--!strict
--[[
    ClockTimeCheck (Server)
    =======================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Advances only the current round timer and delegates expiry to its mode.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)
local RoundUtils = require(ServerStorage.Modules.GameLogic.Round.RoundUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function initTimer()
	while task.wait(1) do
		local timeLeft = workspace:GetAttribute("TimeLeft")
		local mode = workspace:GetAttribute("Gamemode")
		local id = workspace:GetAttribute("RoundId")
		if type(timeLeft) ~= "number" or timeLeft <= 0 or type(mode) ~= "string" or type(id) ~= "number" then continue end
		if workspace:GetAttribute("RoundState") ~= "Running" then continue end

		if (mode == "InfFFA" or mode == "FFA") and #Players:GetPlayers() <= 8 then
			ClockInterface.updateTagRangeSignal:Fire()
		end
		if ReplicatedStorage:GetAttribute("Ranked") then
			ClockInterface.updateRunnerTimesSignal:Fire()
		end

		local configModule = ReplicatedStorage.Shared.Configs.Modes:FindFirstChild(mode)
		local modeConfig = if configModule then require(configModule) else nil
		if modeConfig and modeConfig.lastPlayerStanding and RoundUtils.CheckIfLastPlayerStanding() then
			RoundManager.EndRound(nil, "LastPlayerStanding")
			continue
		end

		local nextTime = timeLeft - 1
		workspace:SetAttribute("TimeLeft", nextTime)
		if nextTime <= 0 then RoundManager.TimerExpired(id) end
	end
end

return Schedules.Boot.job(initTimer)
