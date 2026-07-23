--!strict
--[[
    RoutePathProcessor (Shared)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Removes non-technical backtracking from recorded routes and derives a
    stable planner corridor from the consensus endpoints of repeated attempts.
]]

export type RPath = {
	points: { { number } },
	actions: { string },
}

local RoutePathProcessor = {}

local BACKTRACK_RADIUS = 2.5
local MINIMUM_BACKTRACK_SAMPLES = 4
local MINIMUM_POINT_SPACING = 0.45

local function position(point: { number }): Vector3
	return Vector3.new(point[1], point[2], point[3])
end

local function technical(action: string): boolean
	return action ~= "Run" and action ~= "Drop"
end

local function clonePoint(point: { number }): { number }
	return table.clone(point)
end

-- Removes loops only when the removed section contains no authored tech.
-- Timestamps are rebased so erased wandering does not inflate planner time.
function RoutePathProcessor.clean(points: { { number } }, actions: { string }): RPath
	assert(#points == #actions, "[RoutePathProcessor.clean] points and actions must have equal lengths")
	if #points < 3 then return { points = table.clone(points), actions = table.clone(actions) } end
	local cleanedPoints = {}
	local cleanedActions = {}
	local sourceTimes = {}
	local removedSeconds = 0
	for sourceIndex, sourcePoint in points do
		local action = actions[sourceIndex]
		local point = clonePoint(sourcePoint)
		local sourceTime = sourcePoint[4]
		point[4] = math.max(sourceTime - removedSeconds, 0)
		local loopIndex: number? = nil
		for candidateIndex = #cleanedPoints - MINIMUM_BACKTRACK_SAMPLES, 1, -1 do
			if (position(cleanedPoints[candidateIndex]) - position(sourcePoint)).Magnitude > BACKTRACK_RADIUS then continue end
			local containsTech = technical(action)
			for actionIndex = candidateIndex + 1, #cleanedActions do
				if technical(cleanedActions[actionIndex]) then
					containsTech = true
					break
				end
			end
			if not containsTech then loopIndex = candidateIndex break end
		end
		if loopIndex then
			removedSeconds += math.max(sourceTime - sourceTimes[loopIndex], 0)
			point[4] = math.max(sourceTime - removedSeconds, 0)
			for index = #cleanedPoints, loopIndex + 1, -1 do
				table.remove(cleanedPoints, index)
				table.remove(cleanedActions, index)
				table.remove(sourceTimes, index)
			end
			cleanedPoints[loopIndex] = point
			cleanedActions[loopIndex] = action
			sourceTimes[loopIndex] = sourceTime
		elseif #cleanedPoints == 0
			or (position(cleanedPoints[#cleanedPoints]) - position(point)).Magnitude >= MINIMUM_POINT_SPACING
			or technical(action)
			or sourceIndex == #points
		then
			cleanedPoints[#cleanedPoints + 1] = point
			cleanedActions[#cleanedActions + 1] = action
			sourceTimes[#sourceTimes + 1] = sourceTime
		end
	end
	if #cleanedPoints < 3 then return { points = table.clone(points), actions = table.clone(actions) } end
	local firstTime = cleanedPoints[1][4]
	for _, point in cleanedPoints do point[4] = math.max(point[4] - firstTime, 0) end
	return { points = cleanedPoints, actions = cleanedActions }
end

function RoutePathProcessor.consensusEndpoints(
	attempts: { { [string]: any } },
	indexes: { number }
): (Vector3, Vector3)
	assert(#indexes > 0, "[RoutePathProcessor.consensusEndpoints] at least one attempt is required")
	local start = Vector3.zero
	local finish = Vector3.zero
	local count = 0
	for _, index in indexes do
		local attempt = attempts[index]
		if not attempt or typeof(attempt.points) ~= "table" or #attempt.points < 2 then continue end
		start += position(attempt.points[1])
		finish += position(attempt.points[#attempt.points])
		count += 1
	end
	assert(count > 0, "[RoutePathProcessor.consensusEndpoints] selected attempts have no usable points")
	return start / count, finish / count
end

-- Crops an attempt to its nearest ordered entry/exit around the consensus
-- anchors. This lets recordings begin from slightly different approaches.
function RoutePathProcessor.trim(points: { { number } }, actions: { string }, start: Vector3, finish: Vector3): RPath
	assert(#points == #actions, "[RoutePathProcessor.trim] points and actions must have equal lengths")
	if #points < 3 then return { points = table.clone(points), actions = table.clone(actions) } end
	local startIndex = 1
	local startDistance = math.huge
	for index = 1, #points - 2 do
		local distance = (position(points[index]) - start).Magnitude
		if distance < startDistance then startIndex, startDistance = index, distance end
	end
	local finishIndex = #points
	local finishDistance = math.huge
	for index = startIndex + 2, #points do
		local distance = (position(points[index]) - finish).Magnitude
		if distance < finishDistance then finishIndex, finishDistance = index, distance end
	end
	local trimmedPoints = {}
	local trimmedActions = {}
	local firstTime = points[startIndex][4]
	for index = startIndex, finishIndex do
		local point = clonePoint(points[index])
		point[4] = math.max(point[4] - firstTime, 0)
		trimmedPoints[#trimmedPoints + 1] = point
		trimmedActions[#trimmedActions + 1] = actions[index]
	end
	return { points = trimmedPoints, actions = trimmedActions }
end

return table.freeze(RoutePathProcessor)
