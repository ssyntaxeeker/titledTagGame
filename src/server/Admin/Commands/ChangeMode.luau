local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
	"Playtester",
}

return TextChatService.TextChatCommands.ChangeMode.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	if not RunService:IsStudio() and not CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand) then return end

	RoundManager.SetMode(parameters[1])
end)
