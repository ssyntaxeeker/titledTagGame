local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local Helpers = require(script.Parent.Helpers)
local MatchmakingFunctions = require(ServerStorage.Modules.Matchmaking.MatchmakingFunctions)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local RankedArena = require(script.Parent.RankedArena)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local ClassicRound = {}

function ClassicRound.run(players, map, classicRound, config)
	assert(map.Name == "Crossroads" or map.Name == "Glasshouses", `[ClassicRound.run] unsupported ranked classic map {map.Name}`)
	assert(
		ChangeMap(map, { preserveSession = false }),
		`[ClassicRound.run] {map.Name} map change was superseded`
	)
	local liveMap = workspace:FindFirstChild("Map")
	assert(liveMap, `[ClassicRound.run] {map.Name} did not load into workspace.Map`)
	assert(workspace:GetAttribute("Map") == map.Name, `[ClassicRound.run] expected {map.Name}, got {tostring(workspace:GetAttribute("Map"))}`)
	local spawns = RankedArena.requireSpawns(liveMap)

	for _, player in players do
		Helpers.waitForCharacter(player)
		Helpers.setAnchored(player, true)
	end

	ReplicatedStorage:SetAttribute("RankedClassicRound", classicRound)
	assert(RoundManager.SetMode("RankedClassic"), "[ClassicRound.run] RankedClassic failed to start")
	workspace:SetAttribute("ModeStatus", `Ranked Classic round {classicRound} - {map.Name}`)
	for index, player in players do
		local startsAsRunner = index % 2 == 1
		local role = if classicRound % 2 == 1
			then if startsAsRunner then "Runner" else "Tagger"
			else if startsAsRunner then "Tagger" else "Runner"
		assert(RolesFunctions.ChangeRole(player, role), `[ClassicRound.run] failed to assign {role} to {player.Name}`)
	end
	for _, player in players do
		local character = Helpers.waitForCharacter(player)
		local role = character:GetAttribute("Role")
		assert(role == "Runner" or role == "Tagger", `[ClassicRound.run] {player.Name} has invalid ranked role {tostring(role)}`)
		local spawn = if role == "Runner" then spawns.runner else spawns.tagger
		Helpers.teleportPlayerToSpawn(player, spawn.CFrame)
	end

	ReplicatedStorage:SetAttribute("RankedMatchStatus", "Countdown")
	task.wait(config.countdownSeconds)
	MatchmakingInterface.runnerTimes = {}
	ClockFunctions.SetTime(config.classicDurationSeconds)
	ReplicatedStorage:SetAttribute("RankedMatchStatus", "ActiveRound")

	for _, player in players do
		Helpers.setAnchored(player, false)
	end

	local winners = ClockInterface.roundEndedSignal:Wait()
	for _, winner in winners do
		MatchmakingFunctions.SetScore(winner, (MatchmakingInterface.scores[winner.UserId] or 0) + 0.25)
	end

	local highestTime = -math.huge
	local longestRunners = {}
	for player, runnerTime in MatchmakingInterface.runnerTimes do
		if runnerTime > highestTime then
			highestTime = runnerTime
			longestRunners = { player }
		elseif runnerTime == highestTime then
			table.insert(longestRunners, player)
		end
	end
	if #longestRunners > 0 then
		local timeScore = 0.75 / #longestRunners
		for _, player in longestRunners do
			MatchmakingFunctions.SetScore(player, (MatchmakingInterface.scores[player.UserId] or 0) + timeScore)
		end
	end
end

return ClassicRound
