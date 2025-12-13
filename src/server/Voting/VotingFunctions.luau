local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AllowedMaps = require(ReplicatedStorage.Shared.Configs.Voting.AllowedMaps)
local AllowedModes = require(ReplicatedStorage.Shared.Configs.Voting.AllowedModes)
local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local Net = require(ReplicatedStorage.Packages.Net)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)
local VotingInterface = require(ServerStorage.Modules.Voting.VotingInterface)

local StartClientVotingRE = Net:RemoteEvent("StartClientVoting")
local EndClientVotingRE = Net:RemoteEvent("EndClientVoting")

local VotingFunctions = {}

local function getRandomItem(n, items)
	local chosenItems = {}

	for _ = 1, n do
		if #items < n then break end

		local newItem
		local tries = 0
		local maxTries = 10

		repeat
			newItem = items[math.random(1, #items)]
			tries = tries + 1
		until not table.find(chosenItems, newItem) or tries >= maxTries

		if not table.find(chosenItems, newItem) then table.insert(chosenItems, newItem) end
	end

	return chosenItems
end

function VotingFunctions.GetVotesLUT()
	local votesLUT = {}

	for _, currentMap in VotingInterface.currentMaps do
		votesLUT[currentMap] = 0
	end

	for _, currentMode in VotingInterface.currentModes do
		votesLUT[currentMode] = 0
	end

	for _, voteName in VotingInterface.votes do
		votesLUT[voteName] += 1
	end

	return votesLUT
end

function VotingFunctions.StartVoting(voteType)
	VotingInterface.votes = {}

	if voteType == "map" then
		VotingInterface.currentMaps = getRandomItem(2, AllowedMaps)
	elseif voteType == "mode" then
		VotingInterface.currentModes = getRandomItem(3, AllowedModes[workspace:GetAttribute("Map") or "Crossroads"])
	end

	ClockInterface.roundEndedSignal:Once(function()
		if workspace:GetAttribute("Gamemode") ~= "Voting" then return end

		VotingFunctions.EndVoting()
	end)

	StartClientVotingRE:FireAllClients(voteType == "map" and VotingInterface.currentMaps or VotingInterface.currentModes)
end

function VotingFunctions.EndVoting()
	EndClientVotingRE:FireAllClients()

	local chosenMode
	local highestVote = -1

	for mode, votes in VotingFunctions.GetVotesLUT() do
		if votes <= highestVote then continue end

		highestVote = votes
		chosenMode = mode
	end

	task.delay(1.5, function()
		RoundManager.SetMode(chosenMode)
	end)
end

return VotingFunctions
