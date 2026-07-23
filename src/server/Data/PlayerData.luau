local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")

local MatchmakingFunctions = require(ServerStorage.Modules.Matchmaking.MatchmakingFunctions)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local ProfileStore = require(ServerStorage.Packages.ProfileStore)
local Profiles = require(ServerStorage.Modules.Data.Profiles)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local PlayerProfileStore = ProfileStore.New("RELEASE_1", Profiles.PlayerDataTemplate)

local function forfeitRanked(forfeitingPlayer)
	if MatchmakingInterface.ratingAwarded then return end

	local players = Players:GetPlayers()

	local opponents = {}
	for _, player in players do
		if player ~= forfeitingPlayer then table.insert(opponents, player) end
	end

	if #opponents == 0 then return end

	local randomOpponent = opponents[math.random(1, #opponents)]

	MatchmakingFunctions.GiveHeadToHeadElo(forfeitingPlayer, randomOpponent, 0)
	MatchmakingInterface.ratingAwarded = true
	MatchmakingInterface.rankedAwardsEnabled = false
	ReplicatedStorage:SetAttribute("RankedMatchStatus", "Forfeit")

	TeleportService:TeleportAsync(game.PlaceId, Players:GetPlayers())
end

local function initPlayer(player)
	local profile = Profiles.Create(PlayerProfileStore, player)

	if not profile then
		warn(`Profile did not load for {player.Name}`)
		return
	end

	for data, value in profile.Data do
		if typeof(value) == "table" then continue end

		player:SetAttribute(data, value)
	end

	player:SetAttribute("DataReady", true)
end

local function init()
	Players.PlayerAdded:Connect(function(player)
		initPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = Profiles.ReturnProfile(player)

		if profile ~= nil then
			if ReplicatedStorage:GetAttribute("Ranked") and MatchmakingInterface.rankedAwardsEnabled then
				forfeitRanked(player)
			end

			profile:EndSession()
		end
	end)
end

return Schedules["Boot"].job(init)
