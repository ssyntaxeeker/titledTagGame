local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local VotingUIFunctions = require(ReplicatedStorage.Modules.Voting.VotingUIFunctions)

local EndClientVotingRE = Net:RemoteEvent("EndClientVoting")

local function endVoting()
	for _, frame in VotingUIFunctions.GetUI().Frames:GetChildren() do
		if not frame:IsA("Frame") then continue end

		VotingUIFunctions.HideFrame(frame)
		task.wait(0.2)
	end
end

EndClientVotingRE.OnClientEvent:Connect(endVoting)

return 0
