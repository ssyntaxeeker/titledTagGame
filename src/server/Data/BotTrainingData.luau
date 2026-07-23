--!strict
--[[
    BotTrainingData (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Server-owned global API for bot trainer learning versions. Every player
    reads and writes the same compact learning data so route and tech memory
    can be built collaboratively across sessions.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

type RoleName = "tagger" | "runner"

type VersionInfo = {
	id: string,
	role: RoleName,
	name: string,
	favorite: boolean,
	createdAt: number,
	updatedAt: number,
	saves: number,
	summary: { [string]: any },
	learning: { [string]: any },
}

local RetrieveBotTrainingDataRF = Net:RemoteFunction("RetrieveBotTrainingData")
local SaveBotLearningVersionRF = Net:RemoteFunction("SaveBotLearningVersion")
local FavoriteBotLearningVersionRF = Net:RemoteFunction("FavoriteBotLearningVersion")
local DeleteBotLearningVersionRF = Net:RemoteFunction("DeleteBotLearningVersion")
local SelectBotLearningVersionRF = Net:RemoteFunction("SelectBotLearningVersion")
local RetrieveBotLightweightMemoryRF = Net:RemoteFunction("RetrieveBotLightweightMemory")
local SaveBotLightweightMemoryRF = Net:RemoteFunction("SaveBotLightweightMemory")

local GLOBAL_STORE_NAME = "TitledTagGameBotTrainingData"
local GLOBAL_DATA_KEY = "GlobalLearning_v1"
local GlobalBotTrainingStore = DataStoreService:GetDataStore(GLOBAL_STORE_NAME)

local MAX_NON_FAVORITE_VERSIONS = 5
local MAX_GRAPH_NODES = 650
local MAX_DIRECTION_SCORES = 16
local MAX_SLIDE_SCORES = 32
local MAX_TECH_SCORES = 64
local MAX_ROUTES = 10
local MAX_ROUTE_POINTS = 80
local MAX_LIGHTWEIGHT_MAP_ENTRIES = 2400

local globalTrainingData: { [string]: any }? = nil
local globalDataLoaded = false

local function isRoleName(role: any): boolean
	return role == "tagger" or role == "runner"
end

local function newSharedData(): { [string]: any }
	return {
		tagger = {
			versions = {},
			activeVersionId = nil,
		},
		runner = {
			versions = {},
			activeVersionId = nil,
		},
		LightweightMemory = {
			edgeScores = {},
			edgeAttempts = {},
			techScores = {},
			techAttempts = {},
			deadEndScores = {},
			areaScores = {},
			areaAttempts = {},
			playerRouteScores = {},
			timingSums = {},
			timingSuccesses = {},
			updatedAt = 0,
			saves = 0,
		},
	}
end

local function sanitizeLightweightNumberMap(map: any, minValue: number, maxValue: number): { [string]: number }
	local keyedValues = {}
	local keys = {}

	if typeof(map) ~= "table" then return keyedValues end

	for key, value in map do
		if typeof(key) ~= "string" then continue end

		local numberValue = tonumber(value)
		if not numberValue then continue end

		local safeKey = string.sub(key, 1, 96)
		keyedValues[safeKey] = math.clamp(numberValue, minValue, maxValue)
		table.insert(keys, safeKey)
	end

	table.sort(keys, function(left, right)
		local leftTaught = string.sub(left, 1, 4) == "TR3:" or string.sub(left, 1, 4) == "TT3:"
		local rightTaught = string.sub(right, 1, 4) == "TR3:" or string.sub(right, 1, 4) == "TT3:"
		if leftTaught ~= rightTaught then return leftTaught end
		return math.abs(keyedValues[left]) > math.abs(keyedValues[right])
	end)

	local result = {}
	for index, key in keys do
		if index > MAX_LIGHTWEIGHT_MAP_ENTRIES then break end
		result[key] = keyedValues[key]
	end

	return result
end

local function sanitizeLightweightMemory(memory: any): { [string]: any }
	return {
		edgeScores = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.edgeScores else nil, -500, 500),
		edgeAttempts = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.edgeAttempts else nil, 0, 100000),
		techScores = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.techScores else nil, -500, 500),
		techAttempts = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.techAttempts else nil, 0, 100000),
		deadEndScores = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.deadEndScores else nil, -500, 500),
		areaScores = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.areaScores else nil, -500, 500),
		areaAttempts = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.areaAttempts else nil, 0, 100000),
		playerRouteScores = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.playerRouteScores else nil, -500, 500),
		timingSums = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.timingSums else nil, 0, 100000),
		timingSuccesses = sanitizeLightweightNumberMap(if typeof(memory) == "table" then memory.timingSuccesses else nil, 0, 100000),
		updatedAt = math.floor(tonumber(if typeof(memory) == "table" then memory.updatedAt else nil) or 0),
		saves = math.clamp(math.floor(tonumber(if typeof(memory) == "table" then memory.saves else nil) or 0), 0, 1000000),
	}
