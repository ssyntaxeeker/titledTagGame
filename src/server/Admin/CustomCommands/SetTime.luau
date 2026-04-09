local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local CommandRegistry = require(ServerStorage.Modules.Chat.Commands.CommandRegistry)
local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
}

return CommandRegistry.RegisterCommand("time", function(sender, amountOfTime)
	amountOfTime = tonumber(amountOfTime)
	if typeof(amountOfTime) ~= "number" then return end

	local permission = CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(sender.UserId), canUseCommand)
	if not RunService:IsStudio() and not permission then return end

	ClockFunctions.SetTime(tonumber(amountOfTime) or -1)
end)
