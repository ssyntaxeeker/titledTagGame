local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local PlayerCheckerFunctions = require(ServerStorage.Modules.Admin.Whitelist.PlayerCheckerFunctions)

local checkerProperties = { whitelist = 0, chatPerms = 0 }

Players.PlayerAdded:Connect(function(player)
	local userRole = CommandsUtils.GetPlayerPermission(player)

	if userRole == "Playtester" then
		player:SetAttribute("VIP", true)
	elseif userRole == "Moderator" then
		player:SetAttribute("Mod", true)
	elseif userRole == "Admin" then
		player:SetAttribute("Dev", true)
	end

	PlayerCheckerFunctions.CheckWhitelistPerms(player)
	PlayerCheckerFunctions.CheckChatPerms(player)
end)

return checkerProperties