end

local function mergeLightweightNumberMap(existingMap: any, incomingMap: any, minValue: number, maxValue: number): { [string]: number }
	local existing = sanitizeLightweightNumberMap(existingMap, minValue, maxValue)
	local incoming = sanitizeLightweightNumberMap(incomingMap, minValue, maxValue)

	for key, value in incoming do
		existing[key] = math.clamp((existing[key] or 0) + value, minValue, maxValue)
	end

	return sanitizeLightweightNumberMap(existing, minValue, maxValue)
end

local function mergeLightweightMemory(existingMemory: any, incomingMemory: any): { [string]: any }
	local existing = sanitizeLightweightMemory(existingMemory)
	local incoming = sanitizeLightweightMemory(incomingMemory)

	return {
		edgeScores = mergeLightweightNumberMap(existing.edgeScores, incoming.edgeScores, -500, 500),
		edgeAttempts = mergeLightweightNumberMap(existing.edgeAttempts, incoming.edgeAttempts, 0, 100000),
		techScores = mergeLightweightNumberMap(existing.techScores, incoming.techScores, -500, 500),
		techAttempts = mergeLightweightNumberMap(existing.techAttempts, incoming.techAttempts, 0, 100000),
		deadEndScores = mergeLightweightNumberMap(existing.deadEndScores, incoming.deadEndScores, -500, 500),
		areaScores = mergeLightweightNumberMap(existing.areaScores, incoming.areaScores, -500, 500),
		areaAttempts = mergeLightweightNumberMap(existing.areaAttempts, incoming.areaAttempts, 0, 100000),
		playerRouteScores = mergeLightweightNumberMap(existing.playerRouteScores, incoming.playerRouteScores, -500, 500),
		timingSums = mergeLightweightNumberMap(existing.timingSums, incoming.timingSums, 0, 100000),
		timingSuccesses = mergeLightweightNumberMap(existing.timingSuccesses, incoming.timingSuccesses, 0, 100000),
		updatedAt = os.time(),
		saves = math.clamp((math.floor(tonumber(existing.saves) or 0) + 1), 0, 1000000),
	}
end

local function ensureRoleData(sharedData: { [string]: any }, role: RoleName): { [string]: any }
	if typeof(sharedData[role]) ~= "table" then
		sharedData[role] = {
			versions = {},
			activeVersionId = nil,
		}
	end

	local roleData = sharedData[role]
	if typeof(roleData.versions) ~= "table" then roleData.versions = {} end
	if typeof(roleData.activeVersionId) ~= "string" then roleData.activeVersionId = nil end

	return roleData
end

local function cloneVectorInfo(info: any): { [string]: number }?
	if typeof(info) ~= "table" then return nil end

	local x = tonumber(info.x)
	local y = tonumber(info.y)
	local z = tonumber(info.z)
	if not x or not y or not z then return nil end

	return {
		x = math.floor(x * 100 + 0.5) / 100,
		y = math.floor(y * 100 + 0.5) / 100,
		z = math.floor(z * 100 + 0.5) / 100,
	}
end

