--!strict
--[[
    RailController (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Owns projection onto a straight UTG rail, constrained travel, endpoint
    release, and jump-release momentum.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local ParkourAssetScope = require(ReplicatedStorage.Shared.Utils.ParkourAssetScope)
local RailConfig = require(script.Parent.RailConfig)

type RRailState = {
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	rail: BasePart,
	axis: Vector3,
	halfLength: number,
	distance: number,
	speed: number,
	alignPosition: AlignPosition,
	attachment: Attachment,
	animation: AnimationTrack?,
	loopSound: Sound?,
}

local localPlayer = Players.LocalPlayer
local RailController = {}
local activeState: RRailState? = nil

local function optionalAnimation(animator: Animator, name: string): AnimationTrack?
	local asset = ReplicatedStorage.Assets.Animations:FindFirstChild(name, true)
	if not asset or not asset:IsA("Animation") then return nil end
	return AnimationManager.GetTrack(animator, asset)
end

local function optionalLoopSound(rootPart: BasePart): Sound?
	local asset = ReplicatedStorage.Assets.Sounds:FindFirstChild("RailGrind", true)
	if not asset or not asset:IsA("Sound") then return nil end
	local sound = asset:Clone()
	sound.Looped = true
	sound.Parent = rootPart
	sound:Play()
	return sound
end

local function railFromHit(instance: Instance): BasePart?
	if not ParkourAssetScope.contains(instance) then return nil end
	if instance:IsA("BasePart") and instance:GetAttribute("RailCollision") == true then
		local parent = instance.Parent
		return if parent and parent:IsA("BasePart") then parent else instance
	end
	local parent = instance.Parent
	if parent and parent:IsA("BasePart") and parent:GetAttribute("RailCollision") == true then return parent end
	return nil
end

local function longestAxis(part: BasePart): (Vector3, number)
	if part.Size.X >= part.Size.Y and part.Size.X >= part.Size.Z then return part.CFrame.RightVector, part.Size.X * 0.5 end
	if part.Size.Y >= part.Size.Z then return part.CFrame.UpVector, part.Size.Y * 0.5 end
	return part.CFrame.LookVector, part.Size.Z * 0.5
end

function RailController.isActive(): boolean
	return activeState ~= nil
end

function RailController.release(applyBoost: boolean)
	local state = activeState
	if not state then return end
	activeState = nil
	state.character:SetAttribute("RailGrinding", nil)
	state.humanoid.AutoRotate = true
	if state.animation then state.animation:Stop(0.25) end
	if state.loopSound then
		state.loopSound:Stop()
		state.loopSound:Destroy()
	end
	state.alignPosition:Destroy()
	state.attachment:Destroy()
	if applyBoost and state.rootPart.Parent then
		state.rootPart.AssemblyLinearVelocity = state.axis * state.speed + Vector3.yAxis * RailConfig.releaseVerticalVelocity
		local reward = math.clamp(state.speed / 13, 5, 25) * (state.character:GetAttribute("MomentumMultiplier") or 1)
		state.character:SetAttribute("Momentum", (state.character:GetAttribute("Momentum") or 0) + reward)
	end
	CooldownManager.modifyCooldown(localPlayer, "RailGrind", true, RailConfig.releaseCooldown)
end

function RailController.fling()
	local state = activeState
	if not state then return end
	local direction = (state.rootPart.CFrame.LookVector + Vector3.yAxis * 0.2).Unit
	RailController.release(false)
	if not state.rootPart.Parent then return end
	state.rootPart.AssemblyLinearVelocity = direction * RailConfig.flingVelocity
	local reward = 20 * (state.character:GetAttribute("MomentumMultiplier") or 1)
	state.character:SetAttribute("Momentum", (state.character:GetAttribute("Momentum") or 0) + reward)
	CooldownManager.modifyCooldown(localPlayer, "RailGrind", true, 1)
end

function RailController.tryAttach(character: Model, result: RaycastResult): boolean
	if activeState or CooldownManager.getCooldown(localPlayer, "RailGrind") then return false end
	local rail = railFromHit(result.Instance)
	if not rail then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[RailController.tryAttach] character has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[RailController.tryAttach] character has no HumanoidRootPart")
	local rawAxis, halfLength = longestAxis(rail)
	local reference = if rootPart.AssemblyLinearVelocity.Magnitude > 2 then rootPart.AssemblyLinearVelocity.Unit else rootPart.CFrame.LookVector
	local axis = rawAxis * (if rawAxis:Dot(reference) >= 0 then 1 else -1)
	local along = math.clamp((result.Position - rail.Position):Dot(axis), -halfLength, halfLength)
	local attachment = Instance.new("Attachment")
	attachment.Name = "RailRootAttachment"
	attachment.Parent = rootPart
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.MaxForce = RailConfig.alignMaximumForce
	alignPosition.Responsiveness = RailConfig.alignResponsiveness
	alignPosition.Position = rail.Position + axis * along + Vector3.yAxis * RailConfig.rideHeight
	alignPosition.Parent = rootPart
	humanoid.AutoRotate = false
	character:SetAttribute("RailGrinding", true)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local animation = if animator then optionalAnimation(animator, "RailGrind") else nil
	if animation then
		animation.Priority = Enum.AnimationPriority.Action2
		animation:Play(0.2)
	end
	activeState = {
		character = character,
		humanoid = humanoid,
		rootPart = rootPart,
		rail = rail,
		axis = axis,
		halfLength = halfLength,
		distance = along,
		speed = math.clamp(rootPart.AssemblyLinearVelocity.Magnitude, RailConfig.minimumSpeed, RailConfig.maximumSpeed),
		alignPosition = alignPosition,
		attachment = attachment,
		animation = animation,
		loopSound = optionalLoopSound(rootPart),
	}
	local lastJumpRequestAt = character:GetAttribute("LastJumpRequestAt")
	if typeof(lastJumpRequestAt) == "number" and os.clock() - lastJumpRequestAt < RailConfig.flingInputWindow then
		RailController.fling()
	end
	return true
end

function RailController.step(dt: number)
	local state = activeState
	if not state then return end
	if not state.character.Parent or not state.rail.Parent or state.humanoid.Health <= 0 then
		RailController.release(false)
		return
	end
	state.speed = math.clamp(state.speed + RailConfig.acceleration * dt, RailConfig.minimumSpeed, RailConfig.maximumSpeed)
	state.distance += state.speed * dt
	if state.distance >= state.halfLength - RailConfig.endpointInset then
		RailController.release(false)
		return
	end
	local position = state.rail.Position + state.axis * state.distance + Vector3.yAxis * RailConfig.rideHeight
	state.alignPosition.Position = position
	state.rootPart.CFrame = CFrame.lookAt(state.rootPart.Position, state.rootPart.Position + state.axis)
	state.rootPart.AssemblyLinearVelocity = state.axis * state.speed
	if state.loopSound then
		state.loopSound.Volume = math.clamp(state.speed / 48, 0, 0.5)
		state.loopSound.PlaybackSpeed = math.clamp(state.speed / 48, 0.6, 2.5)
	end
end

return table.freeze(RailController)
