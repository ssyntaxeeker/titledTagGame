local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local Profiles = require(ServerStorage.Modules.Data.Profiles)

local canUseCommand = {
	"Admin",
}

return TextChatService.TextChatCommands.ChangeData.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	local player = CommandsUtils.AutocompletePlayer(parameters[1])
	if not player then return end

	local dataName, keyName = parameters[2], parameters[3]
	if not dataName or not keyName then return end

	local permission = CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand)
	if not RunService:IsStudio() and not permission then return end

	local proxy = Profiles.ReturnProxy(player)
	proxy[dataName] = keyName
end)
