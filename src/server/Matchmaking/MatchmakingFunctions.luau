local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")

local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local Net = require(ReplicatedStorage.Packages.Net)
local Profiles = require(ServerStorage.Modules.Data.Profiles)

local UpdateClientScoresRE = Net:RemoteEvent("UpdateClientScores")
local SetTeleportingStatusRE = Net:RemoteEvent("SetTeleportingStatus")

local MatchmakingFunctions = {}

local queueTimestamps = {}

local BASE_TOLERANCE = 50
local TOLERANCE_GROWTH = 25

local function getPlayerElo(player)
	local proxy = Profiles.ReturnProxy(player)

	if not proxy then return 0 end

	return tonumber(proxy.ELO)
end

local function getDynamicTolerance(player)
	local joinedAt = queueTimestamps[player]
	if not joinedAt then return BASE_TOLERANCE end

	local timeInQueue = os.clock() - joinedAt
	return BASE_TOLERANCE + (timeInQueue * TOLERANCE_GROWTH)
end

function MatchmakingFunctions.CreateMatch(playerA, playerB)
	SetTeleportingStatusRE:FireClient(playerA, "teleporting")
	SetTeleportingStatusRE:FireClient(playerB, "teleporting")

	print(playerA.Name .. " vs " .. playerB.Name)

	queueTimestamps[playerA] = nil
	queueTimestamps[playerB] = nil

	local serverCode = TeleportService:ReserveServer(game.PlaceId)

	TeleportService:TeleportToPrivateServer(game.PlaceId, serverCode, { playerA, playerB }, nil, {
		Ranked = true,
		RankedVersion = 1,
		Participants = { playerA.UserId, playerB.UserId },
	})
end

function MatchmakingFunctions.TryMatchPlayers()
	if #MatchmakingInterface.queuedPlayers < 2 then return end

	table.sort(MatchmakingInterface.queuedPlayers, function(playerA, playerB)
		return getPlayerElo(playerA) < getPlayerElo(playerB)
	end)

	local matchedPlayers = {}

	for i = 1, #MatchmakingInterface.queuedPlayers - 1 do
		local playerA = MatchmakingInterface.queuedPlayers[i]
		local playerB = MatchmakingInterface.queuedPlayers[i + 1]

		if playerA and playerB then
			local eloA = getPlayerElo(playerA)
			local eloB = getPlayerElo(playerB)

			local tolerance = math.max(getDynamicTolerance(playerA), getDynamicTolerance(playerB))

			if math.abs(eloA - eloB) <= tolerance then
				MatchmakingFunctions.CreateMatch(playerA, playerB)

				table.insert(matchedPlayers, playerA)
				table.insert(matchedPlayers, playerB)
			end
		end
	end

	for _, matchedPlayer in matchedPlayers do
		local index = table.find(MatchmakingInterface.queuedPlayers, matchedPlayer)
		if index then table.remove(MatchmakingInterface.queuedPlayers, index) end
	end

	ReplicatedStorage:SetAttribute("PlayersInQueue", #MatchmakingInterface.queuedPlayers)
end

function MatchmakingFunctions.AddToQueue(player)
	queueTimestamps[player] = os.clock()
end

function MatchmakingFunctions.RemoveFromQueue(player)
	queueTimestamps[player] = nil
end

function MatchmakingFunctions.SetScore(player, score)
	MatchmakingInterface.scores[player.UserId] = score

	UpdateClientScoresRE:FireAllClients(MatchmakingInterface.scores)
end

function MatchmakingFunctions.GiveHeadToHeadElo(playerA, playerB, resultA, K)
	K = K or 32
	assert(resultA >= 0 and resultA <= 1, "[MatchmakingFunctions.GiveHeadToHeadElo] resultA must be within 0..1")
	local proxyA = Profiles.ReturnProxy(playerA)
	local proxyB = Profiles.ReturnProxy(playerB)
	assert(proxyA, `[MatchmakingFunctions.GiveHeadToHeadElo] {playerA.Name} has no profile`)
	assert(proxyB, `[MatchmakingFunctions.GiveHeadToHeadElo] {playerB.Name} has no profile`)

	local eloA = tonumber(proxyA.ELO)
	local eloB = tonumber(proxyB.ELO)
	assert(eloA and eloB, "[MatchmakingFunctions.GiveHeadToHeadElo] both players require numeric ELO")
	local expectedA = 1 / (1 + 10 ^ ((eloB - eloA) / 400))
	local rawDelta = K * (resultA - expectedA)
	local deltaA = if rawDelta >= 0 then math.floor(rawDelta + 0.5) else math.ceil(rawDelta - 0.5)
	local deltaB = -deltaA
	proxyA.ELO = eloA + deltaA
	proxyB.ELO = eloB + deltaB
	playerA:SetAttribute("RankedRatingDelta", deltaA)
	playerB:SetAttribute("RankedRatingDelta", deltaB)
	return deltaA, deltaB
end

return MatchmakingFunctions
