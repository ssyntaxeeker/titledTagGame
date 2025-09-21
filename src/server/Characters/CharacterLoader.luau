local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Dev = require(ReplicatedStorage.Shared.Configs.Dev)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local CharacterLoader = {}

local function loadCharacter(player)
	player:LoadCharacter()

	local character = player.Character

	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Once(function()
		task.delay(2.5, function()
			loadCharacter(player)

			local gamemode = workspace:GetAttribute("Gamemode")
			if gamemode then
				local roleConfig = require(ReplicatedStorage.Shared.Configs.Modes[gamemode])
				if roleConfig.respawnAsRole then 
					RolesFunctions.ChangeRole(player, "Alone")
					return
				end
			end 

			RolesFunctions.ChangeRole(player, "Dead")
		end)
	end)

	if RunService:IsStudio() and Dev.spawnInBaseplate == true then
		if not player:HasAppearanceLoaded() then player.CharacterAppearanceLoaded:Wait() end

		character:PivotTo(workspace.Dev.DevSpawn.CFrame * CFrame.new(0, 5, 0))
	end
end

CharacterLoader.Load = loadCharacter

return CharacterLoader
