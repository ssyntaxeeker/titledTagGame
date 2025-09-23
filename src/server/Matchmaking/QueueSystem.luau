local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local Net = require(ReplicatedStorage.Packages.Net)

local QueuePlayerRE = Net:RemoteFunction("QueuePlayer")
local DequeuePlayerRE = Net:RemoteFunction("DequeuePlayer")

QueuePlayerRE.OnServerInvoke = function(player)
	if table.find(MatchmakingInterface.queuedPlayers, player) then return end

	table.insert(MatchmakingInterface.queuedPlayers, player)
	ReplicatedStorage:SetAttribute("PlayersInQueue", #MatchmakingInterface.queuedPlayers)
end

DequeuePlayerRE.OnServerInvoke = function(player)
	local index = table.find(MatchmakingInterface.queuedPlayers, player)
	if not index then return end

	table.remove(MatchmakingInterface.queuedPlayers, index)
	ReplicatedStorage:SetAttribute("PlayersInQueue", #MatchmakingInterface.queuedPlayers)
end

return 0
