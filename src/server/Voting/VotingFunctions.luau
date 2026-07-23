--!strict
--[[
    VotingFunctions (Server)
    ========================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Runs one round-scoped vote and rejects stale votes and transitions.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AllowedMaps = require(ReplicatedStorage.Shared.Configs.Voting.AllowedMaps)
local AllowedModes = require(ReplicatedStorage.Shared.Configs.Voting.AllowedModes)
local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local Net = require(ReplicatedStorage.Packages.Net)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)
local VotingInterface = require(ServerStorage.Modules.Voting.VotingInterface)

local StartClientVotingRE = Net:RemoteEvent("StartClientVoting")
local EndClientVotingRE = Net:RemoteEvent("EndClientVoting")

local VotingFunctions = {}

local function getRandomItems(count: number, items: { string }): { string }
	local pool = table.clone(items)
	for index = #pool, 2, -1 do
		local swapIndex = math.random(1, index)
		pool[index], pool[swapIndex] = pool[swapIndex], pool[index]
	end

	local result = {}
	for index = 1, math.min(count, #pool) do
		table.insert(result, pool[index])
	end
	return result
end

function VotingFunctions.GetVotesLUT(): { [string]: number }
	local votesLUT: { [string]: number } = {}
	for _, item in VotingInterface.currentItems do
		votesLUT[item] = 0
	end
	for _, voteName in VotingInterface.votes do
		if votesLUT[voteName] ~= nil then votesLUT[voteName] += 1 end
	end
	return votesLUT
end

function VotingFunctions.StartVoting(voteType: string, roundId: number)
	assert(voteType == "map" or voteType == "mode", "[VotingFunctions.StartVoting] invalid voteType")
	VotingInterface.votes = {}
	VotingInterface.roundId = roundId
	VotingInterface.voteType = voteType

	if voteType == "map" then
		VotingInterface.currentItems = getRandomItems(2, AllowedMaps)
	else
		local mapName = workspace:GetAttribute("Map") or "Crossroads"
		local modes = AllowedModes[mapName]
		assert(modes and #modes > 0, `[VotingFunctions.StartVoting] no modes configured for {mapName}`)
		VotingInterface.currentItems = getRandomItems(3, modes)
	end

	StartClientVotingRE:FireAllClients(VotingInterface.currentItems, roundId, voteType)
end

function VotingFunctions.EndVoting(roundId: number): boolean
	if VotingInterface.roundId ~= roundId or not RoundManager.IsCurrent(roundId) then return false end
	EndClientVotingRE:FireAllClients(roundId)

	local chosenItem: string? = nil
	local highestVote = -1
	for item, votes in VotingFunctions.GetVotesLUT() do
		if votes > highestVote then
			highestVote = votes
			chosenItem = item
		end
	end
	if not chosenItem then
		warn("[VotingFunctions.EndVoting] vote had no candidates")
		return false
	end

	local selected = chosenItem
	local voteType = VotingInterface.voteType
	VotingInterface.roundId = 0
	task.delay(1.5, function()
		if not RoundManager.IsCurrent(roundId) then return end
		if voteType == "map" then
			local mapAsset = ReplicatedStorage.Assets.Maps:FindFirstChild(selected)
			if not mapAsset then
				warn(`[VotingFunctions.EndVoting] selected map {selected} is missing`)
				return
			end
				if ChangeMap(mapAsset :: any, { preserveSession = false }) then RoundManager.SetMode("Voting") end
			return
		end
		RoundManager.SetMode(selected)
	end)
	return true
end

function VotingFunctions.CancelVoting(roundId: number)
	if VotingInterface.roundId ~= roundId then return end
	VotingInterface.roundId = 0
	VotingInterface.votes = {}
	VotingInterface.currentItems = {}
	EndClientVotingRE:FireAllClients(roundId)
end

function VotingFunctions.SubmitVote(player: Player, vote: any): boolean
	if workspace:GetAttribute("Gamemode") ~= "Voting" or workspace:GetAttribute("RoundState") ~= "Running" then return false end
	if VotingInterface.roundId ~= workspace:GetAttribute("RoundId") then return false end
	if vote ~= nil and (type(vote) ~= "string" or not table.find(VotingInterface.currentItems, vote)) then return false end
	VotingInterface.votes[player] = vote
	return true
end

return VotingFunctions
