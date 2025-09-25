local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local Dev = require(ReplicatedStorage.Shared.Configs.Dev)
local RankedFunctions = require(ServerStorage.Modules.Matchmaking.RankedFunctions)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local function startGame()
	task.spawn(function()
		local player = Players:GetPlayers()[1]
		if not player then player = Players.PlayerAdded:Wait() end

		local joinData = player:GetJoinData()

		task.wait(1)

		if (RunService:IsStudio() and Dev.ranked == true) or (joinData and joinData.TeleportData and joinData.TeleportData.Ranked == true) then
			RankedFunctions.StartRanked()
		else
			ChangeMap(Assets.Maps.Crossroads)
			RoundManager.SetMode("InfCrown")
		end
	end)
end

return Schedules.Boot.job(startGame)
