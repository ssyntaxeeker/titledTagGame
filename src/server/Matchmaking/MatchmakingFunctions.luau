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

	TeleportService:TeleportToPrivateServer(game.PlaceId, serverCode, { playerA, playerB }, nil, { Ranked = true })
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

function MatchmakingFunctions.GiveElo(player, opponent, result, K)
	K = K or 32
	local playerProxy = Profiles.ReturnProxy(player)
	local opponentProxy = Profiles.ReturnProxy(opponent)

	local playerElo = playerProxy.ELO
	local opponentElo = opponentProxy.ELO

	local expected = 1 / (1 + 10 ^ ((opponentElo - playerElo) / 400))
	local actual = result

	local change = math.floor(K * (actual - expected) + 0.5)

	playerProxy.ELO = playerElo + change
end

return MatchmakingFunctions
