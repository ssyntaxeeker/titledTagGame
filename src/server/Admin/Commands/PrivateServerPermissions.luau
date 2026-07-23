--!strict
--[[
    PrivateServerPermissions (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Exposes private-server owner grant, revoke, and list commands through
    TextChatService. The permission service remains the source of truth.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local Net = require(ReplicatedStorage.Packages.Net)
local PrivateServerPermissionService = require(ServerStorage.Modules.Admin.PrivateServer.PrivateServerPermissionService)

local FeedbackRE = Net:RemoteEvent("PrivateServerCommandFeedback")

local function feedback(player: Player, message: string)
	FeedbackRE:FireClient(player, message)
end

local function command(name: string, alias: string, callback: (Player, { string }) -> ())
	local existing = TextChatService:FindFirstChild(name)
	local textCommand: TextChatCommand
	if existing and existing:IsA("TextChatCommand") then
		textCommand = existing
	else
		textCommand = Instance.new("TextChatCommand")
		textCommand.Name = name
		textCommand.PrimaryAlias = alias
		textCommand.Parent = TextChatService
	end
	textCommand.Triggered:Connect(function(origin: TextSource, raw: string)
		local sender = Players:GetPlayerByUserId(origin.UserId)
		if not sender then return end
		local args = raw:split(" ")
		table.remove(args, 1)
		callback(sender, args)
	end)
end

command("PSGrant", "/psgrant", function(sender, args)
	if not PrivateServerPermissionService.isOwner(sender) then
		feedback(sender, "Only the private-server owner can grant command permission.")
		return
	end
	local target = CommandsUtils.AutocompletePlayer(args[1])
	if not target then
		feedback(sender, "Player not found. Usage: /psgrant player")
		return
	end
	local changed = PrivateServerPermissionService.grant(sender, target)
	feedback(sender, if changed then `Granted private-server commands to {target.Name}.` else `{target.Name} already has permission.`)
	if changed then feedback(target, `{sender.Name} granted you private-server command permission.`) end
end)

command("PSRevoke", "/psrevoke", function(sender, args)
	if not PrivateServerPermissionService.isOwner(sender) then
		feedback(sender, "Only the private-server owner can revoke command permission.")
		return
	end
	local target = CommandsUtils.AutocompletePlayer(args[1])
	if not target then
		feedback(sender, "Player not found. Usage: /psrevoke player")
		return
	end
	local changed = PrivateServerPermissionService.revoke(sender, target)
	feedback(sender, if changed then `Revoked private-server commands from {target.Name}.` else `{target.Name} did not have permission.`)
	if changed then feedback(target, `{sender.Name} revoked your private-server command permission.`) end
end)

command("PSPermissions", "/psperms", function(sender, _args)
	if not PrivateServerPermissionService.hasCommandPermission(sender) then
		feedback(sender, "You do not have private-server command permission.")
		return
	end
	local names = {}
	for _, userId in PrivateServerPermissionService.getDelegates() do
		local player = Players:GetPlayerByUserId(userId)
		table.insert(names, if player then player.Name else tostring(userId))
	end
	feedback(sender, if #names > 0 then `Private-server delegates: {table.concat(names, ", ")}` else "No private-server delegates.")
end)

return 0
