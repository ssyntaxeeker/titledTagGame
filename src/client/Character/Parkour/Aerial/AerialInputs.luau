local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AerialInterface = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.AerialInterface)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local SwingTech = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.SwingTech)
local VaultTech = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.VaultTech)

local localPlayer = Players.LocalPlayer

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local AerialInputs = {}

function AerialInputs.JumpRequest()
    	local character = localPlayer.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		if character:GetAttribute("Crouching") or character:GetAttribute("Sliding") then return end

		rayParams.FilterDescendantsInstances = { character, workspace.Debug }

		local obstacleHit = nil

		for distance = 0.5, 2.25, 0.25 do
			if not obstacleHit then
				local origin = rootPart.Position + rootPart.CFrame.LookVector * distance + Vector3.yAxis * 2.75
				local direction = -Vector3.yAxis * 3.25

				obstacleHit = Workspace:Raycast(origin, direction, rayParams)
			end
		end

		task.spawn(function()
			DebugFunctions.VisualizeRaycast(
				rootPart.Position + rootPart.CFrame.LookVector * 2 + rootPart.CFrame.UpVector * 2.75,
				-rootPart.CFrame.UpVector * 3.25
			)
		end)

		if obstacleHit then
			local rootLookVector = rootPart.CFrame.LookVector
			local forwardRay = Ray.new(rootPart.Position + Vector3.new(0, 1.25, 0) - rootLookVector * 2.5, rootLookVector * 3)

			local forwardCheck = Workspace:Raycast(forwardRay.Origin, forwardRay.Direction, rayParams)

			if forwardCheck then return end

			local instance = obstacleHit.Instance

			task.spawn(function()
				DebugFunctions.VisualizeRaycast(forwardRay.Origin, forwardRay.Direction, Color3.fromRGB(255, 0, 0))
			end)

			if forwardCheck then return end

			if instance:GetAttribute("SwingBar") and not AerialInterface.swingingBar then
				SwingTech(obstacleHit)
				return
			end

			if instance:GetAttribute("NoClimb") then return end

			local vaultHeight = math.abs(obstacleHit.Position.Y - rootPart.Position.Y)
			VaultTech(vaultHeight, instance)
			return
		end
end

return AerialInputs