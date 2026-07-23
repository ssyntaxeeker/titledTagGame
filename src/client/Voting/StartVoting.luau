local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrightenColor = require(ReplicatedStorage.Vendor.BrightenColor)
local Net = require(ReplicatedStorage.Packages.Net)
local VotingUIFunctions = require(ReplicatedStorage.Modules.Voting.VotingUIFunctions)

local StartClientVotingRE = Net:RemoteEvent("StartClientVoting")

StartClientVotingRE.OnClientEvent:Connect(function(items, roundId, voteType)
	VotingUIFunctions.BeginSession(roundId, voteType)
	VotingUIFunctions.SetActive(true)
	local frames = {}

	for _, mode in items do
		local modeConfig
		if voteType == "map" then
			local mapAsset = ReplicatedStorage.Assets.Maps:FindFirstChild(mode)
			local mapGlow = if mapAsset then mapAsset:GetAttribute("UIGlow") else nil
			modeConfig = {
				UIImage = if mapAsset then mapAsset:GetAttribute("UIImage") or "" else "",
				Name = mode,
				UIGlow = if typeof(mapGlow) == "Color3" then mapGlow else Color3.fromRGB(180, 180, 180),
			}
		else
			modeConfig = require(ReplicatedStorage.Shared.Configs.Modes[mode])
		end

		table.insert(
			frames,
			VotingUIFunctions.CreateFrame(modeConfig.UIImage, modeConfig.Name, { modeConfig.UIGlow, BrightenColor(modeConfig.UIGlow, 1.7) }, mode)
		)
	end

	for _, frame in frames do
		if not VotingUIFunctions.IsSession(roundId) then return end
		VotingUIFunctions.HookFrame(frame)
		VotingUIFunctions.ShowFrame(frame)
	end
end)

return 0
