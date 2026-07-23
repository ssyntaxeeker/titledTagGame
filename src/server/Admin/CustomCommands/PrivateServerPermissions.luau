--!strict
--[[
    PrivateServerPermissions (Server custom chat)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Mirrors private-server delegation commands into the custom command parser.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CommandRegistry = require(ServerStorage.Modules.Chat.Commands.CommandRegistry)
local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local Net = require(ReplicatedStorage.Packages.Net)
local PrivateServerPermissionService = require(ServerStorage.Modules.Admin.PrivateServer.PrivateServerPermissionService)

local FeedbackRE = Net:RemoteEvent("PrivateServerCommandFeedback")

CommandRegistry.RegisterCommand("psgrant", function(sender: Player, playerName: string?)
	if not PrivateServerPermissionService.isOwner(sender) then return end
	local target = CommandsUtils.AutocompletePlayer(playerName)
	if not target then return end
	local changed = PrivateServerPermissionService.grant(sender, target)
	FeedbackRE:FireClient(sender, if changed then `Granted private-server commands to {target.Name}.` else `{target.Name} already has permission.`)
end)

CommandRegistry.RegisterCommand("psrevoke", function(sender: Player, playerName: string?)
	if not PrivateServerPermissionService.isOwner(sender) then return end
	local target = CommandsUtils.AutocompletePlayer(playerName)
	if not target then return end
	local changed = PrivateServerPermissionService.revoke(sender, target)
	FeedbackRE:FireClient(sender, if changed then `Revoked private-server commands from {target.Name}.` else `{target.Name} did not have permission.`)
end)

CommandRegistry.RegisterCommand("psperms", function(sender: Player)
	if not PrivateServerPermissionService.hasCommandPermission(sender) then return end
	local names = {}
	for _, userId in PrivateServerPermissionService.getDelegates() do
		local player = Players:GetPlayerByUserId(userId)
		table.insert(names, if player then player.Name else tostring(userId))
	end
	FeedbackRE:FireClient(sender, if #names > 0 then `Private-server delegates: {table.concat(names, ", ")}` else "No private-server delegates.")
end)

return 0