local function sanitizeLearning(learning: any): { [string]: any }
	local result: { [string]: any } = {
		graph = {},
		directionScores = {},
		slideBoostScores = {},
		techScores = {},
		routeTechNotes = {},
		geometryScores = {},
		cutoffScores = {},
		learnParams = {},
		routes = {},
		stats = {},
	}

	if typeof(learning) ~= "table" then return result end

	if typeof(learning.graph) == "table" then
		for index, node in learning.graph do
			if index > MAX_GRAPH_NODES then break end
			if typeof(node) ~= "table" then continue end

			local position = cloneVectorInfo(node.position)
			if not position then continue end

			table.insert(result.graph, {
				id = math.floor(tonumber(node.id) or index),
				position = position,
				score = math.clamp(tonumber(node.score) or 0, -100, 100),
				visits = math.clamp(math.floor(tonumber(node.visits) or 0), 0, 100000),
				wallPenalty = math.clamp(tonumber(node.wallPenalty) or 0, 0, 1),
				openDirections = math.clamp(math.floor(tonumber(node.openDirections) or 8), 0, 8),
			})
		end
	end

	if typeof(learning.directionScores) == "table" then
		for bucket, scoreInfo in learning.directionScores do
			if #result.directionScores >= MAX_DIRECTION_SCORES then break end
			if typeof(scoreInfo) ~= "table" then continue end

			table.insert(result.directionScores, {
				bucket = math.clamp(math.floor(tonumber(bucket) or tonumber(scoreInfo.bucket) or 0), 1, 16),
				score = math.clamp(tonumber(scoreInfo.score) or 0, -100, 100),
				visits = math.clamp(math.floor(tonumber(scoreInfo.visits) or 0), 0, 100000),
			})
		end
	end

	if typeof(learning.slideBoostScores) == "table" then
		for key, scoreInfo in learning.slideBoostScores do
			if #result.slideBoostScores >= MAX_SLIDE_SCORES then break end
			if typeof(scoreInfo) ~= "table" then continue end

			local scoreKey = if typeof(key) == "string" then key else scoreInfo.key
			if typeof(scoreKey) ~= "string" then continue end

			table.insert(result.slideBoostScores, {
				key = string.sub(scoreKey, 1, 24),
				score = math.clamp(tonumber(scoreInfo.score) or 0, -100, 100),
				visits = math.clamp(math.floor(tonumber(scoreInfo.visits) or 0), 0, 100000),
			})
		end
	end

	for sourceKey, targetKey in {
		techScores = "techScores",
		routeTechNotes = "routeTechNotes",
		geometryScores = "geometryScores",
		cutoffScores = "cutoffScores",
	} do
		if typeof(learning[sourceKey]) ~= "table" then continue end

		for key, scoreInfo in learning[sourceKey] do
			if #result[targetKey] >= MAX_TECH_SCORES then break end
			if typeof(scoreInfo) ~= "table" then continue end

			local scoreKey = if typeof(key) == "string" then key else scoreInfo.key
			if typeof(scoreKey) ~= "string" then continue end

			table.insert(result[targetKey], {
				key = string.sub(scoreKey, 1, 80),
				score = math.clamp(tonumber(scoreInfo.score) or 0, -100, 100),
				visits = math.clamp(math.floor(tonumber(scoreInfo.visits) or 0), 0, 100000),
			})
		end
	end

	if typeof(learning.learnParams) == "table" then
		for key, value in learning.learnParams do
			if typeof(key) ~= "string" then continue end
			result.learnParams[string.sub(key, 1, 40)] = math.clamp(tonumber(value) or 1, 0, 4)
		end
	end

	if typeof(learning.routes) == "table" then
		for _, route in learning.routes do
			if #result.routes >= MAX_ROUTES then break end
			if typeof(route) ~= "table" then continue end

			local points = {}
			if typeof(route.points) == "table" then
				for index, point in route.points do
					if index > MAX_ROUTE_POINTS then break end
					if typeof(point) ~= "table" then continue end

					local position = cloneVectorInfo(point.position)
					if not position then continue end

					table.insert(points, {
						position = position,
						action = if typeof(point.action) == "string" then string.sub(point.action, 1, 20) else "Move",
						partName = if typeof(point.partName) == "string" then string.sub(point.partName, 1, 160) else nil,
						studs = tonumber(point.studs),
					})
				end
			end

			table.insert(result.routes, {
				id = if typeof(route.id) == "string" then string.sub(route.id, 1, 64) else tostring(os.time()),
				name = if typeof(route.name) == "string" then string.sub(route.name, 1, 40) else "Route",
				maxTime = math.clamp(tonumber(route.maxTime) or 20, 1, 180),
				maxVaults = math.clamp(math.floor(tonumber(route.maxVaults) or 99), 0, 99),
				maxSwings = math.clamp(math.floor(tonumber(route.maxSwings) or 99), 0, 99),
				maxRolls = math.clamp(math.floor(tonumber(route.maxRolls) or 99), 0, 99),
				points = points,
				bestTime = tonumber(route.bestTime),
				successes = math.clamp(math.floor(tonumber(route.successes) or 0), 0, 100000),
				failures = math.clamp(math.floor(tonumber(route.failures) or 0), 0, 100000),
			})
		end
	end

	if typeof(learning.stats) == "table" then
		result.stats = {
			successes = math.clamp(math.floor(tonumber(learning.stats.successes) or 0), 0, 1000000),
			attempts = math.clamp(math.floor(tonumber(learning.stats.attempts) or 0), 0, 1000000),
			lastDistance = tonumber(learning.stats.lastDistance),
			bestDistance = tonumber(learning.stats.bestDistance),
		}
	end

	return result
