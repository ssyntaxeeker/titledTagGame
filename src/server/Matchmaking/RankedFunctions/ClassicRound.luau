local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local Helpers = require(script.Parent.Helpers)
local MatchmakingFunctions = require(ServerStorage.Modules.Matchmaking.MatchmakingFunctions)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)

local Assets = ReplicatedStorage.Assets

local ClassicRound = {}

function ClassicRound.run(players, spawnPositions)
	local map = workspace:FindFirstChild("Map")

	ChangeMap(Assets.Maps.Crossroads)

	RoundManager.SetMode("Intermission")
	for _, player in players do
		Helpers.waitForCharacter(player)
		Helpers.setAnchored(player, true)
	end

	if not map then task.wait(2) end

	for i, player in players do
		local nextIndex = i + 1
		if nextIndex > #spawnPositions then nextIndex = 1 end
		Helpers.teleportPlayerToSpawnFacingNext(player, spawnPositions[i], spawnPositions[nextIndex])
	end

	RoundManager.SetMode("RankedClassic")
	ClockFunctions.SetTime(125)

	task.wait(4.5)

	for _, player in players do
		Helpers.setAnchored(player, false)
	end

	task.wait(1.5)

	MatchmakingInterface.runnerTimes = {}

	ClockInterface.roundEndedSignal:Once(function(winners)
		for _, winner in winners do
			MatchmakingFunctions.SetScore(winner, (MatchmakingInterface.scores[winner.UserId] or 0) + 0.25)
		end

		local mostRunnerTimePlayer
		local highestTime = 0

		for player, runnerTime in MatchmakingInterface.runnerTimes do
			if runnerTime > highestTime then
				highestTime = runnerTime
				mostRunnerTimePlayer = player
			end
		end

		if mostRunnerTimePlayer then
			MatchmakingFunctions.SetScore(mostRunnerTimePlayer, (MatchmakingInterface.scores[mostRunnerTimePlayer.UserId] or 0) + 0.75)
		end
	end)

	ClockInterface.roundEndedSignal:Wait()
end

return ClassicRound
