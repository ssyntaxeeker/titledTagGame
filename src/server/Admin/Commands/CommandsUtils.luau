local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Whitelist = require(ReplicatedStorage.Shared.Configs.Whitelist)

local CommandsUtils = {}

function CommandsUtils.ParseCommand(command)
	if type(command) ~= "string" then return nil end

	local args = {}

	for word in command:gmatch("%S+") do
		table.insert(args, word)
	end

	table.remove(args, 1)

	if #args == 0 then return nil end
	return args
end

function CommandsUtils.AutocompletePlayer(input)
	if type(input) ~= "string" or input == "" then return nil end
	input = input:lower()
	local matches = {}

	for _, player in Players:GetPlayers() do
		local username = player.Name:lower()
		local displayName = player.DisplayName:lower()
		if username:sub(1, #input) == input or displayName:sub(1, #input) == input then table.insert(matches, player) end
	end

	if #matches == 0 then
		return nil
	else
		return matches[1]
	end
end

function CommandsUtils.CheckForPermission(player, canUseTable, forChat)
	if not player then return false end

	for _, role in canUseTable do
		local users = Whitelist[role]
		if not users then continue end

		for _, allowed in users do
			if
				(not ReplicatedStorage:GetAttribute("Ranked") or role == "Admin" or forChat == true)
				and (allowed == tostring(player.UserId) or allowed == player.Name)
			then
				return true
			end
		end
	end

	return false
end

function CommandsUtils.GetPlayerPermission(player)
	if not player then return end

	for role, users in Whitelist do
		if not table.find(users, player.Name) and not table.find(users, tostring(player.UserId)) then continue end

		return role
	end

	return
end

function CommandsUtils.ChangePlayerChatPermissions(player)
	if not player then return false end

	for _, users in Whitelist do
		if not table.find(users, player.Name) and not table.find(users, tostring(player.UserId)) then continue end

		return true
	end

	return false
end

return CommandsUtils
