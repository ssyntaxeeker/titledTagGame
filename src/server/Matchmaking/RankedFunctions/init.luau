local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")

local MatchmakingFunctions = require(ServerStorage.Modules.Matchmaking.MatchmakingFunctions)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local Profiles = require(ServerStorage.Modules.Data.Profiles)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)

local ClassicRound = require(script.ClassicRound)
local Helpers = require(script.Helpers)
local InfFFARound = require(script.InfFFARound)
local RankedMatchConfig = require(script.RankedMatchConfig)
local ScoreProcessing = require(script.ScoreProcessing)

local Assets = ReplicatedStorage.Assets

local RankedFunctions = {}

local function waitForProfile(player: Player): any
	local deadline = os.clock() + 20
	repeat
		local proxy = Profiles.ReturnProxy(player)
		if proxy then return proxy end
		if player.Parent ~= Players then
			error(`[RankedFunctions.waitForProfile] {player.Name} left before profile loading completed`)
		end
		task.wait(0.1)
	until os.clock() >= deadline
	error(`[RankedFunctions.waitForProfile] {player.Name} profile did not load within 20 seconds`)
end

local function getHighestScore(): number
	local highestScore = 0
	for _, score in MatchmakingInterface.scores do
		if score > highestScore then highestScore = score end
	end
	return highestScore
end

local function teleportPlayers(players)
	local succeeded, message = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players)
	end)
	if not succeeded then warn(`[RankedFunctions] Failed to return players after match end:\n{message}`) end
end

local function runMatch(players)
	assert(#players == 2, `[RankedFunctions.runMatch] ranked requires exactly 2 players, received {#players}`)
	assert(RankedMatchConfig.stages[1].kind == "Classic", "[RankedFunctions.runMatch] first ranked stage must be Classic")
	assert(RankedMatchConfig.stages[1].mapName == "Crossroads", "[RankedFunctions.runMatch] first ranked map must be Crossroads")
	MatchmakingInterface.scores = {}
	MatchmakingInterface.runnerTimes = {}
	for _, player in players do
		MatchmakingFunctions.SetScore(player, 0)
	end
	MatchmakingInterface.rankedAwardsEnabled = true
	ReplicatedStorage:SetAttribute("RankedMatchStatus", "Running")
	ReplicatedStorage:SetAttribute("RankedStageCount", #RankedMatchConfig.stages)
	ReplicatedStorage:SetAttribute("RankedPointsToWin", RankedMatchConfig.pointsToWin)

	local cycle = 0
	local roundNumber = 0
	local classicRound = 0
	while getHighestScore() < RankedMatchConfig.pointsToWin do
		cycle += 1
		ReplicatedStorage:SetAttribute("RankedCycle", cycle)
		for stageIndex, stage in RankedMatchConfig.stages do
			local map = Assets.Maps:FindFirstChild(stage.mapName)
			assert(map, `[RankedFunctions.runMatch] Assets.Maps.{stage.mapName} disappeared`)
			for _, player in players do
				assert(player.Parent == Players, `[RankedFunctions.runMatch] {player.Name} left during ranked`)
			end

			roundNumber += 1
			ReplicatedStorage:SetAttribute("RoundNumber", roundNumber)
			ReplicatedStorage:SetAttribute("RankedStage", stageIndex)
			ReplicatedStorage:SetAttribute("RankedMap", stage.mapName)
			ReplicatedStorage:SetAttribute("RankedRoundType", stage.kind)
			ReplicatedStorage:SetAttribute("RankedMatchStatus", "Loading")
			if stage.kind == "Classic" then
				classicRound += 1
				ReplicatedStorage:SetAttribute("RankedClassicRound", classicRound)
				ClassicRound.run(players, map, classicRound, RankedMatchConfig)
			elseif stage.kind == "FFA" then
				InfFFARound.run(players, map, stage.killsToWin, RankedMatchConfig.countdownSeconds)
			else
				error(`[RankedFunctions.runMatch] unsupported stage kind {stage.kind}`)
			end
			ReplicatedStorage:SetAttribute("RankedMatchStatus", "RoundResult")

			if getHighestScore() >= RankedMatchConfig.pointsToWin then break end
			task.wait(RankedMatchConfig.interStageSeconds)
		end
	end

	ReplicatedStorage:SetAttribute("RankedMatchStatus", "Results")
	ScoreProcessing.processFinalScores()
end

function RankedFunctions.StartRanked()
	ReplicatedStorage:SetAttribute("Ranked", true)
	ReplicatedStorage:SetAttribute("RoundNumber", 0)
	ReplicatedStorage:SetAttribute("RankedMatchStatus", "Starting")
	MatchmakingInterface.rankedAwardsEnabled = false
	MatchmakingInterface.ratingAwarded = false

	local players = Players:GetPlayers()
	if #players < 2 then
		repeat
			Players.PlayerAdded:Wait()
			players = Players:GetPlayers()
		until #players >= 2
	end
	local ratingSnapshots = {}
	local participantLeavingConnection = Players.PlayerRemoving:Connect(function(leavingPlayer)
		if not table.find(players, leavingPlayer) then return end
		RoundManager.EndRound({}, "Forfeit")
		MatchmakingInterface.killedSignal:Fire(nil)
	end)
	local succeeded, message = xpcall(function()
		for _, rankedPlayer in players do
			local proxy = waitForProfile(rankedPlayer)
			ratingSnapshots[rankedPlayer.UserId] = {
				proxy = proxy,
				elo = proxy.ELO,
			}
		end
		runMatch(players)
	end, debug.traceback)
	participantLeavingConnection:Disconnect()
	MatchmakingInterface.rankedAwardsEnabled = false
	ReplicatedStorage:SetAttribute("Ranked", false)
	if succeeded then
		ReplicatedStorage:SetAttribute("RankedMatchStatus", "Completed")
	else
		ReplicatedStorage:SetAttribute("RankedMatchStatus", if MatchmakingInterface.ratingAwarded then "Forfeit" else "Failed")
		if not MatchmakingInterface.ratingAwarded then
			for _, snapshot in ratingSnapshots do
				snapshot.proxy.ELO = snapshot.elo
			end
		end
		warn(`[RankedFunctions.StartRanked] Ranked match stopped:\n{message}`)
		RoundManager.SetMode("Intermission")
		for _, player in players do
			Helpers.setAnchored(player, false)
		end
	end

	task.wait(if succeeded then 1 else 8)
	teleportPlayers(players)
end

return RankedFunctions
