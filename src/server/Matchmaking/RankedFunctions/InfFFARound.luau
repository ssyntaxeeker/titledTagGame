local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local Helpers = require(script.Parent.Helpers)
local MatchmakingFunctions = require(ServerStorage.Modules.Matchmaking.MatchmakingFunctions)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)

local Assets = ReplicatedStorage.Assets

local InfFFARound = {}

function InfFFARound.run(players, spawnPositions, killsToScore)
	ChangeMap(Assets.Maps.Baseplate)

	RoundManager.SetMode("Intermission")

	local playerKills = {}
	for _, player in players do
		playerKills[player] = 0
	end

	for _, player in players do
		Helpers.waitForCharacter(player)
		Helpers.setAnchored(player, true)
	end

	for i, player in players do
		local nextIndex = i + 1
		if nextIndex > #spawnPositions then nextIndex = 1 end
		Helpers.teleportPlayerToSpawnFacingNext(player, spawnPositions[i], spawnPositions[nextIndex])
	end

	RoundManager.SetMode("InfFFA")

	for _, player in players do
		Helpers.setAnchored(player, false)
	end

	while true do
		local killer = MatchmakingInterface.killedSignal:Wait()
		if killer and playerKills[killer] ~= nil then
			playerKills[killer] = playerKills[killer] + 1

			local killerCharacter = killer.Character
			if killerCharacter then killerCharacter.Humanoid.Health = killerCharacter.Humanoid.MaxHealth end

			if playerKills[killer] >= killsToScore then
				MatchmakingFunctions.SetScore(killer, (MatchmakingInterface.scores[killer.UserId] or 0) + 1)
				break
			end
		end
	end
end

return InfFFARound
