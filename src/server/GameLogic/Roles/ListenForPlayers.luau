local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local function checkForRoleRearrangement(character)
	local currentGamemode = workspace:GetAttribute("Gamemode")
	if not currentGamemode then return end

	local gamemodeConfig = require(ReplicatedStorage.Shared.Configs.Modes[currentGamemode])
	local regiveRole = gamemodeConfig.regiveRoleOnCharacterRemoved
	local allowedRolesToGetRegivenRole = gamemodeConfig.allowedRolesToGetRegivenRole

	if not regiveRole or character:GetAttribute("Role") ~= regiveRole then return end

	for _, player in Players:GetPlayers() do
		if player.Character == character then continue end
		if not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then continue end

		local playerRole = player.Character:GetAttribute("Role")
		if not table.find(allowedRolesToGetRegivenRole, playerRole) then continue end

		RolesFunctions.ChangeRole(player, regiveRole)
		break
	end
end

local function spawnPlayer(player)
	local currentGamemode = workspace:GetAttribute("Gamemode")
	local chosenRole

	player.CharacterRemoving:Connect(checkForRoleRearrangement)

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
