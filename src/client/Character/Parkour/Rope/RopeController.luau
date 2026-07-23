--!strict
--[[
    RopeController (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Owns local rope attachment, player-driven rope momentum, release velocity,
    and character lifecycle cleanup.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)
local ParkourAssetScope = require(ReplicatedStorage.Shared.Utils.ParkourAssetScope)
local RopeConfig = require(script.Parent.RopeConfig)

type RRopeState = {
	character: Model,
	rootPart: BasePart,
	targetPart: BasePart,
	rootAttachment: Attachment,
	targetAttachment: Attachment,
	alignPosition: AlignPosition,
}

local localPlayer = Players.LocalPlayer
local RopeController = {}
local activeState: RRopeState? = nil

function RopeController.isActive(): boolean
	return activeState ~= nil
end

function RopeController.release(applyBoost: boolean)
	local state = activeState
	if not state then return end
	activeState = nil
	state.character:SetAttribute("RopeSwinging", nil)
	state.alignPosition:Destroy()
	state.rootAttachment:Destroy()
	state.targetAttachment:Destroy()
	if applyBoost and state.rootPart.Parent then
		local velocity = state.rootPart.AssemblyLinearVelocity
		local lookDirection = state.rootPart.CFrame.LookVector
		state.rootPart.AssemblyLinearVelocity = Vector3.new(
			velocity.X,
			if velocity.Y >= 0 then math.max(velocity.Y, RopeConfig.releaseVerticalVelocity) else math.min(velocity.Y, -RopeConfig.releaseVerticalVelocity),
			velocity.Z
		) + lookDirection * RopeConfig.releaseForwardVelocity + state.targetPart.AssemblyLinearVelocity * 0.65
		local reward = 5 * (state.character:GetAttribute("MomentumMultiplier") or 1)
		state.character:SetAttribute("Momentum", (state.character:GetAttribute("Momentum") or 0) + reward)
	end
	CooldownManager.modifyCooldown(localPlayer, "RopeSwing", true, RopeConfig.releaseCooldown)
end

function RopeController.tryGrab(character: Model, targetPart: BasePart, grabPosition: Vector3): boolean
	if activeState or CooldownManager.getCooldown(localPlayer, "RopeSwing") then return false end
	if not ParkourAssetScope.contains(targetPart) then return false end
	local current: Instance? = targetPart
	local canGrab = false
	while current and ParkourAssetScope.contains(current) do
		if current:GetAttribute("RopeGrab") == true then
			canGrab = true
			break
		end
		current = current.Parent
	end
	if not canGrab then return false end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(rootPart and rootPart:IsA("BasePart"), "[RopeController.tryGrab] character has no HumanoidRootPart")
	if (rootPart.Position - grabPosition).Magnitude > RopeConfig.grabDistance + 0.5 then return false end

	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "RopeRootAttachment"
	rootAttachment.Position = Vector3.new(0, 0, -1)
	rootAttachment.Parent = rootPart
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "RopeTargetAttachment"
	targetAttachment.Position = targetPart.CFrame:PointToObjectSpace(grabPosition)
	targetAttachment.Parent = targetPart
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Attachment0 = rootAttachment
	alignPosition.Attachment1 = targetAttachment
	alignPosition.Responsiveness = RopeConfig.alignResponsiveness
	alignPosition.MaxForce = RopeConfig.alignMaximumForce
	alignPosition.Parent = rootPart

	if not targetPart.Anchored then
		targetPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity * 0.9
	end
	character:SetAttribute("RopeSwinging", true)
	activeState = {
		character = character,
		rootPart = rootPart,
		targetPart = targetPart,
		rootAttachment = rootAttachment,
		targetAttachment = targetAttachment,
		alignPosition = alignPosition,
	}
	return true
end

function RopeController.step(dt: number)
	local state = activeState
	if not state then return end
	if not state.character.Parent or not state.targetPart.Parent then
		RopeController.release(false)
		return
	end
	if (state.rootPart.Position - state.targetAttachment.WorldPosition).Magnitude > RopeConfig.maximumSeparation then
		RopeController.release(false)
		return
	end
	if not state.targetPart.Anchored and MovementInterface.MoveVector.Magnitude > 0.1 then
		local humanoid = state.character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			state.targetPart.AssemblyLinearVelocity += humanoid.MoveDirection * RopeConfig.movementImpulse * math.min(dt * 60, 2)
		end
	end
end

return table.freeze(RopeController)
