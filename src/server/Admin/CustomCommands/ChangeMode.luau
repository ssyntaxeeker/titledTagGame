local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CommandRegistry = require(ServerStorage.Modules.Chat.Commands.CommandRegistry)
local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
}

return CommandRegistry.RegisterCommand("mode", function(sender, modeName)
	if typeof(modeName) ~= "string" then return end

	local permission = CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(sender.UserId), canUseCommand)
	if not RunService:IsStudio() and not permission then return end

	local mode

	for _, modeModule in ReplicatedStorage.Shared.Configs.Modes:GetChildren() do
		if modeModule.Name:lower() == modeName:lower() then
			mode = modeModule.Name
			break
		end
	end

	if mode then RoundManager.SetMode(mode) end
end)
