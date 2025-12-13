local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local Net = require(ReplicatedStorage.Packages.Net)

local UpdateLeadRunnerRE = Net:RemoteEvent("UpdateLeadRunner")

local leadingRunner = nil

ClockInterface.updateRunnerTimesSignal:Connect(function()
	for _, player in Players:GetPlayers() do
		if player.Character and player.Character:GetAttribute("Role") == "Runner" then
			MatchmakingInterface.runnerTimes[player] = (MatchmakingInterface.runnerTimes[player] or 0) + 1
		end
	end

	local topRunner = nil
	local topTime = -math.huge

	for runner, time in MatchmakingInterface.runnerTimes do
		if time > topTime then
			topTime = time
			topRunner = runner
		end
	end

	if topRunner == leadingRunner then return end

	leadingRunner = topRunner
	UpdateLeadRunnerRE:FireAllClients(leadingRunner.Name)
end)

return 0
