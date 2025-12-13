local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local RoundUtils = require(ServerStorage.Modules.GameLogic.Round.RoundUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function initTimer()
	while task.wait(1) do
		local timeLeft = workspace:GetAttribute("TimeLeft")

		local players = Players:GetPlayers()

		local gamemode = workspace:GetAttribute("Gamemode")
		if not gamemode then continue end

		local modeConfig = require(ReplicatedStorage.Shared.Configs.Modes[gamemode])

		if (gamemode == "InfFFA" or gamemode == "FFA") and #players <= 8 then ClockInterface.updateTagRangeSignal:Fire() end

		if not timeLeft or timeLeft <= 0 then continue end

		local winningRole = modeConfig.winRole

		if ReplicatedStorage:GetAttribute("Ranked") and winningRole == "Runner" then ClockInterface.updateRunnerTimesSignal:Fire() end

		if modeConfig.lastPlayerStanding then
			local lastPlayerStanding = RoundUtils.CheckIfLastPlayerStanding()

			if lastPlayerStanding then
				workspace:SetAttribute("TimeLeft", 0)
				timeLeft = 1
			else
				workspace:SetAttribute("TimeLeft", timeLeft - 1)
			end
		else
			workspace:SetAttribute("TimeLeft", timeLeft - 1)
		end

		if timeLeft - 1 == 0 then
			local winners = {}

			if winningRole then
				for _, player in players do
					if player.Character and player.Character:GetAttribute("Role") == winningRole then table.insert(winners, player) end
				end
			end

			ClockInterface.roundEndedSignal:Fire(winners)
		end
	end
end

return Schedules.Boot.job(initTimer)
