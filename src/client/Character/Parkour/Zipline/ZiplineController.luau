--!strict
--[[
    ZiplineController (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Owns constraint attachment, travel acceleration, endpoint release, and
    cleanup for one local UTG-style zipline ride.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)
local ZiplineConfig = require(script.Parent.ZiplineConfig)
local ZiplineModel = require(script.Parent.ZiplineModel)

type RZiplineState = {
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	target: ZiplineModel.RZiplineTarget,
	carrier: BasePart,
	rootAttachment: Attachment,
	carrierAttachment: Attachment,
	alignPosition: AlignPosition,
	constraint: PrismaticConstraint,
	startedAt: number,
	heartbeat: RBXScriptConnection?,
	animation: AnimationTrack?,
	loopSound: Sound?,
}

local localPlayer = Players.LocalPlayer
local ZiplineController = {}
local activeState: RZiplineState? = nil

local function optionalAnimation(animator: Animator, name: string): AnimationTrack?
	local animation = ReplicatedStorage.Assets.Animations:FindFirstChild(name, true)
	if not animation or not animation:IsA("Animation") then return nil end
	return AnimationManager.GetTrack(animator, animation)
end

local function optionalSound(rootPart: BasePart, name: string, persistent: boolean?): Sound?
	local sound = ReplicatedStorage.Assets.Sounds:FindFirstChild(name, true)
	if not sound or not sound:IsA("Sound") then return nil end
	local clone = sound:Clone()
	clone.Parent = rootPart
	if persistent then clone.Looped = true end
	clone:Play()
	if not persistent and not clone.Looped then clone.Ended:Once(function() clone:Destroy() end) end
	return clone
end

function ZiplineController.isActive(): boolean
	return activeState ~= nil
end

function ZiplineController.release(applyBoost: boolean)
	local state = activeState
	if not state then return end
	activeState = nil
	if state.heartbeat then state.heartbeat:Disconnect() end
	if state.animation then state.animation:Stop(0.25) end
	if state.loopSound then
		state.loopSound:Stop()
		state.loopSound:Destroy()
	end
	state.character:SetAttribute("Ziplining", nil)
	state.alignPosition:Destroy()
	state.rootAttachment:Destroy()
	state.constraint:Destroy()
	state.carrier:Destroy()
	optionalSound(state.rootPart, "EndZipline")
	if applyBoost and state.rootPart.Parent then
		local camera = Workspace.CurrentCamera
		assert(camera, "[ZiplineController.release] Workspace.CurrentCamera is missing")
		state.rootPart.AssemblyLinearVelocity += camera.CFrame.LookVector
			* ZiplineConfig.releaseBoost
			* Vector3.new(1, 0.3, 1)
	end
	CooldownManager.modifyCooldown(localPlayer, "Zipline", true, ZiplineConfig.cooldown)
end

local function sustain(state: RZiplineState, dt: number)
	if activeState ~= state or not state.character.Parent or state.humanoid.Health <= 0 then
		if activeState == state then ZiplineController.release(false) end
		return
	end
	if not state.target.container.Parent or not state.carrier.Parent then
		ZiplineController.release(false)
		return
	end

	local inputDirection = state.rootPart.CFrame.LookVector * MovementInterface.MoveVector.Z
	local velocity = state.carrier.AssemblyLinearVelocity + inputDirection * ZiplineConfig.inputAcceleration * dt
	local axisSpeed = velocity:Dot(state.target.axis)
	if math.abs(axisSpeed) > ZiplineConfig.maximumSpeed then
		velocity += state.target.axis * (math.sign(axisSpeed) * ZiplineConfig.maximumSpeed - axisSpeed)
	end
	state.carrier.AssemblyLinearVelocity = velocity
	if state.loopSound then
		local speedRatio = state.carrier.AssemblyLinearVelocity.Magnitude / 48
		state.loopSound.Volume = math.clamp(speedRatio, 0, 0.5)
		state.loopSound.PlaybackSpeed = math.clamp(speedRatio, 0.9, 2) * 1.1
	end

	local grace = os.clock() - state.startedAt < ZiplineConfig.attachGraceSeconds
	if grace then return end
	local separation = (state.rootAttachment.WorldPosition - state.carrierAttachment.WorldPosition).Magnitude
	local position = state.constraint.CurrentPosition
	if separation > ZiplineConfig.maximumSeparation
		or position > state.constraint.UpperLimit - ZiplineConfig.endpointInset
		or position < ZiplineConfig.endpointInset
	then
		ZiplineController.release(false)
	end
end

function ZiplineController.tryAttach(character: Model, nearbyParts: { BasePart }?): boolean
	if activeState then return true end
	if CooldownManager.getCooldown(localPlayer, "Zipline") then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[ZiplineController.tryAttach] character has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[ZiplineController.tryAttach] character has no HumanoidRootPart")
	local target = ZiplineModel.find(character, rootPart.Position, nearbyParts)
	if not target then return false end

	local along = math.clamp((rootPart.Position - target.origin):Dot(target.axis), 0, target.upperLimit)
	local carrierPosition = target.origin + target.axis * along
	local carrier = Instance.new("Part")
	carrier.Name = "ZiplineCarrier"
	carrier.Size = Vector3.one
	carrier.CFrame = rootPart.CFrame.Rotation + carrierPosition
	carrier.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity
	carrier.CanCollide = false
	carrier.CanQuery = false
	carrier.CanTouch = false
	carrier.Transparency = 1
	carrier.Parent = character

	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "ZiplineRootAttachment"
	rootAttachment.CFrame = CFrame.new(0, ZiplineConfig.hangOffset, 0)
	rootAttachment.Parent = rootPart
	local carrierAttachment = Instance.new("Attachment")
	carrierAttachment.Name = "ZiplineCarrierAttachment"
	carrierAttachment.Axis = carrier.CFrame:VectorToObjectSpace(target.topAttachment.WorldAxis)
	carrierAttachment.SecondaryAxis = carrier.CFrame:VectorToObjectSpace(target.topAttachment.WorldSecondaryAxis)
	carrierAttachment.Parent = carrier

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Attachment0 = rootAttachment
	alignPosition.Attachment1 = carrierAttachment
	alignPosition.MaxForce = ZiplineConfig.alignMaximumForce
	alignPosition.Responsiveness = ZiplineConfig.alignResponsiveness
	alignPosition.Parent = rootPart

	local constraint = Instance.new("PrismaticConstraint")
	constraint.Attachment0 = target.topAttachment
	constraint.Attachment1 = carrierAttachment
	constraint.LimitsEnabled = true
	constraint.LowerLimit = 0
	constraint.UpperLimit = target.upperLimit
	constraint.Parent = carrier

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local animation = if animator then optionalAnimation(animator, "Zipline") else nil
	if animation then
		animation.Priority = Enum.AnimationPriority.Action2
		animation:Play(0.2)
	end
	optionalSound(rootPart, "StartZipline")
	local loopSound = optionalSound(rootPart, "Zipline", true)
	character:SetAttribute("Ziplining", true)

	local state: RZiplineState = {
		character = character,
		humanoid = humanoid,
		rootPart = rootPart,
		target = target,
		carrier = carrier,
		rootAttachment = rootAttachment,
		carrierAttachment = carrierAttachment,
		alignPosition = alignPosition,
		constraint = constraint,
		startedAt = os.clock(),
		heartbeat = nil,
		animation = animation,
		loopSound = loopSound,
	}
	activeState = state
	state.heartbeat = RunService.Heartbeat:Connect(function(dt) sustain(state, dt) end)
	CooldownManager.modifyCooldown(localPlayer, "Zipline", true, ZiplineConfig.cooldown)
	return true
end

function ZiplineController.toggle(character: Model): boolean
	if activeState then
		ZiplineController.release(true)
		return true
	end
	return ZiplineController.tryAttach(character)
end

return table.freeze(ZiplineController)
