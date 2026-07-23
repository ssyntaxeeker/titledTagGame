--!strict
--[[
    BotKnowledge (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Compact transferable action statistics. Geometry keys carry skill quality
    and timing evidence between maps without storing map coordinates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Packages.Net)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type REdge = Types.REdge

export type RMemory = {
	scores: { [string]: number },
	attempts: { [string]: number },
	timing: { [string]: number },
	timingCount: { [string]: number },
	dirtyScores: { [string]: number },
	dirtyAttempts: { [string]: number },
	dirtyTiming: { [string]: number },
	dirtyTimingCount: { [string]: number },
	playerRoutes: { [string]: number },
	dirtyPlayerRoutes: { [string]: number },
	loaded: boolean,
	saving: boolean,
}

local RetrieveMemory = Net:RemoteFunction("RetrieveBotLightweightMemory")
local SaveMemory = Net:RemoteFunction("SaveBotLightweightMemory")
local BotKnowledge = {}

local function edgeKey(edge: REdge): string
	local distance = (edge.target - edge.approach).Magnitude
	local height = math.floor(edge.height * 2 + 0.5) / 2
	local distanceBand = math.floor(distance / 2 + 0.5) * 2
	return `G2:{edge.action}:H{height}:D{distanceBand}`
end

local function routeKey(edge: REdge): string
	local map = Workspace:FindFirstChild("Map")
	local mapAttribute = Workspace:GetAttribute("Map")
	local mapName = if typeof(mapAttribute) == "string"
		then mapAttribute
		elseif map
		then map.Name
		else "Unknown"
	local function point(position: Vector3): string
		return `{math.floor(position.X / 4 + 0.5)}:{math.floor(position.Y / 4 + 0.5)}:{math.floor(position.Z / 4 + 0.5)}`
	end
	return `PR2:{string.sub(mapName, 1, 24)}:{point(edge.approach)}>{point(edge.target)}:{edge.action}`
end

function BotKnowledge.create(): RMemory
	return {
		scores = {}, attempts = {}, timing = {}, timingCount = {},
		dirtyScores = {}, dirtyAttempts = {}, dirtyTiming = {}, dirtyTimingCount = {},
		playerRoutes = {}, dirtyPlayerRoutes = {},
		loaded = false, saving = false,
	}
end

function BotKnowledge.load(memory: RMemory)
	if memory.loaded then return end
	task.spawn(function()
		local success, raw = pcall(function() return RetrieveMemory:InvokeServer() end)
		if success and typeof(raw) == "table" then
			local scores = if typeof(raw.techScores) == "table" then raw.techScores else {}
			local attempts = if typeof(raw.techAttempts) == "table" then raw.techAttempts else {}
			local timing = if typeof(raw.timingSums) == "table" then raw.timingSums else {}
			local timingCount = if typeof(raw.timingSuccesses) == "table" then raw.timingSuccesses else {}
			local playerRoutes = if typeof(raw.playerRouteScores) == "table" then raw.playerRouteScores else {}
			local processed = 0
			for key, value in attempts do
				if typeof(key) == "string" and tonumber(value) then
					memory.attempts[key] = tonumber(value) :: number
					memory.scores[key] = tonumber(scores[key]) or 0
					memory.timing[key] = tonumber(timing[key]) or 0
					memory.timingCount[key] = tonumber(timingCount[key]) or 0
					processed += 1
					if processed % 200 == 0 then task.wait() end
				end
			end
			for key, value in playerRoutes do
				if typeof(key) == "string" and tonumber(value) then memory.playerRoutes[key] = tonumber(value) :: number end
			end
		end
		memory.loaded = true
	end)
end

function BotKnowledge.cost(memory: RMemory, edge: REdge): number
	local key = edgeKey(edge)
	local attempts = memory.attempts[key] or 0
	local skillCost = if attempts > 0
		then math.clamp(-(memory.scores[key] or 0) / attempts * 0.04, -0.6, 1.5)
		else 0
	local playerEvidence = memory.playerRoutes[routeKey(edge)] or 0
	local taughtBias = if edge.taught then math.clamp((edge.taughtEvidence or 0) * 0.004, 0.08, 0.3) else 0
	return skillCost - math.clamp(playerEvidence * 0.025, -0.8, 0.8) - taughtBias
end

function BotKnowledge.recordPlayerRoute(memory: RMemory, edge: REdge, quality: number)
	local key = routeKey(edge)
	local value = math.clamp(quality, 0.1, 8)
	memory.playerRoutes[key] = (memory.playerRoutes[key] or 0) + value
	memory.dirtyPlayerRoutes[key] = (memory.dirtyPlayerRoutes[key] or 0) + value
end

function BotKnowledge.timing(memory: RMemory, edge: REdge, fallback: number): number
	local key = edgeKey(edge)
	local count = memory.timingCount[key] or 0
	return if count > 0 then (memory.timing[key] or 0) / count else fallback
end

function BotKnowledge.record(memory: RMemory, edge: REdge, succeeded: boolean, reward: number, timing: number?)
	local key = edgeKey(edge)
	memory.attempts[key] = (memory.attempts[key] or 0) + 1
	memory.scores[key] = (memory.scores[key] or 0) + reward
	memory.dirtyAttempts[key] = (memory.dirtyAttempts[key] or 0) + 1
	memory.dirtyScores[key] = (memory.dirtyScores[key] or 0) + reward
	local localKey = routeKey(edge)
	local localReward = reward * 0.5
	memory.playerRoutes[localKey] = (memory.playerRoutes[localKey] or 0) + localReward
	memory.dirtyPlayerRoutes[localKey] = (memory.dirtyPlayerRoutes[localKey] or 0) + localReward
	if succeeded and timing then
		memory.timing[key] = (memory.timing[key] or 0) + timing
		memory.timingCount[key] = (memory.timingCount[key] or 0) + 1
		memory.dirtyTiming[key] = (memory.dirtyTiming[key] or 0) + timing
		memory.dirtyTimingCount[key] = (memory.dirtyTimingCount[key] or 0) + 1
	end
end

function BotKnowledge.save(memory: RMemory)
	if memory.saving or (next(memory.dirtyAttempts) == nil and next(memory.dirtyPlayerRoutes) == nil) then return end
	memory.saving = true
	local payload = {
		techScores = table.clone(memory.dirtyScores), techAttempts = table.clone(memory.dirtyAttempts),
		timingSums = table.clone(memory.dirtyTiming), timingSuccesses = table.clone(memory.dirtyTimingCount),
		playerRouteScores = table.clone(memory.dirtyPlayerRoutes),
	}
	table.clear(memory.dirtyScores)
	table.clear(memory.dirtyAttempts)
	table.clear(memory.dirtyTiming)
	table.clear(memory.dirtyTimingCount)
	table.clear(memory.dirtyPlayerRoutes)
	task.spawn(function()
		local success = pcall(function() SaveMemory:InvokeServer(payload) end)
		if not success then
			for key, value in payload.techScores do memory.dirtyScores[key] = (memory.dirtyScores[key] or 0) + value end
			for key, value in payload.techAttempts do memory.dirtyAttempts[key] = (memory.dirtyAttempts[key] or 0) + value end
			for key, value in payload.timingSums do memory.dirtyTiming[key] = (memory.dirtyTiming[key] or 0) + value end
			for key, value in payload.timingSuccesses do memory.dirtyTimingCount[key] = (memory.dirtyTimingCount[key] or 0) + value end
			for key, value in payload.playerRouteScores do memory.dirtyPlayerRoutes[key] = (memory.dirtyPlayerRoutes[key] or 0) + value end
		end
		memory.saving = false
	end)
end

return table.freeze(BotKnowledge)
