--!strict
--[[
    MatchAnalysisRouteCatalog (Server)
    =========================
    Author: Sol (3693744006)
    Updated: 26/07/21

    Unbounded-by-design route-family catalog. Each demonstrated line owns a
    separate DataStore key, while small bucket directories make the catalog
    incrementally pageable without loading every route into one object.
]]

local DataStoreService = game:GetService("DataStoreService")

local Store = DataStoreService:GetDataStore("TitledTagGameMatchAnalysisRoutesV1")
local DIRECTORY_BUCKETS = 64
local PAGE_SIZE = 20
local DIRECTORY_CACHE_SECONDS = 30

local MatchAnalysisRouteCatalog = {}
local directoryCache: { [string]: { loadedAt: number, ids: { [string]: any } } } = {}
local manifestCache: { [string]: { loadedAt: number, buckets: { [number]: boolean } } } = {}
local routeCache: { [string]: { [string]: any } } = {}

local function hash(value: string, seed: number): number
	local result = seed
	for index = 1, #value do
		result = (result * 33 + string.byte(value, index)) % 4_294_967_296
	end
	return result
end

local function token(value: string): string
	return string.format("%08x%08x", hash(value, 5381), hash(value, 52711))
end

local function routeKey(mapToken: string, routeId: string): string
	return `R:{mapToken}:{routeId}`
end

local function directoryKey(mapToken: string, bucket: number): string
	return `D:{mapToken}:{bucket}`
end

local function manifestKey(mapToken: string): string
	return `M:{mapToken}`
end

local function executionScore(info: { [string]: any }): number
	return (tonumber(info.advantage) or 0) * 1.8
		+ (tonumber(info.outcome) or 0) * 8
		+ (tonumber(info.displacement) or 0) / math.max(tonumber(info.duration) or 1, 0.1)
		+ (tonumber(info.quality) or 0) * 0.5
end

