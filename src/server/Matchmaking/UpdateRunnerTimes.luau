local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local Net = require(ReplicatedStorage.Packages.Net)

local UpdateLeadRunnerRE = Net:RemoteEvent("UpdateLeadRunner")

ClockInterface.updateRunnerTimesSignal:Connect(function()
	local players = Players:GetPlayers()
	for _, player in players do
		if player.Character and player.Character:GetAttribute("Role") == "Runner" then
			MatchmakingInterface.runnerTimes[player] = (MatchmakingInterface.runnerTimes[player] or 0) + 1
		end
	end

	local topRunner = nil
	local topTime = -math.huge

	for _, runner in players do
		local time = MatchmakingInterface.runnerTimes[runner] or 0
		if time > topTime then
			topTime = time
			topRunner = runner
		end
	end

	if not topRunner then return end
	local secondHighestTime = 0
	for _, player in players do
		if player ~= topRunner then
			secondHighestTime = math.max(secondHighestTime, MatchmakingInterface.runnerTimes[player] or 0)
		end
	end
	UpdateLeadRunnerRE:FireAllClients(topRunner.Name, topTime - secondHighestTime)
end)

return 0
