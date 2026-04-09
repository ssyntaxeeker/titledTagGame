local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")

local MatchmakingFunctions = require(ServerStorage.Modules.Matchmaking.MatchmakingFunctions)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)

local ClassicRound = require(script.ClassicRound)
local InfFFARound = require(script.InfFFARound)
local ScoreProcessing = require(script.ScoreProcessing)

local RankedFunctions = {}

local function getHighestScore()
	local scores = MatchmakingInterface.scores or {}
	local highest = 0

	for _, score in scores do
		if score > highest then highest = score end
	end

	return highest
end

function RankedFunctions.StartRanked()
	ReplicatedStorage:SetAttribute("Ranked", true)
	ReplicatedStorage:SetAttribute("RoundNumber", 0)

	local players = Players:GetPlayers()
	if #players < 2 then
		repeat
			Players.PlayerAdded:Wait()
			players = Players:GetPlayers()
		until #players >= 2
	end

	local crossroadsSpawnPositions = {
		CFrame.new(Vector3.new(-1568.627, 162, 992.845)),
		CFrame.new(Vector3.new(-1670.627, 159.75, 933.845)),
	}

	local baseplateSpawnPositions = {
		CFrame.new(Vector3.new(0, 3, 30)),
		CFrame.new(Vector3.new(0, 3, -30)),
	}

	for _, player in players do
		MatchmakingFunctions.SetScore(player, 0)
	end

	local roundNumber = 0

	while getHighestScore() < 4 do
		roundNumber += 1
		ReplicatedStorage:SetAttribute("RoundNumber", roundNumber)

		ClassicRound.run(players, crossroadsSpawnPositions)

		task.wait(1)

		if getHighestScore() >= 4 then break end

		InfFFARound.run(players, baseplateSpawnPositions, 2)
		task.wait(3.5)
	end

	ScoreProcessing.processFinalScores()

	task.wait(1)

	TeleportService:TeleportAsync(game.PlaceId, players)

	return
end

return RankedFunctions
