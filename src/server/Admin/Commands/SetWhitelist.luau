local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local PlayerChecker = require(ServerStorage.Modules.Admin.Whitelist.PlayerChecker)

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
	"Playtester",
}

return TextChatService.TextChatCommands.SetWhitelist.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	if not CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand) then return end

	PlayerChecker.whitelist = parameters[2] == "true" and 1 or 0
	print(`Set whitelist to {parameters[2] == "true" and 1 or 0}`)
end)
