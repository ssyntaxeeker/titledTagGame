local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local function spawnPlayer(player)
	local currentGamemode = workspace:GetAttribute("Gamemode")
	local chosenRole

	local character = player.Character or player.CharacterAdded:Wait()
	if character:GetAttribute("Role") then return end

	if currentGamemode then
		local gamemodeConfig = require(ReplicatedStorage.Shared.Configs.Modes[currentGamemode])
		chosenRole = gamemodeConfig.onJoinRole
	else
		chosenRole = "Runner"
	end

	RolesFunctions.ChangeRole(player, chosenRole)
end

Players.PlayerAdded:Connect(spawnPlayer)

return 0
