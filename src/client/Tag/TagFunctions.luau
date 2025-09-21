local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CharacterUtils = require(ReplicatedStorage.Vendor.CharacterUtils)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local CrosshairFunctions = require(ReplicatedStorage.Modules.Cursor.CrosshairFunctions)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)

local Assets = ReplicatedStorage.Assets
local localPlayer = Players.LocalPlayer

local TagRE = Net:RemoteEvent("Tag")
local PlaySoundRE = Net:RemoteEvent("PlaySound")
local tagIndex = 1

local TagFunctions = {}

function TagFunctions.Tag()
    	if CooldownManager.getCooldown(localPlayer, "Tag") then return end

		local character = localPlayer.Character
		if not character then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		task.spawn(function()
			local tagCooldown = character:GetAttribute("TagCooldown") or 1
			CooldownManager.modifyCooldown(localPlayer, "Tag", true, tagCooldown)

			if tagIndex % 2 == 0 then tagIndex = 0 end
			tagIndex += 1

			local tagAnimation = AnimationManager.GetTrack(character.Humanoid.Animator, Assets.Animations.Player[`Tag{tagIndex}`])
			tagAnimation.Priority = Enum.AnimationPriority.Action3

			tagAnimation:Play()
			tagAnimation:AdjustSpeed(1 / tagCooldown)

			PlaySound("Tag", rootPart)
			PlaySoundRE:FireServer("Tag", rootPart)
			CrosshairFunctions.SetCooldown(tagCooldown)
		end)

		local camera = workspace.CurrentCamera
		local forward = camera.CFrame.LookVector
		local right = camera.CFrame.RightVector
		local up = camera.CFrame.UpVector

		local rayNumber = 9
		local circleRadius = 1
		local rangeMultiplier = 1
		local hits = {}
		local characters = {}

		for _, ePlayer in Players:GetPlayers() do
			if ePlayer == localPlayer then continue end

			local eCharacter = ePlayer.Character
			if eCharacter then table.insert(characters, eCharacter) end
		end

		table.insert(characters, workspace.Bots)

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = characters
		rayParams.FilterType = Enum.RaycastFilterType.Include

		for i = 1, rayNumber do
			local angle = (i / rayNumber) * math.pi * 2
			local originOffset = right * math.cos(angle) * circleRadius + up * math.sin(angle) * circleRadius
			local origin = rootPart.Position + Vector3.new(0, 1.5, 0) + originOffset
			local direction = forward * rangeMultiplier * 7

			local raycastResult = workspace:Raycast(origin, direction, rayParams)
			task.spawn(function()
				DebugFunctions.VisualizeRaycast(origin, direction, Color3.fromRGB(255, 39, 39))
			end)

			if raycastResult then
				local instance = raycastResult.Instance
				if
					CharacterUtils.CheckIfInstanceIsPartOfCharacter(instance)
					or (not instance.Anchored or instance:GetAttribute("Taggable") or instance.Name == "Lamp")
				then
					table.insert(hits, { instance, raycastResult.Position })
				end
			end
		end

		if #hits > 0 then
			local target = hits[1][1]
			TagRE:FireServer(target)
		end
	end

return TagFunctions