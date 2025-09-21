local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
}

return TextChatService.TextChatCommands.SetTime.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	local permission = CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand)
	if not RunService:IsStudio() and not permission then return end

	ClockFunctions.SetTime(tonumber(parameters[1]) or -1)
end)