local function compact(info: { [string]: any }): { [string]: any }
	local points = {}
	for _, point in info.points do
		points[#points + 1] = { point[1], point[2], point[3], point[4] }
	end
	return {
		signature = info.signature,
		role = info.role,
		points = points,
		actions = table.clone(info.actions),
		weight = info.weight,
		duration = info.duration,
		distance = info.distance,
		displacement = info.displacement,
		advantage = info.advantage,
		outcome = info.outcome,
		techCount = info.techCount,
		quality = info.quality,
		attempts = 1,
		totalTime = info.duration,
		totalTimeSquared = info.duration ^ 2,
		totalAdvantage = info.advantage,
		totalOutcome = info.outcome,
		totalQuality = info.quality,
		firstTime = info.duration,
		bestTime = info.duration,
		recentBatchIds = {},
	}
end

local function loadDirectory(mapToken: string, bucket: number): { [string]: any }
	local key = directoryKey(mapToken, bucket)
	local cached = directoryCache[key]
	if cached and os.clock() - cached.loadedAt < DIRECTORY_CACHE_SECONDS then return cached.ids end
	local result = Store:GetAsync(key)
	local ids = if typeof(result) == "table" then result else {}
	directoryCache[key] = { loadedAt = os.clock(), ids = ids }
	return ids
end

--[=[
    @server
    @tag Authoritative
    @yields

    upsert
    ======

    Merges sanitized route attempts into individually keyed route families.
    There is no route-count rotation; only Roblox DataStore quotas bound growth.
]=]
function MatchAnalysisRouteCatalog.upsert(mapKey: string, batchId: string, lines: { { [string]: any } }): (boolean, string)
	local mapToken = token(mapKey)
	for _, info in lines do
		local signature = tostring(info.signature)
		local routeId = token(signature)
		local key = routeKey(mapToken, routeId)
		local success, result = pcall(function()
			return Store:UpdateAsync(key, function(old)
				local hasExisting = typeof(old) == "table" and old.mapKey == mapKey and old.signature == signature
				local memory = if hasExisting
					then old
					else compact(info)
				memory.mapKey = mapKey
				memory.routeId = routeId
				memory.recentBatchIds = if typeof(memory.recentBatchIds) == "table" then memory.recentBatchIds else {}
				if table.find(memory.recentBatchIds, batchId) then return memory end
				memory.recentBatchIds[#memory.recentBatchIds + 1] = batchId
				while #memory.recentBatchIds > 16 do table.remove(memory.recentBatchIds, 1) end

				if hasExisting then
					memory.attempts += 1
					memory.weight = (tonumber(memory.weight) or 0) + info.weight
					memory.totalTime = (tonumber(memory.totalTime) or 0) + info.duration
					memory.totalTimeSquared = (tonumber(memory.totalTimeSquared) or 0) + info.duration ^ 2
					memory.totalAdvantage = (tonumber(memory.totalAdvantage) or 0) + info.advantage
					memory.totalOutcome = (tonumber(memory.totalOutcome) or 0) + info.outcome
					memory.totalQuality = (tonumber(memory.totalQuality) or 0) + info.quality
					memory.bestTime = math.min(tonumber(memory.bestTime) or info.duration, info.duration)
					if executionScore(info) > executionScore(memory) then
						local replacement = compact(info)
						memory.points = replacement.points
						memory.actions = replacement.actions
						memory.duration = info.duration
						memory.distance = info.distance
						memory.displacement = info.displacement
						memory.advantage = info.advantage
						memory.outcome = info.outcome
						memory.techCount = info.techCount
						memory.quality = info.quality
					end
				end
				memory.updatedAt = os.time()
				return memory
			end)
		end)
		if not success then return false, tostring(result) end
		routeCache[key] = result

		local bucket = hash(routeId, 7919) % DIRECTORY_BUCKETS
		local ids = loadDirectory(mapToken, bucket)
		local wasIndexed = ids[routeId] ~= nil
		local directorySuccess, directoryResult = pcall(function()
			return Store:UpdateAsync(directoryKey(mapToken, bucket), function(old)
				local directory = if typeof(old) == "table" then old else {}
				-- Compact projections make restoration one read per populated bucket,
				-- while the individual route key remains authoritative.
				directory[routeId] = result
				return directory
			end)
		end)
		if not directorySuccess then return false, tostring(directoryResult) end
		directoryCache[directoryKey(mapToken, bucket)] = {
			loadedAt = os.clock(),
			ids = directoryResult,
		}
		if not wasIndexed then
			local manifestSuccess, manifestResult = pcall(function()
				return Store:UpdateAsync(manifestKey(mapToken), function(old)
					local manifest = if typeof(old) == "table" then old else {}
					manifest[tostring(bucket)] = true
					return manifest
				end)
			end)
			if not manifestSuccess then return false, tostring(manifestResult) end
			local buckets = {}
			for rawBucket in manifestResult do
				local parsed = tonumber(rawBucket)
				if parsed then buckets[parsed] = true end
			end
			manifestCache[mapToken] = { loadedAt = os.clock(), buckets = buckets }
		end
	end
	return true, `{#lines} route attempt(s) indexed`
end

function MatchAnalysisRouteCatalog.loadManifest(mapKey: string): { number }
	local mapToken = token(mapKey)
	local cached = manifestCache[mapToken]
	local buckets = if cached and os.clock() - cached.loadedAt < DIRECTORY_CACHE_SECONDS then cached.buckets else nil
	if not buckets then
		buckets = {}
		local result = Store:GetAsync(manifestKey(mapToken))
		if typeof(result) == "table" then
			for rawBucket in result do
				local parsed = tonumber(rawBucket)
				if parsed and parsed >= 0 and parsed < DIRECTORY_BUCKETS then buckets[parsed] = true end
			end
		end
		manifestCache[mapToken] = { loadedAt = os.clock(), buckets = buckets }
	end
	local result = {}
	for bucket in buckets do result[#result + 1] = bucket end
	table.sort(result)
	return result
end

function MatchAnalysisRouteCatalog.loadPage(mapKey: string, bucket: number, cursor: number?): { [string]: any }
	assert(bucket >= 0 and bucket < DIRECTORY_BUCKETS and bucket % 1 == 0, "[MatchAnalysisRouteCatalog.loadPage] invalid bucket")
	local mapToken = token(mapKey)
	local directory = loadDirectory(mapToken, bucket)
	local ids = {}
	for routeId in directory do ids[#ids + 1] = routeId end
	table.sort(ids)
	local first = math.max(math.floor(cursor or 1), 1)
	local last = math.min(first + PAGE_SIZE - 1, #ids)
	local lines = {}
	for index = first, last do
		local key = routeKey(mapToken, ids[index])
		local projection = directory[ids[index]]
		local line = if typeof(projection) == "table" then projection else routeCache[key]
		if not line then
			line = Store:GetAsync(key)
			if typeof(line) == "table" then routeCache[key] = line end
		end
		if typeof(line) == "table" and line.mapKey == mapKey then lines[#lines + 1] = line end
	end
	return {
		lines = lines,
		nextCursor = if last < #ids then last + 1 else nil,
	}
end

return table.freeze(MatchAnalysisRouteCatalog)
