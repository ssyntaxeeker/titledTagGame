--!strict
--[[
    IndividualELOLeaderboard (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Mirrors loaded player ELO into the all-time ordered leaderboard and serves
    cached leaderboard pages to clients.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderboards = require(ReplicatedStorage.Shared.Configs.Leaderboards)
local Net = require(ReplicatedStorage.Packages.Net)
local OrderedLeaderboardService = require(script.Parent.OrderedLeaderboardService)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local categories = Leaderboards.categories :: { [string]: { dataStoreName: string, playerAttribute: string } }

local GetLeaderboardRF = Net:RemoteFunction("GetAllTimeLeaderboard")
local connections: { [Player]: RBXScriptConnection } = {}
local lastRequests: { [Player]: number } = {}

local function observePlayer(player: Player)
	if connections[player] then return end
	local function publish()
		local elo = player:GetAttribute("ELO")
		if typeof(elo) == "number" then
			OrderedLeaderboardService.setScore("IndividualELO", player.UserId, elo)
		end
	end
	if player:GetAttribute("DataReady") == true then publish() end
	connections[player] = player:GetAttributeChangedSignal("ELO"):Connect(publish)
end

local function init()
	Players.PlayerAdded:Connect(observePlayer)
	Players.PlayerRemoving:Connect(function(player)
		local connection = connections[player]
		if connection then connection:Disconnect() end
		connections[player] = nil
		lastRequests[player] = nil
	end)
	for _, player in Players:GetPlayers() do observePlayer(player) end
	GetLeaderboardRF.OnServerInvoke = function(player: Player, category: any, requestedCount: any)
		if typeof(category) ~= "string" or categories[category] == nil then return {} end
		local now = os.clock()
		local lastRequest = lastRequests[player]
		if lastRequest and now - lastRequest < 2 then return {} end
		lastRequests[player] = now
		local rawCount = if typeof(requestedCount) == "number" then requestedCount else 50
		local count = if rawCount <= 10 then 10 elseif rawCount <= 25 then 25 elseif rawCount <= 50 then 50 else 100
		return OrderedLeaderboardService.getTop(category, count)
	end
end

return Schedules.Boot.job(init)
