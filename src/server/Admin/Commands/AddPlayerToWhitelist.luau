local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local Net = require(ReplicatedStorage.Packages.Net)
local Whitelist = require(ReplicatedStorage.Shared.Configs.Whitelist)

local ToggleChatRE = Net:RemoteEvent("ToggleChat")

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
	"Playtester",
}

return TextChatService.TextChatCommands.GivePlayerChatPerms.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	local player = CommandsUtils.AutocompletePlayer(parameters[1])
	if not player then return end

	if not CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand) then return end

	if not table.find(Whitelist.ChatPerms, player.Name) then table.insert(Whitelist.ChatPerms, player.Name) end
	ToggleChatRE:FireClient(player, CommandsUtils.ChangePlayerChatPermissions(player))
end)
