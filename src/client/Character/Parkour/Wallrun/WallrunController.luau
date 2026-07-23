--!strict
--[[
    WallrunController (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Owns the local wallrun lifecycle. The active heartbeat exists only while
    attached and releases immediately when the supporting wall is lost.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local WallrunConfig = require(script.Parent.WallrunConfig)
local WallrunModel = require(script.Parent.WallrunModel)
local ParkourAssetScope = require(ReplicatedStorage.Shared.Utils.ParkourAssetScope)

local AnimationAssets = ReplicatedStorage.Assets.Animations.Parkour

type RWallrunState = {
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	wall: BasePart,
	normal: Vector3,
	direction: Vector3,
	side: number,
	heartbeat: RBXScriptConnection?,
	animation: AnimationTrack?,
}

local localPlayer = Players.LocalPlayer
local WallrunController = {}
local activeState: RWallrunState? = nil

local function stopState(state: RWallrunState)
	if state.heartbeat then state.heartbeat:Disconnect() end
	if state.animation then state.animation:Stop(0.1) end
	state.character:SetAttribute("Wallrunning", nil)
	state.character:SetAttribute("WallrunDirection", nil)
	state.character:SetAttribute("WallrunSide", nil)
end

function WallrunController.isActive(): boolean
	return activeState ~= nil
end

function WallrunController.release(applyBoost: boolean)
	local state = activeState
	if not state then return end
	activeState = nil
	stopState(state)

	if applyBoost and state.character.Parent and state.rootPart.Parent then
		local cameraPitch = CameraModule.FreelookX or CameraModule.CameraX
		state.rootPart.AssemblyLinearVelocity = WallrunModel.releaseVelocity(
			state.rootPart.AssemblyLinearVelocity,
			state.rootPart.CFrame.LookVector,
			cameraPitch
		)
		local multiplier = state.character:GetAttribute("MomentumMultiplier") or 1
		local momentum = state.character:GetAttribute("Momentum") or 0
		state.character:SetAttribute(
			"Momentum",
			momentum + WallrunModel.momentumReward(state.rootPart.AssemblyLinearVelocity) * multiplier
		)
	end
	CooldownManager.modifyCooldown(localPlayer, "Wallrun", true, WallrunConfig.cooldown)
end

local function sustain(state: RWallrunState, dt: number)
	if activeState ~= state or not state.character.Parent or state.humanoid.Health <= 0 then
		if activeState == state then WallrunController.release(false) end
		return
	end
	if state.humanoid.FloorMaterial ~= Enum.Material.Air then
		WallrunController.release(false)
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { state.character }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local result = Workspace:Raycast(state.rootPart.Position, -state.normal * WallrunConfig.probeDistance, params)
	if not result
		or not ParkourAssetScope.contains(result.Instance)
		or result.Instance:GetAttribute("Wallrun") ~= true
		or math.abs(result.Normal.Y) >= WallrunConfig.maximumNormalY
		or not result.Instance:IsA("BasePart")
		or not WallrunModel.isWeldSurface(result.Instance, result.Normal)
	then
		WallrunController.release(false)
		return
	end

	assert(result.Instance:IsA("BasePart"), "[WallrunController.sustain] wallrun ray hit a non-part")
	state.wall = result.Instance
	state.normal = result.Normal
	state.direction, state.side = WallrunModel.travelDirection(state.rootPart, result)
	state.character:SetAttribute("WallrunDirection", state.direction)
	local velocity = state.rootPart.AssemblyLinearVelocity
	state.rootPart.AssemblyLinearVelocity = Vector3.new(
		velocity.X,
		math.max(velocity.Y + math.min(dt, 1) * 60 * WallrunConfig.verticalAccelerationPerFrame, WallrunConfig.minimumFallVelocity),
		velocity.Z
	)
end

function WallrunController.tryStart(character: Model, suppressEntryJump: boolean): boolean
	if activeState then return true end
	if CooldownManager.getCooldown(localPlayer, "Wallrun") then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[WallrunController.tryStart] character has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[WallrunController.tryStart] character has no HumanoidRootPart")
	if humanoid.FloorMaterial ~= Enum.Material.Air or humanoid.Health <= 0 then return false end
	local probe = WallrunModel.probe(character, rootPart)
	if not probe or not probe.result.Instance:IsA("BasePart") then return false end

	local direction, side = WallrunModel.travelDirection(rootPart, probe.result)
	rootPart.CFrame = rootPart.CFrame.Rotation + probe.result.Position + probe.result.Normal
	if not suppressEntryJump then
		local velocity = rootPart.AssemblyLinearVelocity
		rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, WallrunConfig.entryVerticalVelocity, velocity.Z)
	end
	humanoid.WalkSpeed = WallrunConfig.baseWalkSpeed * (probe.result.Instance:GetAttribute("Speed") or 1)
	character:SetAttribute("Wallrunning", true)
	character:SetAttribute("WallrunDirection", direction)
	character:SetAttribute("WallrunSide", side)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	assert(animator, "[WallrunController.tryStart] humanoid has no Animator")
	local animationAsset = if side < 0 then AnimationAssets.WallrunLeft else AnimationAssets.WallrunRight
	assert(animationAsset:IsA("Animation"), "[WallrunController.tryStart] wallrun asset is not an Animation")
	local animation = AnimationManager.GetTrack(animator, animationAsset)
	assert(animation, "[WallrunController.tryStart] failed to load wallrun animation")
	animation.Priority = Enum.AnimationPriority.Action2
	animation.Looped = true
	animation:Play(0.1)

	local state: RWallrunState = {
		character = character,
		humanoid = humanoid,
		rootPart = rootPart,
		wall = probe.result.Instance,
		normal = probe.result.Normal,
		direction = direction,
		side = side,
		heartbeat = nil,
		animation = animation,
	}
	state.heartbeat = RunService.Heartbeat:Connect(function(dt) sustain(state, dt) end)
	activeState = state
	CooldownManager.modifyCooldown(localPlayer, "Wallrun", true, WallrunConfig.cooldown)
	return true
end

return table.freeze(WallrunController)
