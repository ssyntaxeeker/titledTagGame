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
	assert(not MatchmakingInterface.ratingAwarded, "[ScoreProcessing.processFinalScores] rating was already awarded")
	local userIds = {}
	for userId in scores do
		table.insert(userIds, userId)
	end
	assert(#userIds == 2, `[ScoreProcessing.processFinalScores] expected 2 scores, received {#userIds}`)
	local playerA = getPlayerFromUserId(userIds[1])
	local playerB = getPlayerFromUserId(userIds[2])
	assert(playerA and playerB, "[ScoreProcessing.processFinalScores] both ranked players must still be connected")

	local scoreA = scores[userIds[1]]
	local scoreB = scores[userIds[2]]
	local resultA = if scoreA > scoreB then 1 elseif scoreA < scoreB then 0 else 0.5
	MatchmakingFunctions.GiveHeadToHeadElo(playerA, playerB, resultA)
	MatchmakingInterface.ratingAwarded = true

	local topPlayers = if resultA == 1 then { userIds[1] } elseif resultA == 0 then { userIds[2] } else userIds
	local webhookSucceeded, webhookError = pcall(sendDiscordWebhook, scores, topPlayers)
	if not webhookSucceeded then warn(`[ScoreProcessing] Ranked webhook failed: {webhookError}`) end
end

return ScoreProcessing
