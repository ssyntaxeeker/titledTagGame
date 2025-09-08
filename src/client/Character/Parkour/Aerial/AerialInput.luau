local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AerialInterface = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.AerialInterface)
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local SwingTech = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.SwingTech)
local VaultTech = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.VaultTech)

local localPlayer = Players.LocalPlayer

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function visualizeRay(origin, direction, color)
	local rayLength = direction.Magnitude
	local rayPart = Instance.new("Part")
	rayPart.Anchored = true
	rayPart.CanCollide = false
	rayPart.CanQuery = false
	rayPart.Size = Vector3.new(0.02, 0.02, rayLength)
	rayPart.Color = color or Color3.fromRGB(128, 0, 128)
	rayPart.Material = Enum.Material.Neon
	rayPart.CFrame = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -rayLength / 2)
	rayPart.Parent = workspace.Debug

	game:GetService("Debris"):AddItem(rayPart, 4)
end

InputsManager.AddInput("JumpRequest", {
	Keys = { Enum.KeyCode.Space },
	OnBegan = function()
		local character = localPlayer.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		if character:GetAttribute("Crouching") or character:GetAttribute("Sliding") then return end

		rayParams.FilterDescendantsInstances = { character, workspace.Debug }

		local obstacleHit = nil

		for distance = 0.5, 2.25, 0.25 do
			if not obstacleHit then
				local origin = rootPart.Position + rootPart.CFrame.LookVector * distance + rootPart.CFrame.UpVector * 2.75
				local direction = -rootPart.CFrame.UpVector * 3.25

				obstacleHit = Workspace:Raycast(origin, direction, rayParams)
			end
		end

		task.spawn(function()
			if SettingsInterface.debug.showValues ~= true then return end

			visualizeRay(rootPart.Position + rootPart.CFrame.LookVector * 2 + rootPart.CFrame.UpVector * 2.75, -rootPart.CFrame.UpVector * 3.25)
		end)

		if obstacleHit then
			local rootPos = rootPart.Position
			local forwardOrigin = rootPos + Vector3.new(0, 1.25, 0) - rootPart.CFrame.LookVector * 2.5
			local forwardDirection = rootPart.CFrame.LookVector * 3

			local forwardCheck = Workspace:Raycast(forwardOrigin, forwardDirection, rayParams)
			local instance = obstacleHit.Instance

			if forwardCheck then return end

			if instance:GetAttribute("SwingBar") and not AerialInterface.swingingBar then
				SwingTech(obstacleHit)
				return
			end

			if instance:GetAttribute("NoClimb") then return end

			local vaultHeight = math.abs(obstacleHit.Position.Y - rootPart.Position.Y)
			VaultTech(vaultHeight)
		end
	end,
})

return 0
