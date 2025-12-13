local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local Profiles = require(ServerStorage.Modules.Data.Profiles)

local canUseCommand = {
	"Admin",
	"Ranker",
}

return TextChatService.TextChatCommands.Rank.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	if not RunService:IsStudio() and not CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand) then return end

	local player = CommandsUtils.AutocompletePlayer(parameters[1])
	if not player then return end

	local rankType = parameters[2]:lower()
	if rankType ~= "ffa" and rankType ~= "classic" then return end

	rankType = rankType == "ffa" and "Stars" or "Rank"

	local proxy = Profiles.ReturnProxy(player)
	proxy[rankType] = parameters[3]
end)
