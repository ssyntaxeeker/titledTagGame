local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)

local canUseCommand = {
	"Admin",
	"Playtester",
	"PrivateServerOwner",
}

return TextChatService.TextChatCommands.Goto.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	local commandSender = Players:GetPlayerByUserId(source.UserId)

	if not RunService:IsStudio() and not CommandsUtils.CheckForPermission(commandSender, canUseCommand) then return end

	local player = CommandsUtils.AutocompletePlayer(parameters[1])
	if not player then return end

	local character1, character2 = commandSender.Character, player.Character
	if not character1 or not character2 then return end

	character1:PivotTo(character2.PrimaryPart.CFrame)
end)
