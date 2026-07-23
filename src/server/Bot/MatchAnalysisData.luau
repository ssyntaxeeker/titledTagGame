--!strict
--[[
    MatchAnalysisData (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/21

    Authoritative whitelisted persistence for global per-map match analysis.
    Incoming batches are archived permanently, then sanitized and merged into
    a bounded hot aggregate suitable for live recommendations.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local MatchAnalysisArchive = require(script.Parent.MatchAnalysisArchive)
local MatchAnalysisRouteCatalog = require(script.Parent.MatchAnalysisRouteCatalog)

local LoadAnalysis = Net:RemoteFunction("LoadMatchAnalysis")
local LoadAnalysisRoutes = Net:RemoteFunction("LoadMatchAnalysisRoutes")
local SaveAnalysis = Net:RemoteFunction("SaveMatchAnalysisBatch")
local Store = DataStoreService:GetDataStore("TitledTagGameMatchAnalysisV1")

local VALID_ACTIONS = table.freeze({
	Run = true,
	Jump = true,
	Vault = true,
	Swing = true,
	Walljump = true,
	Wallrun = true,
	Zipline = true,
	Rail = true,
	Rope = true,
	Windforce = true,
	Crouch = true,
	Slide = true,
	Roll = true,
	SlideBoost = true,
	RollBoost = true,
	Tramp = true,
	Trampoline = true,
	Drop = true,
	UnknownTech = true,
})
local MAXIMUM_ZONES = 5000
local MAXIMUM_TRANSITIONS = 50000
local MAXIMUM_TECHNIQUES = 5000
local MAXIMUM_HOT_LINES = 128
local MAXIMUM_TECH_OBSERVATIONS = 5000
local MAXIMUM_ROUTE_REVIEWS = 5000
local MAXIMUM_BATCH_ZONES = 900
local MAXIMUM_BATCH_TRANSITIONS = 1800
local MAXIMUM_BATCH_TECHNIQUES = 120
local MAXIMUM_BATCH_LINES = 24
local MAXIMUM_BATCH_ROUTE_REVIEWS = 48
local ROUTE_ENDPOINT_RADIUS = 14
local ROUTE_CORRIDOR_RADIUS = 10
local lastSaveAt: { [Player]: number } = {}
local cache: { [string]: { [string]: any } } = {}
local cacheLoadedAt: { [string]: number } = {}

local function number(value: any, maximumMagnitude: number): number?
	local converted = tonumber(value)
	if not converted or converted ~= converted or math.abs(converted) > maximumMagnitude then return nil end
	return converted
end

local function mapKey(raw: any): string?
	if typeof(raw) ~= "string" or #raw < 1 or #raw > 80 then return nil end
	local cleaned = string.gsub(raw, "[^%w_%-:]", "_")
	return string.sub(cleaned, 1, 80)
end

local function empty(key: string): { [string]: any }
	return {
		version = 3,
		mapKey = key,
		zones = {},
		transitions = {},
		techniques = {},
		techObservations = {},
		lines = {},
		routeReviews = {},
		updatedAt = os.time(),
	}
end

local function numericTuple(raw: any, count: number, maximumMagnitude: number): { number }?
	if typeof(raw) ~= "table" or #raw ~= count then return nil end
	local result = {}
	for index = 1, count do
		local value = number(raw[index], maximumMagnitude)
		if not value then return nil end
		result[index] = value
	end
	return result
end

local function sanitizeActions(raw: any, maximum: number): { string }?
	if typeof(raw) ~= "table" or #raw > maximum then return nil end
	local actions = {}
	for _, action in raw do
		if typeof(action) ~= "string" or not VALID_ACTIONS[action] then return nil end
		actions[#actions + 1] = action
	end
	return actions
end

local function techniqueSignature(info: { [string]: any }): string
	local function band(value: number, size: number): number
		return math.floor(value / size + 0.5) * size
	end
	return `{info.action}:H{band(info.wallHeight, 1)}:W{band(info.wallDistance, 1)}:Y{band(info.preY, 5)}:S{band(info.preSpeed, 4)}:R{info.role}`
end

local function sanitizeTechnique(raw: any): { [string]: any }?
	if typeof(raw) ~= "table" or not VALID_ACTIONS[raw.action] then return nil end
	if raw.role ~= "Chaser" and raw.role ~= "Runner" then return nil end
	local position = numericTuple(raw.position, 3, 100000)
	local weight = number(raw.weight, 5)
	local preSpeed = number(raw.preSpeed, 500)
	local postSpeed = number(raw.postSpeed, 500)
	local preY = number(raw.preY, 500)
	local postY = number(raw.postY, 500)
	local floorY = number(raw.floorY, 100000)
	local wallDistance = number(raw.wallDistance, 100)
	local wallHeight = number(raw.wallHeight, 100)
	local headroom = number(raw.headroom, 100)
	local advantage = number(raw.advantage, 100)
	local techValue = if raw.techValue == nil then nil else number(raw.techValue, 10000)
	if not position or not weight or not preSpeed or not postSpeed or not preY or not postY
		or not floorY or not wallDistance or not wallHeight or not headroom or not advantage
	then
		return nil
	end
	return {
		action = raw.action,
		role = raw.role,
		position = position,
		weight = weight,
		preSpeed = preSpeed,
		postSpeed = postSpeed,
		preY = preY,
		postY = postY,
		floorY = floorY,
		wallDistance = wallDistance,
		wallHeight = wallHeight,
		headroom = headroom,
		nearSwingBar = raw.nearSwingBar == true,
		nearTrampoline = raw.nearTrampoline == true,
		techValue = techValue,
		advantage = advantage,
	}
end

local function sanitizeLine(raw: any): { [string]: any }?
	if typeof(raw) ~= "table" or (raw.role ~= "Chaser" and raw.role ~= "Runner") then return nil end
	if typeof(raw.points) ~= "table" or #raw.points < 3 or #raw.points > 168 then return nil end
	local points = {}
	for _, rawPoint in raw.points do
		local point: { number }?
		if typeof(rawPoint) == "table" and #rawPoint == 4 then
			point = numericTuple(rawPoint, 4, 100000)
		elseif typeof(rawPoint) == "table" and #rawPoint == 15 then
			point = numericTuple(rawPoint, 15, 100000)
		elseif typeof(rawPoint) == "table" and #rawPoint == 24 then
			point = numericTuple(rawPoint, 24, 100000)
		else
			point = numericTuple(rawPoint, 29, 100000)
		end
		if not point then return nil end
		-- Full kinematic samples remain in the append-only archive. The live
		-- route catalog needs only position and relative route time.
		points[#points + 1] = { point[1], point[2], point[3], point[4] }
	end
	local actions = sanitizeActions(raw.actions, 168)
	local weight = number(raw.weight, 5)
	local duration = number(raw.duration, 60)
	local distance = number(raw.distance, 2000)
	local displacement = number(raw.displacement, 2000)
	local advantage = number(raw.advantage, 500)
	local outcome = number(raw.outcome, 1)
	local techCount = number(raw.techCount, 100)
	local quality = number(raw.quality or 0, 1000)
	if not actions or #actions ~= #points or not weight or not duration or duration <= 0
		or not distance or not displacement or not advantage or not outcome or not techCount or not quality
	then
		return nil
	end
	if displacement < 18 or distance / duration < 8 or advantage < -3 or quality < 5 then return nil end
	local first = points[1]
	local last = points[#points]
	local middle = points[math.ceil(#points / 2)]
	local techniquePattern = {}
	local previousAction = "Run"
	for _, action in actions do
		if action ~= "Run" and action ~= previousAction and #techniquePattern < 8 then
			techniquePattern[#techniquePattern + 1] = action
		end
		previousAction = action
	end
	local signature = `{raw.role}:{math.floor(first[1] / 4)}:{math.floor(first[2] / 4)}:{math.floor(first[3] / 4)}>{math.floor(middle[1] / 4)}:{math.floor(middle[2] / 4)}:{math.floor(middle[3] / 4)}>{math.floor(last[1] / 4)}:{math.floor(last[2] / 4)}:{math.floor(last[3] / 4)}:{table.concat(techniquePattern, "+")}`
	return {
		signature = string.sub(signature, 1, 180),
		role = raw.role,
		points = points,
		actions = actions,
		weight = weight,
		duration = duration,
		distance = distance,
		displacement = displacement,
		advantage = advantage,
		outcome = outcome,
		techCount = math.floor(techCount),
		quality = quality,
	}
end

local function sanitizeRouteReview(raw: any): { [string]: any }?
	if typeof(raw) ~= "table" or typeof(raw.points) ~= "table" or #raw.points ~= 5 then return nil end
	local points = {}
	for _, rawPoint in raw.points do
		local point = numericTuple(rawPoint, 3, 100000)
		if not point then return nil end
		points[#points + 1] = point
	end
	local uses = number(raw.uses, 100)
	local catches = number(raw.catches, 100)
	local advantage = number(raw.advantage, 1000)
	if not uses or not catches or not advantage or uses < 1 or catches < 0 or catches > uses then return nil end
	return {
		points = points,
		uses = math.floor(uses),
		catches = math.floor(catches),
		totalAdvantage = advantage,
	}
end

local function reviewsMatch(first: { [string]: any }, second: { [string]: any }): boolean
	local total = 0
	for index = 1, 5 do
		local firstPoint = first.points[index]
		local secondPoint = second.points[index]
		total += (Vector3.new(firstPoint[1], firstPoint[2], firstPoint[3])
			- Vector3.new(secondPoint[1], secondPoint[2], secondPoint[3])).Magnitude
	end
	return total / 5 <= 12
end

-- Routes are sampled at different rates and timings. Comparing normalized
-- anchors lets repeated runs refine one family without merging distinct lines
-- that merely share endpoints.
local function routesMatch(first: { [string]: any }, second: { [string]: any }): boolean
	if first.role ~= second.role then return false end
	local firstPoints = first.points
	local secondPoints = second.points
	if typeof(firstPoints) ~= "table" or typeof(secondPoints) ~= "table" or #firstPoints < 2 or #secondPoints < 2 then
		return false
	end
	local function distance(a: { number }, b: { number }): number
		return (Vector3.new(a[1], a[2], a[3]) - Vector3.new(b[1], b[2], b[3])).Magnitude
	end
	if distance(firstPoints[1], secondPoints[1]) > ROUTE_ENDPOINT_RADIUS
		or distance(firstPoints[#firstPoints], secondPoints[#secondPoints]) > ROUTE_ENDPOINT_RADIUS
	then
		return false
	end
	local total = 0
	for anchor = 0, 4 do
		local firstIndex = math.clamp(math.round(1 + (#firstPoints - 1) * anchor / 4), 1, #firstPoints)
		local secondIndex = math.clamp(math.round(1 + (#secondPoints - 1) * anchor / 4), 1, #secondPoints)
		total += distance(firstPoints[firstIndex], secondPoints[secondIndex])
	end
	return total / 5 <= ROUTE_CORRIDOR_RADIUS
end

local function executionScore(info: { [string]: any }): number
	return (tonumber(info.advantage) or 0) * 1.8
		+ (tonumber(info.outcome) or 0) * 8
		+ (tonumber(info.displacement) or 0) / math.max(tonumber(info.duration) or 1, 0.1)
		+ (tonumber(info.quality) or 0) * 0.5
end

local function trimDictionary(dictionary: { [string]: any }, maximum: number, scoreField: string)
	local count = 0
	for _ in dictionary do count += 1 end
	if count <= maximum then return end
	local entries = {}
	for key, value in dictionary do
		entries[#entries + 1] = { key = key, score = tonumber(value[scoreField]) or 0 }
	end
	table.sort(entries, function(a, b) return a.score > b.score end)
	for index = maximum + 1, #entries do dictionary[entries[index].key] = nil end
end

local function dictionaryCount(dictionary: { [string]: any }): number
	local result = 0
	for _ in dictionary do result += 1 end
	return result
end

local function merge(memory: { [string]: any }, raw: any)
	if typeof(raw) ~= "table" then return end
	memory.version = 3
	memory.zones = if typeof(memory.zones) == "table" then memory.zones else {}
	memory.transitions = if typeof(memory.transitions) == "table" then memory.transitions else {}
	memory.techniques = if typeof(memory.techniques) == "table" then memory.techniques else {}
	memory.techObservations = if typeof(memory.techObservations) == "table" then memory.techObservations else {}
	memory.lines = if typeof(memory.lines) == "table" then memory.lines else {}
	memory.routeReviews = if typeof(memory.routeReviews) == "table" then memory.routeReviews else {}
	if typeof(raw.zones) == "table" then
		local accepted = 0
		for key, tuple in raw.zones do
			if accepted >= 900 or typeof(key) ~= "string" or #key > 60 then break end
			local values = numericTuple(tuple, 6, 100000)
			if not values then continue end
			local zone = memory.zones[key] or { samples = 0, dwell = 0, speed = 0, chaser = 0, runner = 0, techs = 0 }
			zone.samples += values[1]
			zone.dwell += values[2]
			zone.speed += values[3]
			zone.chaser += values[4]
			zone.runner += values[5]
			zone.techs += values[6]
			memory.zones[key] = zone
			accepted += 1
		end
	end
	if typeof(raw.transitions) == "table" then
		local accepted = 0
		for key, tuple in raw.transitions do
			if accepted >= 1800 or typeof(key) ~= "string" or #key > 150 then break end
			local values = numericTuple(tuple, 4, 100000)
			if not values then continue end
			local transition = memory.transitions[key] or { count = 0, time = 0, advantage = 0, techs = 0 }
			transition.count += values[1]
			transition.time += values[2]
			transition.advantage += values[3]
			transition.techs += values[4]
			memory.transitions[key] = transition
			accepted += 1
		end
	end
	if typeof(raw.techniques) == "table" then
		for index = 1, math.min(#raw.techniques, 120) do
			local info = sanitizeTechnique(raw.techniques[index])
			if not info then continue end
			local signature = techniqueSignature(info)
			local aggregate = memory.techniques[signature] or {
				action = info.action, role = info.role, count = 0, weight = 0, preSpeed = 0,
				postSpeed = 0, preY = 0, postY = 0, wallDistance = 0, wallHeight = 0,
				headroom = 0, advantage = 0, examples = {},
				techValue = 0, techValueWeight = 0,
			}
			aggregate.count += 1
			aggregate.weight += info.weight
			aggregate.preSpeed += info.preSpeed * info.weight
			aggregate.postSpeed += info.postSpeed * info.weight
			aggregate.preY += info.preY * info.weight
			aggregate.postY += info.postY * info.weight
			aggregate.wallDistance += info.wallDistance * info.weight
			aggregate.wallHeight += info.wallHeight * info.weight
			aggregate.headroom += info.headroom * info.weight
			aggregate.advantage += info.advantage * info.weight
			if info.techValue then
				aggregate.techValue += info.techValue * info.weight
				aggregate.techValueWeight += info.weight
			end
			if #aggregate.examples < 6 then aggregate.examples[#aggregate.examples + 1] = info.position end
			memory.techniques[signature] = aggregate
			info.recordedAt = os.time()
			memory.techObservations[#memory.techObservations + 1] = info
		end
	end
	if #memory.techObservations > MAXIMUM_TECH_OBSERVATIONS then
		local retained = {}
		local first = #memory.techObservations - MAXIMUM_TECH_OBSERVATIONS + 1
		for index = first, #memory.techObservations do retained[#retained + 1] = memory.techObservations[index] end
		memory.techObservations = retained
	end
	if typeof(raw.lines) == "table" then
		for index = 1, math.min(#raw.lines, 24) do
			local info = sanitizeLine(raw.lines[index])
			if not info then continue end
			local existingIndex: number? = nil
			for lineIndex, line in memory.lines do
				if routesMatch(line, info) then
					existingIndex = lineIndex
					break
				end
			end
			if existingIndex then
				local existing = memory.lines[existingIndex]
				local previousAttempts = math.max(tonumber(existing.attempts) or 1, 1)
				local previousTimeTotal = tonumber(existing.totalTime) or (tonumber(existing.duration) or 0) * previousAttempts
				local previousTimeSquared = tonumber(existing.totalTimeSquared)
					or (tonumber(existing.duration) or 0) ^ 2 * previousAttempts
				existing.attempts = (existing.attempts or 1) + 1
				existing.weight = (existing.weight or 0) + info.weight
				existing.totalTime = previousTimeTotal + info.duration
				existing.totalTimeSquared = previousTimeSquared + info.duration ^ 2
				existing.totalAdvantage = (existing.totalAdvantage or existing.advantage) + info.advantage
				existing.totalOutcome = (existing.totalOutcome or existing.outcome or 0) + info.outcome
				existing.totalQuality = (existing.totalQuality or existing.quality or 0) + info.quality
				existing.firstTime = existing.firstTime or existing.duration
				existing.bestTime = math.min(existing.bestTime or existing.duration, info.duration)
				local existingScore = executionScore(existing)
				local candidateScore = executionScore(info)
				if candidateScore > existingScore then
					existing.points = info.points
					existing.actions = info.actions
					existing.duration = info.duration
					existing.distance = info.distance
					existing.displacement = info.displacement
					existing.advantage = info.advantage
					existing.outcome = info.outcome
					existing.techCount = info.techCount
					existing.quality = info.quality
				end
			else
				info.attempts = 1
				info.totalTime = info.duration
				info.totalTimeSquared = info.duration ^ 2
				info.totalAdvantage = info.advantage
				info.totalOutcome = info.outcome
				info.totalQuality = info.quality
				info.firstTime = info.duration
				info.bestTime = info.duration
				memory.lines[#memory.lines + 1] = info
			end
		end
	end
	if typeof(raw.routeReviews) == "table" then
		for index = 1, math.min(#raw.routeReviews, 48) do
			local info = sanitizeRouteReview(raw.routeReviews[index])
			if not info then continue end
			local existing: { [string]: any }? = nil
			for _, review in memory.routeReviews do
				if reviewsMatch(review, info) then
					existing = review
					break
				end
			end
			if existing then
				existing.uses = (existing.uses or 0) + info.uses
				existing.catches = (existing.catches or 0) + info.catches
				existing.totalAdvantage = (existing.totalAdvantage or 0) + info.totalAdvantage
			else
				memory.routeReviews[#memory.routeReviews + 1] = info
			end
		end
	end
	trimDictionary(memory.zones, MAXIMUM_ZONES, "samples")
	trimDictionary(memory.transitions, MAXIMUM_TRANSITIONS, "count")
	trimDictionary(memory.techniques, MAXIMUM_TECHNIQUES, "weight")
	table.sort(memory.lines, function(a, b)
		local aReliability = math.min(a.attempts or 1, 8)
		local bReliability = math.min(b.attempts or 1, 8)
		local aAttempts = math.max(a.attempts or 1, 1)
		local bAttempts = math.max(b.attempts or 1, 1)
		local aAverageTime = (a.totalTime or a.duration) / aAttempts
		local bAverageTime = (b.totalTime or b.duration) / bAttempts
		local aDeviation = math.sqrt(math.max((a.totalTimeSquared or a.duration ^ 2 * aAttempts) / aAttempts - aAverageTime ^ 2, 0))
		local bDeviation = math.sqrt(math.max((b.totalTimeSquared or b.duration ^ 2 * bAttempts) / bAttempts - bAverageTime ^ 2, 0))
		local aConsistency = math.clamp(1 - aDeviation / math.max(aAverageTime, 0.1), 0, 1)
		local bConsistency = math.clamp(1 - bDeviation / math.max(bAverageTime, 0.1), 0, 1)
		local aScore = (a.totalAdvantage or 0) / aAttempts + (a.totalOutcome or 0) / aAttempts * 8 + aReliability * 0.5 + aConsistency * 3 + (a.totalQuality or a.quality or 0) / aAttempts - aAverageTime * 0.08
		local bScore = (b.totalAdvantage or 0) / bAttempts + (b.totalOutcome or 0) / bAttempts * 8 + bReliability * 0.5 + bConsistency * 3 + (b.totalQuality or b.quality or 0) / bAttempts - bAverageTime * 0.08
		return aScore > bScore
	end)
	-- The unbounded route catalog owns complete retention. This small seed keeps
	-- initial recommendations available while catalog pages stream in.
	while #memory.lines > MAXIMUM_HOT_LINES do table.remove(memory.lines) end
	table.sort(memory.routeReviews, function(a, b) return (a.uses or 0) > (b.uses or 0) end)
	while #memory.routeReviews > MAXIMUM_ROUTE_REVIEWS do table.remove(memory.routeReviews) end
	memory.updatedAt = os.time()
end

local function load(key: string): { [string]: any }
	if cache[key] and os.clock() - (cacheLoadedAt[key] or 0) < 30 then return cache[key] end
	local success, result = pcall(function() return Store:GetAsync(`Map:{key}`) end)
	local memory = if success and typeof(result) == "table" then result else empty(key)
	if not success then warn(`[MatchAnalysisData] load failed for {key}: {tostring(result)}`) end
	memory.version = 3
	memory.techObservations = if typeof(memory.techObservations) == "table" then memory.techObservations else {}
	memory.routeReviews = if typeof(memory.routeReviews) == "table" then memory.routeReviews else {}
	cache[key] = memory
	cacheLoadedAt[key] = os.clock()
	return memory
end

local function init()
	LoadAnalysis.OnServerInvoke = function(player: Player, rawKey: any)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		local key = mapKey(rawKey)
		if not key then return nil end
		return load(key)
	end
	LoadAnalysisRoutes.OnServerInvoke = function(player: Player, raw: any)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		if typeof(raw) ~= "table" then return nil end
		local key = mapKey(raw.mapKey)
		if not key then return nil end
		if raw.bucket == nil then return { buckets = MatchAnalysisRouteCatalog.loadManifest(key) } end
		local bucket = number(raw.bucket, 63)
		local cursor = if raw.cursor == nil then 1 else number(raw.cursor, 1_000_000)
		if not bucket or bucket < 0 or bucket % 1 ~= 0 or not cursor or cursor < 1 then return nil end
		return MatchAnalysisRouteCatalog.loadPage(key, bucket, cursor)
	end
	SaveAnalysis.OnServerInvoke = function(player: Player, raw: any)
		if BotAccess.userIds[player.UserId] ~= true then return { success = false, reason = "not authorized" } end
		if os.clock() - (lastSaveAt[player] or 0) < 6 then return { success = false, reason = "save rate limited" } end
		if typeof(raw) ~= "table" then return { success = false, reason = "invalid batch" } end
		local key = mapKey(raw.mapKey)
		if not key then return { success = false, reason = "invalid map key" } end
		local batchId = raw.batchId
		if typeof(batchId) ~= "string" or #batchId ~= 36 or not string.match(batchId, "^[%x%-]+$") then
			return { success = false, reason = "invalid batch id" }
		end
		if typeof(raw.zones) ~= "table" or dictionaryCount(raw.zones) > MAXIMUM_BATCH_ZONES then
			return { success = false, reason = "invalid zones batch" }
		end
		if typeof(raw.transitions) ~= "table" or dictionaryCount(raw.transitions) > MAXIMUM_BATCH_TRANSITIONS then
			return { success = false, reason = "invalid transitions batch" }
		end
		if typeof(raw.techniques) ~= "table" or #raw.techniques > MAXIMUM_BATCH_TECHNIQUES then
			return { success = false, reason = "invalid techniques batch" }
		end
		if typeof(raw.lines) ~= "table" or #raw.lines > MAXIMUM_BATCH_LINES then
			return { success = false, reason = "invalid lines batch" }
		end
		if typeof(raw.routeReviews) ~= "table" or #raw.routeReviews > MAXIMUM_BATCH_ROUTE_REVIEWS then
			return { success = false, reason = "invalid route reviews batch" }
		end

		lastSaveAt[player] = os.clock()
		local archiveSuccess, archiveResult = MatchAnalysisArchive.append(key, batchId, player, raw)
		if not archiveSuccess then
			warn(`[MatchAnalysisData] archive failed for {key}: {archiveResult}`)
			return { success = false, reason = `archive failed: {archiveResult}` }
		end
		local sanitizedLines = {}
		for _, rawLine in raw.lines do
			local info = sanitizeLine(rawLine)
			if info then sanitizedLines[#sanitizedLines + 1] = info end
		end
		if #sanitizedLines > 0 then
			local routeSuccess, routeResult = MatchAnalysisRouteCatalog.upsert(key, batchId, sanitizedLines)
			if not routeSuccess then
				warn(`[MatchAnalysisData] route catalog failed for {key}: {routeResult}`)
				return { success = false, reason = `route catalog failed: {routeResult}` }
			end
		end

		local success, result = pcall(function()
			return Store:UpdateAsync(`Map:{key}`, function(old)
				local memory = if typeof(old) == "table" then old else empty(key)
				merge(memory, raw)
				return memory
			end)
		end)
		if not success then
			warn(`[MatchAnalysisData] save failed for {key}: {tostring(result)}`)
			return { success = false, reason = tostring(result) }
		end

		cache[key] = result
		cacheLoadedAt[key] = os.clock()
		return {
			success = true,
			archived = true,
			archive = archiveResult,
			zones = if typeof(result.zones) == "table" then dictionaryCount(result.zones) else 0,
			lines = if typeof(result.lines) == "table" then #result.lines else 0,
			updatedAt = result.updatedAt,
		}
	end
	Players.PlayerRemoving:Connect(function(player) lastSaveAt[player] = nil end)
end

return Schedules.Boot.job(init)