end

local function sanitizeSummary(summary: any): { [string]: any }
	if typeof(summary) ~= "table" then return {} end

	return {
		graphNodes = math.clamp(math.floor(tonumber(summary.graphNodes) or 0), 0, MAX_GRAPH_NODES),
		directionScores = math.clamp(math.floor(tonumber(summary.directionScores) or 0), 0, MAX_DIRECTION_SCORES),
		slideTimings = math.clamp(math.floor(tonumber(summary.slideTimings) or 0), 0, MAX_SLIDE_SCORES),
		techNotes = math.clamp(math.floor(tonumber(summary.techNotes) or 0), 0, MAX_TECH_SCORES),
		cutoffs = math.clamp(math.floor(tonumber(summary.cutoffs) or 0), 0, MAX_TECH_SCORES),
		selfTaughtCandidates = math.clamp(math.floor(tonumber(summary.selfTaughtCandidates) or 0), 0, MAX_TECH_SCORES),
		routes = math.clamp(math.floor(tonumber(summary.routes) or 0), 0, MAX_ROUTES),
		successes = math.clamp(math.floor(tonumber(summary.successes) or 0), 0, 1000000),
		attempts = math.clamp(math.floor(tonumber(summary.attempts) or 0), 0, 1000000),
		note = if typeof(summary.note) == "string" then string.sub(summary.note, 1, 80) else "",
	}
end

local function mergeScoredList(existingList: any, incomingList: any, keyName: string, maxCount: number): { any }
	local byKey: { [string]: any } = {}
	local order = {}

	for _, list in { existingList, incomingList } do
		if typeof(list) ~= "table" then continue end

		for _, entry in list do
			if typeof(entry) ~= "table" then continue end

			local rawKey = entry[keyName]
			local key = if keyName == "bucket" then tostring(math.clamp(math.floor(tonumber(rawKey) or 0), 1, 16)) else tostring(rawKey or "")
			if key == "" then continue end

			local score = math.clamp(tonumber(entry.score) or 0, -100, 100)
			local visits = math.clamp(math.floor(tonumber(entry.visits) or 0), 0, 100000)
			local oldEntry = byKey[key]

			if not oldEntry then
				local copy = {
					score = score,
					visits = visits,
				}
				copy[keyName] = if keyName == "bucket" then tonumber(key) else key
				byKey[key] = copy
				table.insert(order, key)
			elseif visits >= (tonumber(oldEntry.visits) or 0) then
				oldEntry.score = score
				oldEntry.visits = visits
			end
		end
	end

	table.sort(order, function(left, right)
		return (tonumber(byKey[left].visits) or 0) > (tonumber(byKey[right].visits) or 0)
	end)

	local result = {}
	for index, key in order do
		if index > maxCount then break end
		table.insert(result, byKey[key])
	end

	return result
end

