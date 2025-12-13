local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Workspace = game:GetService("Workspace")

local CameraShake = require(ReplicatedStorage.Modules.Camera.CameraShake)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local MovementController = require(ReplicatedStorage.Modules.Character.Movement.MovementController)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local localPlayer = Players.LocalPlayer

local Wallrun = {}

local activeWall
local momentum = 0

local function releaseWallrun(applyBoost: boolean)
	if not activeWall then return end

	local character = localPlayer.Character
	if not character then return end

	activeWall = nil

	local rootPart = character.HumanoidRootPart

	if applyBoost and rootPart then
		CameraShake.new():Shake(0.3, 0.05, 0.5)

		local lookVector = rootPart.CFrame.LookVector
		local side = math.sign(workspace.CurrentCamera.CFrame.X or 0)

		rootPart.AssemblyLinearVelocity = (rootPart.AssemblyLinearVelocity + lookVector * ((90 - side) * 0.5)) * 0.7

		local boost = math.clamp(rootPart.AssemblyLinearVelocity.Magnitude / 65, 1, 5) * 5
		momentum += boost * (character:GetAttribute("MomentumMultiplier") or 1)
	end

	CooldownManager.modifyCooldown(localPlayer, "Wallrun", true, 0.66)
	-- Events.Movement:Fire("WallrunLeft", 0.1)
	-- Events.Movement:Fire("WallrunRight", 0.1)
end

local function startWallrun(hitResult: RaycastResult, suppressJump: boolean)
	if activeWall then return end
	if not hitResult or not hitResult.Instance then return end
	if not hitResult.Instance:GetAttribute("Wallrun") then return end

	local character = localPlayer.Character
	if not character then return end

	local humanoid = character.Humanoid
	local rootPart = character.HumanoidRootPart

	activeWall = hitResult
	local localPos = rootPart.CFrame:PointToObjectSpace(hitResult.Position)

	if not suppressJump then
		rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 10, rootPart.AssemblyLinearVelocity.Z)

		-- local side = if localPos.X < 0 then "Left" else "Right"
		-- Events.Movement:Fire("Wallrun" .. side, 0.1)
		CooldownManager.modifyCooldown(localPlayer, "Wallrun", true, 0.66)
	end

	local speed = hitResult.Instance:GetAttribute("Speed") or 1
	humanoid.WalkSpeed = 32 * speed

	local forceVector = CFrame.new(Vector3.zero, hitResult.Normal).RightVector * math.sign(localPos.X)
	MovementController.MoveVector = forceVector
	MovementController.ForceMoveVector = true
end

local function checkWallrun(forceRelease: boolean)
	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	if humanoid.FloorMaterial ~= Enum.Material.Air then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { localPlayer.Character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result
	for side = -1, 1, 2 do
		if result then continue end

		local origin = rootPart.Position
		local direction = rootPart.CFrame.RightVector * side * 5
		result = Workspace:Raycast(origin, direction, params)

		if SettingsInterface.debug.showRaycasts == true then DebugFunctions.VisualizeRaycast(origin, direction, Color3.new(1, 0, 1)) end
	end

	if result and result.Instance:GetAttribute("Wallrun") then
		if math.abs(result.Normal.Y) < 0.15 then startWallrun(result, forceRelease) end
	end

	if forceRelease and activeWall then releaseWallrun(true) end
end

Wallrun.Release = releaseWallrun
Wallrun.Start = startWallrun
Wallrun.Check = checkWallrun
Wallrun.GetActiveWall = function()
	return activeWall
end

return Wallrun
