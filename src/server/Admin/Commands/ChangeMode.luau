local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

	if not parameters[1] then return end

	local mode

	for _, modeModule in ReplicatedStorage.Shared.Configs.Modes:GetChildren() do
		if modeModule.Name:lower() == parameters[1]:lower() then
			mode = modeModule.Name

			break
		end
	end

	RoundManager.SetMode(mode)
end)