local function mergeGraph(existingGraph: any, incomingGraph: any): { any }
	local byId: { [number]: any } = {}
	local ids = {}

	for _, list in { existingGraph, incomingGraph } do
		if typeof(list) ~= "table" then continue end

		for _, node in list do
			if typeof(node) ~= "table" then continue end

			local id = math.floor(tonumber(node.id) or 0)
			local position = cloneVectorInfo(node.position)
			if id <= 0 or not position then continue end

			local score = math.clamp(tonumber(node.score) or 0, -100, 100)
			local visits = math.clamp(math.floor(tonumber(node.visits) or 0), 0, 100000)
			local oldNode = byId[id]

			if not oldNode then
				byId[id] = {
					id = id,
					position = position,
					score = score,
					visits = visits,
					wallPenalty = math.clamp(tonumber(node.wallPenalty) or 0, 0, 1),
					openDirections = math.clamp(math.floor(tonumber(node.openDirections) or 8), 0, 8),
				}
				table.insert(ids, id)
			elseif visits >= (tonumber(oldNode.visits) or 0) then
				oldNode.position = position
				oldNode.score = score
				oldNode.visits = visits
				oldNode.wallPenalty = math.clamp(tonumber(node.wallPenalty) or oldNode.wallPenalty or 0, 0, 1)
				oldNode.openDirections = math.clamp(math.floor(tonumber(node.openDirections) or oldNode.openDirections or 8), 0, 8)
			end
		end
	end

	table.sort(ids, function(left, right)
		return (tonumber(byId[left].visits) or 0) > (tonumber(byId[right].visits) or 0)
	end)

	local result = {}
	for index, id in ids do
		if index > MAX_GRAPH_NODES then break end
		table.insert(result, byId[id])
	end

	return result
end

local function mergeRoutes(existingRoutes: any, incomingRoutes: any): { any }
	local byId: { [string]: any } = {}
	local ids = {}

	for _, list in { existingRoutes, incomingRoutes } do
		if typeof(list) ~= "table" then continue end

		for _, route in list do
			if typeof(route) ~= "table" or typeof(route.id) ~= "string" then continue end

			local oldRoute = byId[route.id]
			if not oldRoute then
				byId[route.id] = route
				table.insert(ids, route.id)
				continue
			end

			oldRoute.name = if typeof(route.name) == "string" then route.name else oldRoute.name
			oldRoute.maxTime = tonumber(route.maxTime) or oldRoute.maxTime
			oldRoute.maxVaults = math.max(math.floor(tonumber(route.maxVaults) or 0), math.floor(tonumber(oldRoute.maxVaults) or 0))
			oldRoute.maxSwings = math.max(math.floor(tonumber(route.maxSwings) or 0), math.floor(tonumber(oldRoute.maxSwings) or 0))
			oldRoute.maxRolls = math.max(math.floor(tonumber(route.maxRolls) or 0), math.floor(tonumber(oldRoute.maxRolls) or 0))
			oldRoute.points = if typeof(route.points) == "table" and #route.points > 0 then route.points else oldRoute.points
			local incomingBestTime = tonumber(route.bestTime)
			local existingBestTime = tonumber(oldRoute.bestTime)
			oldRoute.bestTime = if incomingBestTime and existingBestTime then math.min(incomingBestTime, existingBestTime) else incomingBestTime or existingBestTime
			oldRoute.successes = math.max(math.floor(tonumber(route.successes) or 0), math.floor(tonumber(oldRoute.successes) or 0))
			oldRoute.failures = math.max(math.floor(tonumber(route.failures) or 0), math.floor(tonumber(oldRoute.failures) or 0))
		end
	end

	table.sort(ids, function(left, right)
		local leftRoute = byId[left]
		local rightRoute = byId[right]
		return (tonumber(leftRoute.successes) or 0) > (tonumber(rightRoute.successes) or 0)
	end)

	local result = {}
	for index, id in ids do
		if index > MAX_ROUTES then break end
		table.insert(result, byId[id])
	end

	return result
end

local function mergeLearning(existingLearning: any, incomingLearning: any): { [string]: any }
	local existing = sanitizeLearning(existingLearning)
	local incoming = sanitizeLearning(incomingLearning)
	local merged = sanitizeLearning({})

	merged.graph = mergeGraph(existing.graph, incoming.graph)
	merged.directionScores = mergeScoredList(existing.directionScores, incoming.directionScores, "bucket", MAX_DIRECTION_SCORES)
	merged.slideBoostScores = mergeScoredList(existing.slideBoostScores, incoming.slideBoostScores, "key", MAX_SLIDE_SCORES)
	merged.techScores = mergeScoredList(existing.techScores, incoming.techScores, "key", MAX_TECH_SCORES)
	merged.routeTechNotes = mergeScoredList(existing.routeTechNotes, incoming.routeTechNotes, "key", MAX_TECH_SCORES)
	merged.geometryScores = mergeScoredList(existing.geometryScores, incoming.geometryScores, "key", MAX_TECH_SCORES)
	merged.cutoffScores = mergeScoredList(existing.cutoffScores, incoming.cutoffScores, "key", MAX_TECH_SCORES)
	merged.learnParams = incoming.learnParams
	merged.routes = mergeRoutes(existing.routes, incoming.routes)
	merged.stats = {
		successes = math.max(math.floor(tonumber(existing.stats.successes) or 0), math.floor(tonumber(incoming.stats.successes) or 0)),
		attempts = math.max(math.floor(tonumber(existing.stats.attempts) or 0), math.floor(tonumber(incoming.stats.attempts) or 0)),
		lastDistance = incoming.stats.lastDistance or existing.stats.lastDistance,
		bestDistance = nil,
	}

	local existingBestDistance = tonumber(existing.stats.bestDistance)
	local incomingBestDistance = tonumber(incoming.stats.bestDistance)
	merged.stats.bestDistance = if existingBestDistance and incomingBestDistance then math.min(existingBestDistance, incomingBestDistance) else incomingBestDistance or existingBestDistance

	return merged
