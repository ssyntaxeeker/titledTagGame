local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local Dev = require(ReplicatedStorage.Shared.Configs.Dev)
local RankedFunctions = require(ServerStorage.Modules.Matchmaking.RankedFunctions)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local function playerJoinedRanked(player: Player): boolean
	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	return typeof(teleportData) == "table" and teleportData.Ranked == true
end

-- Matchmaking uses ReserveServer, whose owner id is always zero. Keep this as
-- the authoritative fallback because relying on one arrival's TeleportData can
-- incorrectly start voting when the paired players reach the server separately.
local function isRankedServer(): boolean
	if RunService:IsStudio() and Dev.ranked == true then return true end
	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then return true end
	for _, player in Players:GetPlayers() do
		if playerJoinedRanked(player) then return true end
	end
	return false
end

local function startGame()
	task.spawn(function()
		if #Players:GetPlayers() == 0 then Players.PlayerAdded:Wait() end

		task.wait(1)

		if isRankedServer() then
			RankedFunctions.StartRanked()
		elseif Dev.autoStartAIPlayground then
			local map = Assets.Maps:FindFirstChild("AIPlayground")
			assert(map, "[StartGame] autoStartAIPlayground requires Assets.Maps.AIPlayground")

			ChangeMap(map, { preserveSession = false })
			RoundManager.SetMode("InfClassic")
		elseif RunService:IsStudio() and Dev.studioAutoStartInfClassic then
			ChangeMap(Assets.Maps.Crossroads, { preserveSession = false })
			RoundManager.SetMode("InfClassic")
		else
			ChangeMap(Assets.Maps.Crossroads, { preserveSession = false })
			RoundManager.SetMode("Voting")
		end
	end)
end

return Schedules.Boot.job(startGame)
