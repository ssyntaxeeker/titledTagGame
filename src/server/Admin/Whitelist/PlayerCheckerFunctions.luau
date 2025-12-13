local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local Net = require(ReplicatedStorage.Packages.Net)

local ToggleChatRE = Net:RemoteEvent("ToggleChat")

local PlayerCheckerFunctions = {}

PlayerCheckerFunctions.Perms = { whitelist = 0, chatPerms = 0 }

function PlayerCheckerFunctions.CheckChatPerms(player)
	if
		PlayerCheckerFunctions.Perms.chatPerms == 1
		and not CommandsUtils.CheckForPermission(player, { "Admin", "Playtester", "PrivateServerOwner", "ChatPerms" }, true)
		and game.PrivateServerId == ""
		and not ReplicatedStorage:GetAttribute("Ranked")
	then
		ToggleChatRE:FireClient(player, false)
	end
end

function PlayerCheckerFunctions.CheckWhitelistPerms(player)
	if
		not CommandsUtils.CheckForPermission(player, { "Playtester", "Admin" })
		and (PlayerCheckerFunctions.Perms.whitelist == 1 and not RunService:IsStudio())
	then
		print("Kicked " .. player.Name)
		player:Kick("[WHITELIST ON] You are not allowed here yet (Tester+ only)")
	end
end

return PlayerCheckerFunctions
