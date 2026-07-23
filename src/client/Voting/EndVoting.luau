local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local VotingUIFunctions = require(ReplicatedStorage.Modules.Voting.VotingUIFunctions)

local EndClientVotingRE = Net:RemoteEvent("EndClientVoting")

local function endVoting(roundId)
	VotingUIFunctions.EndSession(roundId)
end

EndClientVotingRE.OnClientEvent:Connect(endVoting)

return 0