end

local function sanitizeVersion(role: RoleName, version: any): VersionInfo?
	if typeof(version) ~= "table" or typeof(version.id) ~= "string" then return nil end

	return {
		id = string.sub(version.id, 1, 64),
		role = role,
		name = if typeof(version.name) == "string" then string.sub(version.name, 1, 40) else `{role} session`,
		favorite = version.favorite == true,
		createdAt = math.floor(tonumber(version.createdAt) or os.time()),
		updatedAt = math.floor(tonumber(version.updatedAt) or os.time()),
		saves = math.clamp(math.floor(tonumber(version.saves) or 0), 0, 1000000),
		summary = sanitizeSummary(version.summary),
		learning = sanitizeLearning(version.learning),
	}
end

local function normalizeSharedData(rawData: any): { [string]: any }
	local sharedData = newSharedData()

	if typeof(rawData) ~= "table" then return sharedData end

	for _, role in { "tagger" :: RoleName, "runner" :: RoleName } do
		local sourceRoleData = rawData[role]
		local roleData = ensureRoleData(sharedData, role)
		if typeof(sourceRoleData) ~= "table" then continue end

		roleData.activeVersionId = if typeof(sourceRoleData.activeVersionId) == "string" then string.sub(sourceRoleData.activeVersionId, 1, 64) else nil

		if typeof(sourceRoleData.versions) == "table" then
			for _, rawVersion in sourceRoleData.versions do
				local version = sanitizeVersion(role, rawVersion)
				if version then table.insert(roleData.versions, version) end
			end
		end
	end

	sharedData.LightweightMemory = sanitizeLightweightMemory(rawData.LightweightMemory)

	return sharedData
end

local function pruneVersions(roleData: { [string]: any })
	local versions = roleData.versions
	local nonFavoriteCount = 0

	for _, version in versions do
		if typeof(version) == "table" and not version.favorite then
			nonFavoriteCount += 1
		end
	end

	while nonFavoriteCount > MAX_NON_FAVORITE_VERSIONS do
		local oldestIndex = nil
		local oldestTime = math.huge

		for index, version in versions do
			if typeof(version) ~= "table" or version.favorite then continue end

			local updatedAt = tonumber(version.updatedAt) or 0
			if updatedAt < oldestTime then
				oldestTime = updatedAt
				oldestIndex = index
			end
		end

		if not oldestIndex then return end

		local removedVersion = table.remove(versions, oldestIndex)
		if removedVersion and roleData.activeVersionId == removedVersion.id then
			roleData.activeVersionId = if versions[1] then versions[1].id else nil
		end
		nonFavoriteCount -= 1
	end
end

local function getVersion(roleData: { [string]: any }, versionId: string): (VersionInfo?, number?)
	for index, version in roleData.versions do
		if typeof(version) == "table" and version.id == versionId then return version :: VersionInfo, index end
	end

	return nil, nil
end

local function loadGlobalData(): { [string]: any }
	if globalDataLoaded and globalTrainingData then return globalTrainingData end

	local success, result = pcall(function()
		return GlobalBotTrainingStore:GetAsync(GLOBAL_DATA_KEY)
	end)

	if not success then
		warn(`[BotTrainingData] Failed to load global bot training data: {tostring(result)}`)
		globalTrainingData = newSharedData()
		globalDataLoaded = true
		return globalTrainingData
	end

	globalTrainingData = normalizeSharedData(result)
	globalDataLoaded = true
	return globalTrainingData
end

