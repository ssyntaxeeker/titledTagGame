local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
}

return TextChatService.TextChatCommands.ChangeRole.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	local player = CommandsUtils.AutocompletePlayer(parameters[1])
	if not player then return end

	local permission = CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand)
	if not RunService:IsStudio() and not permission then return end

	RolesFunctions.ChangeRole(player, parameters[2])
end)
