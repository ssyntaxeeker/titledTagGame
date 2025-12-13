local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrightenColor = require(ReplicatedStorage.Vendor.BrightenColor)
local Net = require(ReplicatedStorage.Packages.Net)
local VotingUIFunctions = require(ReplicatedStorage.Modules.Voting.VotingUIFunctions)

local StartClientVotingRE = Net:RemoteEvent("StartClientVoting")

StartClientVotingRE.OnClientEvent:Connect(function(items)
	local frames = {}

	for _, mode in items do
		local modeConfig = require(ReplicatedStorage.Shared.Configs.Modes[mode])

		table.insert(
			frames,
			VotingUIFunctions.CreateFrame(modeConfig.UIImage, modeConfig.Name, { modeConfig.UIGlow, BrightenColor(modeConfig.UIGlow, 1.7) }, mode)
		)
	end

	for _, frame in frames do
		VotingUIFunctions.HookFrame(frame)
		VotingUIFunctions.ShowFrame(frame)
		task.wait(0.2)
	end
end)

return 0
