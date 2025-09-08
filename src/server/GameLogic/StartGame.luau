local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local function startGame()
	task.spawn(function()
		if not Players:GetPlayers()[1] then Players.PlayerAdded:Wait() end

		task.wait(2)

		ChangeMap(Assets.Maps.Crossroads)
		RoundManager.SetMode("InfCrown")
	end)
end

return Schedules.Boot.job(startGame)
