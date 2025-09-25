local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MatchmakingFunctions = require(ServerStorage.Modules.Matchmaking.MatchmakingFunctions)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local QueuePlayerRE = Net:RemoteFunction("QueuePlayer")
local DequeuePlayerRE = Net:RemoteFunction("DequeuePlayer")

QueuePlayerRE.OnServerInvoke = function(player)
	if table.find(MatchmakingInterface.queuedPlayers, player) then return end

	table.insert(MatchmakingInterface.queuedPlayers, player)
	MatchmakingFunctions.AddToQueue(player)

	ReplicatedStorage:SetAttribute("PlayersInQueue", #MatchmakingInterface.queuedPlayers)
end

DequeuePlayerRE.OnServerInvoke = function(player)
	local index = table.find(MatchmakingInterface.queuedPlayers, player)
	if not index then return end

	table.remove(MatchmakingInterface.queuedPlayers, index)
	MatchmakingFunctions.RemoveFromQueue(player)
	ReplicatedStorage:SetAttribute("PlayersInQueue", #MatchmakingInterface.queuedPlayers)
end

local function init()
	task.spawn(function()
		while task.wait(1) do
			MatchmakingFunctions.TryMatchPlayers()
		end
	end)
end

return Schedules.Boot.job(init)
