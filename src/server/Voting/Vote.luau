local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local VotingFunctions = require(ServerStorage.Modules.Voting.VotingFunctions)
local VotingInterface = require(ServerStorage.Modules.Voting.VotingInterface)

local VoteRE = Net:RemoteEvent("Vote")
local UpdateClientVotesRE = Net:RemoteEvent("UpdateClientVotes")

local function updateClientVotes()
	local votesLUT = VotingFunctions.GetVotesLUT()

	UpdateClientVotesRE:FireAllClients(votesLUT)
end

VoteRE.OnServerEvent:Connect(function(player, vote)
	if not VotingFunctions.SubmitVote(player, vote) then return end
	updateClientVotes()
end)

return 0
