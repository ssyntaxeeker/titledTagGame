local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AerialInterface = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.AerialInterface)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local ParkourMovementModel = require(ReplicatedStorage.Modules.Character.Parkour.ParkourMovementModel)
local Slide = require(ReplicatedStorage.Modules.Character.Parkour.Landing.Slide)
local SwingTech = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.SwingTech)
local VaultTech = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.VaultTech)
local RailController = require(ReplicatedStorage.Modules.Character.Parkour.Rail.RailController)
local RopeController = require(ReplicatedStorage.Modules.Character.Parkour.Rope.RopeController)
local WallrunController = require(ReplicatedStorage.Modules.Character.Parkour.Wallrun.WallrunController)
local WalljumpTech = require(ReplicatedStorage.Modules.Character.Parkour.Walljump.WalljumpTech)
local ZiplineController = require(ReplicatedStorage.Modules.Character.Parkour.Zipline.ZiplineController)

local localPlayer = Players.LocalPlayer

local AerialInputs = {}

function AerialInputs.JumpRequest()
	AerialInterface.swingInputHeld = true
	local character = localPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if character:GetAttribute("Crouching") then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	character:SetAttribute("LastJumpRequestAt", os.clock())
	local performedTech = false
	if AerialInterface.swingingBar then
		AerialInterface.swingReleaseRequested = true
		performedTech = true
	elseif RopeController.isActive() then
		RopeController.release(true)
		performedTech = true
	elseif RailController.isActive() then
		RailController.release(true)
		performedTech = true
	end
	if WallrunController.isActive() then
		WallrunController.release(true)
		performedTech = true
	end
	if not performedTech and ZiplineController.toggle(character) then performedTech = true end

	if not performedTech then
		local ignore = { character }
		local debugFolder = workspace:FindFirstChild("Debug")
		if debugFolder then table.insert(ignore, debugFolder) end
		local probe = ParkourMovementModel.probeAerial(rootPart.Position, rootPart.CFrame.LookVector, ignore)

		if probe then
			task.spawn(function()
				DebugFunctions.VisualizeRaycast(probe.rayOrigin, probe.rayDirection)
				DebugFunctions.VisualizeRaycast(probe.forwardOrigin, probe.forwardDirection, Color3.fromRGB(255, 0, 0))
			end)
			local obstacleHit = probe.result
			local instance = obstacleHit.Instance

			if ParkourMovementModel.isSwingBar(instance) and not AerialInterface.swingingBar then
				task.spawn(SwingTech, obstacleHit)
				performedTech = true
			elseif not instance:GetAttribute("NoClimb") then
				VaultTech(probe.studs, instance)
				performedTech = true
			end
		end
	end

	if not performedTech and humanoid.FloorMaterial == Enum.Material.Air then
		performedTech = WallrunController.tryStart(character, false)
	end
	if not performedTech then performedTech = WalljumpTech.try(character) end

	if character:GetAttribute("Sliding") then
		Slide.Stop()
	end

	return if performedTech then nil else true
end

function AerialInputs.JumpReleased()
	AerialInterface.swingInputHeld = false
end

return AerialInputs
