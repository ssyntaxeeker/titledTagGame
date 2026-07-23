--!strict
--[[
    RouteTrainerData (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Authoritative global authored-route persistence, validation, rating, and
    planner-line projection for whitelisted route teachers.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local Net = require(ReplicatedStorage.Packages.Net)
local RoutePathProcessor = require(ReplicatedStorage.Shared.Bot.RoutePathProcessor)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local LoadIndex = Net:RemoteFunction("LoadAuthoredRouteIndex")
local LoadRoute = Net:RemoteFunction("LoadAuthoredRoute")
local PublishRoute = Net:RemoteFunction("PublishAuthoredRoute")
local RateRoute = Net:RemoteFunction("RateAuthoredRoute")
local DeleteRoute = Net:RemoteFunction("DeleteAuthoredRoute")
local LoadPlannerLines = Net:RemoteFunction("LoadAuthoredPlannerLines")
local Store = DataStoreService:GetDataStore("TitledTagGameAuthoredRoutesV1")

local VALID_ACTIONS = table.freeze {
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
}
local MAXIMUM_ROUTES_PER_MAP = 32
local MAXIMUM_ATTEMPTS = 12
local MAXIMUM_POINTS = 600
local routeCache: { [string]: { [string]: any } } = {}
local indexCache: { [string]: { [string]: any } } = {}
local routeCacheAt: { [string]: number } = {}
local indexCacheAt: { [string]: number } = {}
local lastWriteAt: { [Player]: number } = {}

local function cleanMapKey(raw: any): string?
	if typeof(raw) ~= "string" or #raw < 1 or #raw > 80 then return nil end
	return string.sub(string.gsub(raw, "[^%w_%-:]", "_"), 1, 80)
end

local function cleanRouteId(raw: any): string?
	if typeof(raw) ~= "string" or not string.match(raw, "^[%w%-]+$") or #raw > 64 then return nil end
	return raw
end

local function finite(raw: any, maximum: number): number?
	local value = tonumber(raw)
	if not value or value ~= value or math.abs(value) > maximum then return nil end
	return value
end

local function sanitizeAttempt(raw: any, selected: boolean): { [string]: any }?
	if typeof(raw) ~= "table" or typeof(raw.points) ~= "table" or typeof(raw.actions) ~= "table" then return nil end
	if #raw.points < 3 or #raw.points > MAXIMUM_POINTS or #raw.actions ~= #raw.points then return nil end
	local points = {}
	local previousTime = -math.huge
	for _, rawPoint in raw.points do
		if typeof(rawPoint) ~= "table" or #rawPoint ~= 10 then return nil end
		local point = {}
		for index = 1, 10 do
			local value = finite(rawPoint[index], 100000)
			if not value then return nil end
			point[index] = value
		end
		if point[4] < previousTime or point[4] > 30.5 then return nil end
		previousTime = point[4]
		points[#points + 1] = point
	end
	local actions = {}
	for _, action in raw.actions do
		if typeof(action) ~= "string" or not VALID_ACTIONS[action] then return nil end
		actions[#actions + 1] = action
	end
	local cleaned = RoutePathProcessor.clean(points, actions)
	points = cleaned.points
	actions = cleaned.actions
	local first = points[1]
	local last = points[#points]
	local displacement = (Vector3.new(last[1], last[2], last[3]) - Vector3.new(first[1], first[2], first[3])).Magnitude
	local duration = math.max(last[4], 0.05)
	local distance = 0
	local techCount = 0
	local previousAction = "Run"
	for index = 2, #points do
		local previousPoint = points[index - 1]
		local point = points[index]
		distance += (Vector3.new(point[1], point[2], point[3]) - Vector3.new(previousPoint[1], previousPoint[2], previousPoint[3])).Magnitude
		local action = actions[index]
		if action ~= previousAction and action ~= "Run" and action ~= "Drop" then techCount += 1 end
		previousAction = action
	end
	local success = raw.success == true
	if selected and (not success or displacement < 8 or distance / duration < 5) then return nil end
	return {
		success = success,
		selected = selected,
		duration = duration,
		distance = distance,
		displacement = displacement,
		averageSpeed = distance / duration,
		techCount = techCount,
		points = points,
		actions = actions,
	}
end

local function metadata(route: { [string]: any }): { [string]: any }
	local start = Vector3.zero
	local finish = Vector3.zero
	local middle = Vector3.zero
	local selectedCount = 0
	for _, index in route.bestIndexes do
		local attempt = route.attempts[index]
		if not attempt or #attempt.points < 3 then continue end
		start += Vector3.new(attempt.points[1][1], attempt.points[1][2], attempt.points[1][3])
		finish += Vector3.new(attempt.points[#attempt.points][1], attempt.points[#attempt.points][2], attempt.points[#attempt.points][3])
		local middlePoint = attempt.points[math.ceil(#attempt.points / 2)]
		middle += Vector3.new(middlePoint[1], middlePoint[2], middlePoint[3])
		selectedCount += 1
	end
	assert(selectedCount > 0, "[RouteTrainerData.metadata] route has no selected attempts")
	start /= selectedCount
	finish /= selectedCount
	middle /= selectedCount
	local ratings = route.ratings or {}
	local ratingTotal = 0
	local ratingCount = 0
	for _, rating in ratings do
		ratingTotal += rating
		ratingCount += 1
	end
	local successCount = 0
	for _, attempt in route.attempts do
		if attempt.success then
			successCount += 1
		end
	end
	return {
		id = route.id,
		title = route.title,
		creatorId = route.creatorId,
		creatorName = route.creatorName,
		attemptCount = #route.attempts,
		successCount = successCount,
		rating = if ratingCount > 0 then ratingTotal / ratingCount else 3,
		ratingCount = ratingCount,
		start = { start.X, start.Y, start.Z },
		finish = { finish.X, finish.Y, finish.Z },
		middle = { middle.X, middle.Y, middle.Z },
		updatedAt = route.updatedAt,
	}
end

local function loadIndex(key: string): { [string]: any }
	if indexCache[key] and os.clock() - (indexCacheAt[key] or 0) < 15 then return indexCache[key] end
	local success, result = pcall(function()
		return Store:GetAsync(`Index:{key}`)
	end)
	local index = if success and typeof(result) == "table" then result else { mapKey = key, routes = {} }
	if not success then warn(`[RouteTrainerData] index load failed: {tostring(result)}`) end
	indexCache[key] = index
	indexCacheAt[key] = os.clock()
	return index
end

local function loadRoute(id: string): { [string]: any }?
	if routeCache[id] and os.clock() - (routeCacheAt[id] or 0) < 15 then return routeCache[id] end
	local success, result = pcall(function()
		return Store:GetAsync(`Route:{id}`)
	end)
	if not success then warn(`[RouteTrainerData] route load failed: {tostring(result)}`) end
	if not success or typeof(result) ~= "table" then return nil end
	routeCache[id] = result
	routeCacheAt[id] = os.clock()
	return result
end

local function filteredTitle(player: Player, raw: any): string?
	if typeof(raw) ~= "string" then return nil end
	local title = string.sub(string.match(raw, "^%s*(.-)%s*$") or "", 1, 48)
	if #title < 2 then return nil end
	local success, result = pcall(function()
		return TextService:FilterStringAsync(title, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if success and typeof(result) == "string" and #result >= 2 then return result end
	return if RunService:IsStudio() then title else nil
end

local function selectedIndexes(attempts: { { [string]: any } }): { number }
	local selected = {}
	for index, attempt in attempts do
		if attempt.selected and attempt.success then selected[#selected + 1] = index end
	end
	table.sort(selected, function(a, b)
		local first = attempts[a]
		local second = attempts[b]
		return first.duration < second.duration
	end)
	while #selected > 3 do
		table.remove(selected)
	end
	return selected
end

local function attemptsAreSimilar(first: { [string]: any }, second: { [string]: any }): boolean
	local firstPoints = first.points
	local secondPoints = second.points
	local function position(points: { { number } }, index: number): Vector3
		local point = points[index]
		return Vector3.new(point[1], point[2], point[3])
	end
	return (position(firstPoints, 1) - position(secondPoints, 1)).Magnitude <= 14
		and (position(firstPoints, #firstPoints) - position(secondPoints, #secondPoints)).Magnitude <= 14
		and (position(firstPoints, math.ceil(#firstPoints / 2)) - position(secondPoints, math.ceil(#secondPoints / 2))).Magnitude <= 12
end

local function saveIndex(key: string, routeInfo: { [string]: any })
	local result = Store:UpdateAsync(`Index:{key}`, function(old)
		local index = if typeof(old) == "table" then old else { mapKey = key, routes = {} }
		local replaced = false
		for itemIndex, info in index.routes do
			if info.id == routeInfo.id then
				index.routes[itemIndex] = routeInfo
				replaced = true
				break
			end
		end
		if not replaced then index.routes[#index.routes + 1] = routeInfo end
		table.sort(index.routes, function(a, b)
			local firstScore = (a.rating or 3) + math.min(a.ratingCount or 0, 5) * 0.1
			local secondScore = (b.rating or 3) + math.min(b.ratingCount or 0, 5) * 0.1
			return firstScore > secondScore
		end)
		while #index.routes > MAXIMUM_ROUTES_PER_MAP do
			table.remove(index.routes)
		end
		return index
	end)
	indexCache[key] = result
	indexCacheAt[key] = os.clock()
end

local function deleteOwnedRoute(player: Player, id: string): { [string]: any }
	local route = loadRoute(id)
	if not route then return { success = false, reason = "route unavailable" } end
	if route.creatorId ~= player.UserId then return { success = false, reason = "only the route owner can delete it" } end
	local key = cleanMapKey(route.mapKey)
	if not key then return { success = false, reason = "route has an invalid map key" } end
	local index = Store:UpdateAsync(`Index:{key}`, function(old)
		if typeof(old) ~= "table" then return { mapKey = key, routes = {} } end
		local routes = {}
		for _, info in old.routes or {} do
			if info.id ~= id then routes[#routes + 1] = info end
		end
		old.routes = routes
		return old
	end)
	Store:RemoveAsync(`Route:{id}`)
	indexCache[key] = index
	indexCacheAt[key] = os.clock()
	routeCache[id] = nil
	routeCacheAt[id] = nil
	return { success = true, id = id }
end

local function publish(player: Player, raw: any): { [string]: any }
	if typeof(raw) ~= "table" then return { success = false, reason = "invalid payload" } end
	local key = cleanMapKey(raw.mapKey)
	local title = filteredTitle(player, raw.title)
	if not key or not title or typeof(raw.attempts) ~= "table" or typeof(raw.bestIndexes) ~= "table" then
		return { success = false, reason = "invalid route metadata" }
	end
	local requestedBest = {}
	for _, rawIndex in raw.bestIndexes do
		local index = math.floor(tonumber(rawIndex) or 0)
		if index >= 1 and index <= MAXIMUM_ATTEMPTS then requestedBest[index] = true end
	end
	local attempts = {}
	for index = 1, math.min(#raw.attempts, MAXIMUM_ATTEMPTS) do
		local attempt = sanitizeAttempt(raw.attempts[index], requestedBest[index] == true)
		if not attempt then return { success = false, reason = `attempt {index} failed validation` } end
		attempts[#attempts + 1] = attempt
	end
	if #selectedIndexes(attempts) ~= 3 then return { success = false, reason = "select exactly 3 valid successful attempts" } end

	local mergeId = cleanRouteId(raw.mergeRouteId)
	local route: { [string]: any }
	if mergeId then
		local existing = loadRoute(mergeId)
		if not existing or existing.mapKey ~= key then return { success = false, reason = "merge route unavailable" } end
		local existingAnchor = existing.attempts[existing.bestIndexes[1]]
		local incomingAnchor = attempts[selectedIndexes(attempts)[1]]
		if not existingAnchor or not incomingAnchor or not attemptsAreSimilar(existingAnchor, incomingAnchor) then
			return { success = false, reason = "server rejected dissimilar route merge" }
		end
		route = existing
		route.contributors = if typeof(route.contributors) == "table" then route.contributors else {}
		for _, attempt in attempts do
			route.attempts[#route.attempts + 1] = attempt
		end
		while #route.attempts > MAXIMUM_ATTEMPTS do
			table.remove(route.attempts, 1)
		end
		route.contributors[tostring(player.UserId)] = player.Name
	else
		route = {
			id = HttpService:GenerateGUID(false),
			mapKey = key,
			title = title,
			creatorId = player.UserId,
			creatorName = player.Name,
			contributors = { [tostring(player.UserId)] = player.Name },
			attempts = attempts,
			ratings = {},
			createdAt = os.time(),
		}
	end
	route.bestIndexes = selectedIndexes(route.attempts)
	if #route.bestIndexes < 3 then return { success = false, reason = "route has fewer than 3 planner attempts" } end
	route.updatedAt = os.time()
	Store:SetAsync(`Route:{route.id}`, route)
	routeCache[route.id] = route
	routeCacheAt[route.id] = os.clock()
	local info = metadata(route)
	saveIndex(key, info)
	return { success = true, route = info }
end

local function plannerLines(key: string): { { [string]: any } }
	local lines = {}
	for _, info in loadIndex(key).routes do
		if info.ratingCount >= 2 and info.rating < 2.75 then continue end
		local route = loadRoute(info.id)
		if not route then continue end
		local selected = {}
		for _, index in route.bestIndexes do
			local attempt = route.attempts[index]
			if attempt and attempt.success then
				local cleaned = RoutePathProcessor.clean(attempt.points, attempt.actions)
				local plannerAttempt = table.clone(attempt)
				plannerAttempt.points = cleaned.points
				plannerAttempt.actions = cleaned.actions
				plannerAttempt.duration = math.max(cleaned.points[#cleaned.points][4], 0.05)
				selected[#selected + 1] = plannerAttempt
			end
		end
		if #selected < 3 then continue end
		local selectedIndexesForConsensus = {}
		for selectedIndex in selected do selectedIndexesForConsensus[#selectedIndexesForConsensus + 1] = selectedIndex end
		local consensusStart, consensusFinish = RoutePathProcessor.consensusEndpoints(selected, selectedIndexesForConsensus)
		table.sort(selected, function(a, b)
			local first = RoutePathProcessor.trim(a.points, a.actions, consensusStart, consensusFinish)
			local second = RoutePathProcessor.trim(b.points, b.actions, consensusStart, consensusFinish)
			return first.points[#first.points][4] < second.points[#second.points][4]
		end)
		local best = selected[1]
		local plannerPath = RoutePathProcessor.trim(best.points, best.actions, consensusStart, consensusFinish)
		local plannerDistance = 0
		for pointIndex = 2, #plannerPath.points do
			local previousPoint = plannerPath.points[pointIndex - 1]
			local point = plannerPath.points[pointIndex]
			plannerDistance += (Vector3.new(point[1], point[2], point[3]) - Vector3.new(previousPoint[1], previousPoint[2], previousPoint[3])).Magnitude
		end
		local plannerDuration = math.max(plannerPath.points[#plannerPath.points][4], 0.05)
		local plannerTechCount = 0
		local previousAction = "Run"
		for _, action in plannerPath.actions do
			if action ~= previousAction and action ~= "Run" and action ~= "Drop" then plannerTechCount += 1 end
			previousAction = action
		end
		local totalTime = 0
		local totalTimeSquared = 0
		local selectedDurations = {}
		for _, attempt in selected do
			local selectedPath = RoutePathProcessor.trim(attempt.points, attempt.actions, consensusStart, consensusFinish)
			local duration = math.max(selectedPath.points[#selectedPath.points][4], 0.05)
			totalTime += duration
			totalTimeSquared += duration ^ 2
			selectedDurations[#selectedDurations + 1] = duration
		end
		table.sort(selectedDurations)
		for _, role in { "Runner", "Chaser" } do
			lines[#lines + 1] = {
				role = role,
				points = plannerPath.points,
				actions = plannerPath.actions,
				duration = plannerDuration,
				distance = plannerDistance,
				displacement = (Vector3.new(plannerPath.points[#plannerPath.points][1], plannerPath.points[#plannerPath.points][2], plannerPath.points[#plannerPath.points][3]) - Vector3.new(plannerPath.points[1][1], plannerPath.points[1][2], plannerPath.points[1][3])).Magnitude,
				advantage = 0,
				outcome = 0,
				techCount = plannerTechCount,
				quality = plannerDistance / plannerDuration + plannerTechCount,
				attempts = #selected,
				totalTime = totalTime,
				totalTimeSquared = totalTimeSquared,
				totalAdvantage = 0,
				totalOutcome = 0,
				firstTime = selectedDurations[#selectedDurations],
				bestTime = selectedDurations[1],
				authored = true,
				authoredTitle = route.title,
				authoredRating = info.rating,
				authoredRatingCount = info.ratingCount,
				authoredAttemptCount = info.attemptCount,
				authoredSuccessRate = info.successCount / math.max(info.attemptCount, 1),
			}
		end
		if #lines >= 24 then break end
	end
	return lines
end

local function init()
	LoadIndex.OnServerInvoke = function(player: Player, rawKey: any)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		local key = cleanMapKey(rawKey)
		return if key then loadIndex(key).routes else nil
	end
	LoadRoute.OnServerInvoke = function(player: Player, rawId: any)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		local id = cleanRouteId(rawId)
		return if id then loadRoute(id) else nil
	end
	PublishRoute.OnServerInvoke = function(player: Player, raw: any)
		if BotAccess.userIds[player.UserId] ~= true then return { success = false, reason = "not authorized" } end
		if os.clock() - (lastWriteAt[player] or 0) < 3 then return { success = false, reason = "write rate limited" } end
		lastWriteAt[player] = os.clock()
		local success, result = pcall(function()
			return publish(player, raw)
		end)
		if success then return result end
		warn(`[RouteTrainerData] publish failed: {tostring(result)}`)
		return { success = false, reason = tostring(result) }
	end
	RateRoute.OnServerInvoke = function(player: Player, rawId: any, rawRating: any)
		if BotAccess.userIds[player.UserId] ~= true then return { success = false, reason = "not authorized" } end
		if os.clock() - (lastWriteAt[player] or 0) < 3 then return { success = false, reason = "write rate limited" } end
		local id = cleanRouteId(rawId)
		local rating = math.floor(tonumber(rawRating) or 0)
		if not id or rating < 1 or rating > 5 then return { success = false, reason = "invalid rating" } end
		lastWriteAt[player] = os.clock()
		local success, route = pcall(function()
			return Store:UpdateAsync(`Route:{id}`, function(old)
				if typeof(old) ~= "table" then return nil end
				old.ratings = if typeof(old.ratings) == "table" then old.ratings else {}
				old.ratings[tostring(player.UserId)] = rating
				old.updatedAt = os.time()
				return old
			end)
		end)
		if not success or typeof(route) ~= "table" then return { success = false, reason = tostring(route) } end
		routeCache[id] = route
		routeCacheAt[id] = os.clock()
		local info = metadata(route)
		saveIndex(route.mapKey, info)
		return { success = true, route = info }
	end
	DeleteRoute.OnServerInvoke = function(player: Player, rawId: any)
		if BotAccess.userIds[player.UserId] ~= true then return { success = false, reason = "not authorized" } end
		if os.clock() - (lastWriteAt[player] or 0) < 3 then return { success = false, reason = "write rate limited" } end
		local id = cleanRouteId(rawId)
		if not id then return { success = false, reason = "invalid route id" } end
		lastWriteAt[player] = os.clock()
		local success, result = pcall(function() return deleteOwnedRoute(player, id) end)
		if success then return result end
		warn(`[RouteTrainerData] delete failed: {tostring(result)}`)
		return { success = false, reason = tostring(result) }
	end
	LoadPlannerLines.OnServerInvoke = function(player: Player, rawKey: any)
		if BotAccess.userIds[player.UserId] ~= true then return nil end
		local key = cleanMapKey(rawKey)
		return if key then plannerLines(key) else nil
	end
	Players.PlayerRemoving:Connect(function(player)
		lastWriteAt[player] = nil
	end)
end

return Schedules.Boot.job(init)
