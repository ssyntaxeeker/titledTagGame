local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)

local checkerProperties = { whitelist = 1 }

Players.PlayerAdded:Connect(function(player)
	if
		not CommandsUtils.CheckForPermission(player, { "Playtester", "Admin" }) and (checkerProperties.whitelist == 1 and not RunService:IsStudio())
	then
		print("Kicked " .. player.Name)
		player:Kick("[WHITELIST ON] You are not allowed here yet (Tester+ only)")
	end
end)

return checkerProperties
