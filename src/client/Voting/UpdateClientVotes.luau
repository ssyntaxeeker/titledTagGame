local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local VotingUIFunctions = require(ReplicatedStorage.Modules.Voting.VotingUIFunctions)

local UpdateClientVotesRE = Net:RemoteEvent("UpdateClientVotes")

UpdateClientVotesRE.OnClientEvent:Connect(VotingUIFunctions.UpdateVotes)

return 0
