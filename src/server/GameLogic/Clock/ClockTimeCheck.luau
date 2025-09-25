local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local RoundUtils = require(ServerStorage.Modules.GameLogic.Round.RoundUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function initTimer()
	while task.wait(1) do
		local timeLeft = workspace:GetAttribute("TimeLeft")

		if not timeLeft or timeLeft <= 0 then continue end

		local gamemode = workspace:GetAttribute("Gamemode")
		local modeConfig = require(ReplicatedStorage.Shared.Configs.Modes[gamemode])

		local winningRole = modeConfig.winRole

		if ReplicatedStorage:GetAttribute("Ranked") then
			if winningRole == "Runner" then
				for _, player in Players:GetPlayers() do
					if player.Character and player.Character:GetAttribute("Role") == winningRole then
						MatchmakingInterface.runnerTimes[player] = (MatchmakingInterface.runnerTimes[player] or 0) + 1
					end
				end
			end
		end

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
			if not winningRole then continue end

			local winners = {}

			for _, player in Players:GetPlayers() do
				if player.Character and player.Character:GetAttribute("Role") == winningRole then table.insert(winners, player) end
			end

			if ReplicatedStorage:GetAttribute("Ranked") then MatchmakingInterface.roundEndedSignal:Fire(winners) end
		end
	end
end

return Schedules.Boot.job(initTimer)