local function updateGlobalData(mutator: ({ [string]: any }) -> ()): { [string]: any }?
	local success, result = pcall(function()
		return GlobalBotTrainingStore:UpdateAsync(GLOBAL_DATA_KEY, function(oldData)
			local sharedData = normalizeSharedData(oldData)
			mutator(sharedData)
			return sharedData
		end)
	end)

	if not success then
		warn(`[BotTrainingData] Failed to save global bot training data: {tostring(result)}`)
		return nil
	end

	globalTrainingData = normalizeSharedData(result)
	globalDataLoaded = true
	return globalTrainingData
end

local function init()
	RetrieveBotTrainingDataRF.OnServerInvoke = function(player)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		return loadGlobalData()
	end

	RetrieveBotLightweightMemoryRF.OnServerInvoke = function(player)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		local sharedData = loadGlobalData()
		return sanitizeLightweightMemory(sharedData.LightweightMemory)
	end

	SaveBotLightweightMemoryRF.OnServerInvoke = function(player, memory)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		if typeof(memory) ~= "table" then return nil end

		local updatedData = updateGlobalData(function(sharedData)
			sharedData.LightweightMemory = mergeLightweightMemory(sharedData.LightweightMemory, memory)
		end)

		if not updatedData then return nil end
		return sanitizeLightweightMemory(updatedData.LightweightMemory)
	end

	SaveBotLearningVersionRF.OnServerInvoke = function(player, role, versionInfo)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		if not isRoleName(role) then return nil end
		if typeof(versionInfo) ~= "table" then return nil end

		local now = os.time()
		local roleName = role :: RoleName
		local versionId = if typeof(versionInfo.id) == "string" and versionInfo.id ~= "" then string.sub(versionInfo.id, 1, 64) else `{roleName}-{now}`

		return updateGlobalData(function(sharedData)
			local roleData = ensureRoleData(sharedData, roleName)
			local version = getVersion(roleData, versionId)

			if not version then
				version = {
					id = versionId,
					role = roleName,
					name = if typeof(versionInfo.name) == "string" then string.sub(versionInfo.name, 1, 40) else `{roleName} session`,
					favorite = false,
					createdAt = now,
					updatedAt = now,
					saves = 0,
					summary = {},
					learning = {},
				}
				table.insert(roleData.versions, 1, version)
			end

			version.name = if typeof(versionInfo.name) == "string" then string.sub(versionInfo.name, 1, 40) else version.name
			version.favorite = version.favorite == true or versionInfo.favorite == true
			version.updatedAt = now
			version.saves = math.clamp(math.floor(tonumber(version.saves) or 0) + 1, 0, 1000000)
			version.summary = sanitizeSummary(versionInfo.summary)
			version.learning = mergeLearning(version.learning, versionInfo.learning)
			roleData.activeVersionId = versionId

			pruneVersions(roleData)
		end)
	end

	FavoriteBotLearningVersionRF.OnServerInvoke = function(player, role, versionId, favorite)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		if not isRoleName(role) or typeof(versionId) ~= "string" then return nil end

		return updateGlobalData(function(sharedData)
			local roleData = ensureRoleData(sharedData, role :: RoleName)
			local version = getVersion(roleData, versionId)
			if not version then return end

			version.favorite = favorite == true
			version.updatedAt = os.time()
			pruneVersions(roleData)
		end)
	end

	DeleteBotLearningVersionRF.OnServerInvoke = function(player, role, versionId)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		if not isRoleName(role) or typeof(versionId) ~= "string" then return nil end

		return updateGlobalData(function(sharedData)
			local roleData = ensureRoleData(sharedData, role :: RoleName)
			local _, index = getVersion(roleData, versionId)
			if index then table.remove(roleData.versions, index) end
			if roleData.activeVersionId == versionId then
				roleData.activeVersionId = if roleData.versions[1] then roleData.versions[1].id else nil
			end
		end)
	end

	SelectBotLearningVersionRF.OnServerInvoke = function(player, role, versionId)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		if not isRoleName(role) or typeof(versionId) ~= "string" then return nil end

		return updateGlobalData(function(sharedData)
			local roleData = ensureRoleData(sharedData, role :: RoleName)
			local version = getVersion(roleData, versionId)
			if version then roleData.activeVersionId = versionId end
		end)
	end
end

return Schedules.Boot.job(init)
