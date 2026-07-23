--!strict
--[[
    OrderedLeaderboardService (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Provides cached reads and serialized score writes for configured all-time
    ordered leaderboards.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderboards = require(ReplicatedStorage.Shared.Configs.Leaderboards)

type RCategoryInfo = {
	dataStoreName: string,
	playerAttribute: string,
}

local categories = Leaderboards.categories :: { [string]: RCategoryInfo }

export type RLeaderboardEntry = {
	userId: number,
	score: number,
}

type RCache = {
	expiresAt: number,
	entries: { RLeaderboardEntry },
}

local OrderedLeaderboardService = {}
local stores: { [string]: OrderedDataStore } = {}
local caches: { [string]: RCache } = {}
local pendingScores: { [string]: { [number]: number } } = {}
local writing: { [string]: { [number]: boolean } } = {}

local function getStore(category: string): OrderedDataStore
	local categoryInfo = categories[category]
	assert(categoryInfo, `[OrderedLeaderboardService] Unknown category {category}`)
	local existing = stores[category]
	if existing then return existing end
	local store = DataStoreService:GetOrderedDataStore(categoryInfo.dataStoreName)
	stores[category] = store
	return store
end

function OrderedLeaderboardService.setScore(category: string, userId: number, score: number)
	assert(userId > 0, "[OrderedLeaderboardService.setScore] userId must be positive")
	assert(score == score and math.abs(score) < math.huge, "[OrderedLeaderboardService.setScore] score must be finite")
	local categoryPending = pendingScores[category]
	if not categoryPending then
		categoryPending = {}
		pendingScores[category] = categoryPending
	end
	categoryPending[userId] = math.round(score)
	local categoryWriting = writing[category]
	if not categoryWriting then
		categoryWriting = {}
		writing[category] = categoryWriting
	end
	if categoryWriting[userId] then return end
	categoryWriting[userId] = true
	task.spawn(function()
		while categoryPending[userId] ~= nil do
			local nextScore = categoryPending[userId]
			categoryPending[userId] = nil
			local success = false
			local message: any = nil
			for attempt = 1, 3 do
				success, message = pcall(function()
					getStore(category):SetAsync(tostring(userId), nextScore)
				end)
				if success then break end
				if attempt < 3 then task.wait(2 ^ (attempt - 1)) end
			end
			if not success then warn(`[OrderedLeaderboardService] Failed writing {category}/{userId}: {message}`) end
		end
		categoryWriting[userId] = nil
		for cacheKey in caches do
			if cacheKey:sub(1, #category + 1) == `{category}:` then caches[cacheKey] = nil end
		end
	end)
end

function OrderedLeaderboardService.getTop(category: string, count: number): { RLeaderboardEntry }
	count = math.clamp(math.floor(count), 1, Leaderboards.maximumEntries)
	local cacheKey = `{category}:{count}`
	local cached = caches[cacheKey]
	if cached and cached.expiresAt > os.clock() then return table.clone(cached.entries) end
	local success, pages = pcall(function()
		return getStore(category):GetSortedAsync(false, count)
	end)
	if not success then
		warn(`[OrderedLeaderboardService] Failed reading {category}: {pages}`)
		return {}
	end
	local entries: { RLeaderboardEntry } = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if not userId then continue end
		table.insert(entries, { userId = userId, score = item.value })
	end
	caches[cacheKey] = { expiresAt = os.clock() + Leaderboards.cacheSeconds, entries = entries }
	return table.clone(entries)
end

return table.freeze(OrderedLeaderboardService)
