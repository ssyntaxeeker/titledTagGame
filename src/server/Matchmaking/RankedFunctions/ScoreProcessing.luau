local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local MatchmakingFunctions = require(ServerStorage.Modules.Matchmaking.MatchmakingFunctions)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)

local ScoreProcessing = {}

local function getPlayerFromUserId(userId)
	return Players:GetPlayerByUserId(userId)
end

local function sendDiscordWebhook(scores, topPlayers)
	local message = ""

	local players = {}
	for userId, score in scores do
		local player = game.Players:GetPlayerByUserId(userId)
		if player then table.insert(players, { Name = player.Name, Score = score }) end
	end

	if #topPlayers == 1 then
		local winnerId = topPlayers[1]
		local winner = game.Players:GetPlayerByUserId(winnerId)
		message = string.format("%s (%.2f) vs %s (%.2f) - %s WON", players[1].Name, players[1].Score, players[2].Name, players[2].Score, winner.Name)
	elseif #topPlayers > 1 then
		message = string.format("%s (%.2f) vs %s (%.2f) - TIE", players[1].Name, players[1].Score, players[2].Name, players[2].Score)
	else
		message = "No winner determined"
	end

	local data = HttpService:JSONEncode { content = message }
	HttpService:PostAsync(
		"https://discord.com/api/webhooks/1420457791524438181/OHe-V2KeD7vjMfw6PgVet8QMK0wE0m9onQNPwR-dY0hh6M4BxpEi20bEA4zPUFuILCEY",
		data,
		Enum.HttpContentType.ApplicationJson
	)
end

function ScoreProcessing.processFinalScores()
	local scores = MatchmakingInterface.scores or {}
	local topPlayers = {}
	local highScore = -math.huge

	for player, score in scores do
		if score > highScore then
			highScore = score
			topPlayers = { player }
		elseif score == highScore then
			table.insert(topPlayers, player)
		end
	end

	sendDiscordWebhook(scores, topPlayers)

	if #topPlayers == 1 then
		local finalWinner = topPlayers[1]
		print("FINAL WINNER: " .. getPlayerFromUserId(finalWinner).Name)

		for player, _ in scores do
			if player ~= finalWinner then
				MatchmakingFunctions.GiveElo(getPlayerFromUserId(finalWinner), getPlayerFromUserId(player), 1)
				MatchmakingFunctions.GiveElo(getPlayerFromUserId(player), getPlayerFromUserId(finalWinner), 0)
			end
		end
	elseif #topPlayers > 1 then
		print("DRAW between: ")
		for _, player in topPlayers do
			print(getPlayerFromUserId(player).Name)
		end

		for _, playerA in topPlayers do
			for playerB, _ in scores do
				if playerB ~= playerA then MatchmakingFunctions.GiveElo(getPlayerFromUserId(playerA), getPlayerFromUserId(playerB), 0.5) end
			end
		end
	else
		print("No winner determined")
	end
end

return ScoreProcessing
