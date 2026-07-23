--!strict
--[[
    InfFFARound (Server)
    ====================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Runs the kill-limited ranked FFA stage with explicit setup and countdown.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local Helpers = require(script.Parent.Helpers)
local MatchmakingFunctions = require(ServerStorage.Modules.Matchmaking.MatchmakingFunctions)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)

local InfFFARound = {}

function InfFFARound.run(players: { Player }, map: Instance, killsToScore: number, countdownSeconds: number)
	assert(#players == 2, `[InfFFARound.run] ranked FFA requires 2 players, received {#players}`)
	assert(killsToScore > 0, "[InfFFARound.run] killsToScore must be positive")
	assert(
		ChangeMap(map, { preserveSession = false }),
		`[InfFFARound.run] {map.Name} map change was superseded`
	)
	local liveMap = workspace:FindFirstChild("Map")
	assert(liveMap, `[InfFFARound.run] {map.Name} did not load into workspace.Map`)
	assert(workspace:GetAttribute("Map") == map.Name, `[InfFFARound.run] expected {map.Name}, got {tostring(workspace:GetAttribute("Map"))}`)

	local playerKills: { [Player]: number } = {}
	for _, player in players do
		assert(player.Parent == Players, `[InfFFARound.run] {player.Name} left before FFA setup`)
		playerKills[player] = 0
		player:SetAttribute("RankedFFAKills", 0)
		Helpers.waitForCharacter(player)
		Helpers.setAnchored(player, true)
	end

	ReplicatedStorage:SetAttribute("RankedFFAKillsToWin", killsToScore)
	assert(RoundManager.SetMode("RankedFFA"), "[InfFFARound.run] RankedFFA failed to start")

	for _, player in players do
		local character = Helpers.waitForCharacter(player)
		assert(character:GetAttribute("Role") == "Alone", `[InfFFARound.run] {player.Name} was not assigned Alone`)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		assert(humanoid, `[InfFFARound.run] {player.Name} has no Humanoid`)
		humanoid.Health = humanoid.MaxHealth
		character:SetAttribute("NTBDurability", 0)
	end

	workspace:SetAttribute("ModeStatus", `{map.Name} - ranked FFA starts in {countdownSeconds}s`)
	ReplicatedStorage:SetAttribute("RankedMatchStatus", "Countdown")
	task.wait(countdownSeconds)

	workspace:SetAttribute("ModeStatus", `{map.Name} - first to {killsToScore} kills (0 - 0)`)
	ReplicatedStorage:SetAttribute("RankedMatchStatus", "ActiveRound")
	for _, player in players do
		Helpers.setAnchored(player, false)
	end

	while true do
		local killer = MatchmakingInterface.killedSignal:Wait()
		if killer == nil then error("[InfFFARound.run] ranked participant left during FFA") end
		local kills = playerKills[killer]
		if kills == nil then continue end

		kills += 1
		playerKills[killer] = kills
		killer:SetAttribute("RankedFFAKills", kills)
		workspace:SetAttribute(
			"ModeStatus",
			`{map.Name} - first to {killsToScore} kills ({playerKills[players[1]]} - {playerKills[players[2]]})`
		)

		if kills >= killsToScore then
			MatchmakingFunctions.SetScore(killer, (MatchmakingInterface.scores[killer.UserId] or 0) + 1)
			assert(RoundManager.EndRound({ killer }, "KillLimit"), "[InfFFARound.run] failed to end ranked FFA")
			break
		end
	end
end

return InfFFARound
