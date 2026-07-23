--!strict
--[[
    MatchLinePredictor (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/21

    Ranks demonstrated lines and proposes transition chains assembled from
    repeatable player decisions. Predicted chains remain explicitly labeled.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisConfig)
local Types = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisTypes)

type ObservedRole = Types.ObservedRole
type RMemory = Types.RMemory

export type RCandidate = {
	kind: "Observed" | "Predicted" | "Authored",
	role: ObservedRole,
	verdict: "Proven" | "Good" | "Promising" | "Try",
	score: number,
	time: number,
	advantage: number,
	reliability: number,
	confidence: number,
	consistency: number,
	improvement: number,
	points: { Vector3 },
	actions: { string },
	entryDistance: number?,
	tacticalGain: number?,
	title: string?,
	uses: number?,
	catches: number?,
	catchRate: number?,
	continuation: boolean?,
	closestOpponentDistance: number?,
}

export type RRecommendationContext = {
	position: Vector3,
	look: Vector3,
	opponentPosition: Vector3?,
	opponentVelocity: Vector3?,
	opponentLook: Vector3?,
	predictionTimeOffset: number?,
}

local MatchLinePredictor = {}
local cachedObservedMemory: RMemory? = nil
local cachedPredictedMemory: RMemory? = nil
local cachedObserved: { [ObservedRole]: { RCandidate } } = {
	Chaser = {},
	Runner = {},
}
local cachedPredicted: { [ObservedRole]: { RCandidate } } = {
	Chaser = {},
	Runner = {},
}
local cachedReviewMemory: RMemory? = nil
local cachedReviewBuckets: { [string]: { { [string]: any } } } = {}
local predicted: (RMemory, ObservedRole) -> { RCandidate }

local function reviewBucket(position: Vector3): string
	return `{math.floor(position.X / 32)}:{math.floor(position.Y / 32)}:{math.floor(position.Z / 32)}`
end

local function reviewIndex(memory: RMemory): { [string]: { { [string]: any } } }
	if cachedReviewMemory == memory then return cachedReviewBuckets end
	cachedReviewMemory = memory
	cachedReviewBuckets = {}
	for _, review in memory.routeReviews or {} do
		local point = review.points and review.points[1]
		if typeof(point) ~= "table" or #point < 3 then continue end
		local key = reviewBucket(Vector3.new(point[1], point[2], point[3]))
		local bucket = cachedReviewBuckets[key]
		if not bucket then
			bucket = {}
			cachedReviewBuckets[key] = bucket
		end
		bucket[#bucket + 1] = review
	end
	return cachedReviewBuckets
end

local function routeReview(memory: RMemory, role: ObservedRole, points: { Vector3 }): (number, number, number)
	if role ~= "Runner" or #points < 2 then return 0, 0, 0 end
	local uses = 0
	local catches = 0
	local first = points[1]
	local originX = math.floor(first.X / 32)
	local originY = math.floor(first.Y / 32)
	local originZ = math.floor(first.Z / 32)
	local nearbyReviews = {}
	local buckets = reviewIndex(memory)
	for x = originX - 1, originX + 1 do
		for y = originY - 1, originY + 1 do
			for z = originZ - 1, originZ + 1 do
				for _, review in buckets[`{x}:{y}:{z}`] or {} do nearbyReviews[#nearbyReviews + 1] = review end
			end
		end
	end
	for _, review in nearbyReviews do
		if typeof(review.points) ~= "table" or #review.points < 2 then continue end
		local totalDistance = 0
		for index, rawPoint in review.points do
			if typeof(rawPoint) ~= "table" or #rawPoint < 3 then
				totalDistance = math.huge
				break
			end
			local reviewPoint = Vector3.new(rawPoint[1], rawPoint[2], rawPoint[3])
			local candidateIndex = math.clamp(math.round(1 + (#points - 1) * (index - 1) / math.max(#review.points - 1, 1)), 1, #points)
			totalDistance += (points[candidateIndex] - reviewPoint).Magnitude
		end
		if totalDistance / #review.points <= Config.routeReviewCorridorRadius then
			uses += math.max(tonumber(review.uses) or 0, 0)
			catches += math.max(tonumber(review.catches) or 0, 0)
		end
	end
	return uses, catches, catches / math.max(uses, 1)
end

local function cellPosition(key: string): Vector3?
	local x, y, z = string.match(key, "^(-?%d+):(-?%d+):(-?%d+)$")
	if not x or not y or not z then return nil end
	return Vector3.new(
		(tonumber(x) :: number) * Config.cellSize + Config.cellSize * 0.5,
		(tonumber(y) :: number) * Config.cellSize + Config.cellSize * 0.5,
		(tonumber(z) :: number) * Config.cellSize + Config.cellSize * 0.5
	)
end

local function demonstrated(memory: RMemory, role: ObservedRole, maximum: number?): { RCandidate }
	local candidates = {}
	for lineIndex, line in memory.lines do
		if lineIndex % 100 == 0 then task.wait() end
		if line.role ~= role or typeof(line.points) ~= "table" then continue end
		local attempts = math.max(tonumber(line.attempts) or 1, 1)
		local averageAdvantage = (tonumber(line.totalAdvantage) or tonumber(line.advantage) or 0) / attempts
		local averageOutcome = (tonumber(line.totalOutcome) or tonumber(line.outcome) or 0) / attempts
		local averageTime = (tonumber(line.totalTime) or tonumber(line.duration) or 1) / attempts
		local averageTimeSquared = (tonumber(line.totalTimeSquared) or averageTime ^ 2 * attempts) / attempts
		local timeDeviation = math.sqrt(math.max(averageTimeSquared - averageTime ^ 2, 0))
		local consistency = math.clamp(1 - timeDeviation / math.max(averageTime, 0.1), 0, 1)
		local repeatConfidence = math.min(attempts / Config.provenRouteMinimumAttempts, 1)
		local confidence = repeatConfidence * 0.7 + consistency * 0.3
		local reliability = confidence
		local firstTime = tonumber(line.firstTime) or averageTime
		local bestTime = tonumber(line.bestTime) or tonumber(line.duration) or averageTime
		local improvement = math.clamp((firstTime - bestTime) / math.max(firstTime, 0.1), -1, 1)
		local isAuthored = line.authored == true
		local authoredRating = tonumber(line.authoredRating) or 3
		local authoredRatingCount = math.max(tonumber(line.authoredRatingCount) or 0, 0)
		local authoredSuccessRate = math.clamp(tonumber(line.authoredSuccessRate) or 1, 0, 1)
		if isAuthored then
			confidence *= 0.5 + authoredSuccessRate * 0.5
			reliability = confidence
		end
		local points = {}
		for _, point in line.points do
			if typeof(point) == "table" and #point >= 3 then
				points[#points + 1] = Vector3.new(point[1], point[2], point[3])
			end
		end
		if #points < 2 then continue end
		local uses, catches, catchRate = routeReview(memory, role, points)
		local catchEvidence = math.min(uses / 3, 1)
		confidence *= 1 - catchRate * catchEvidence * 0.85
		reliability = confidence
		local verdict: "Proven" | "Good" | "Promising" | "Try" = "Promising"
		if isAuthored and authoredRatingCount >= 3 and authoredRating >= 4 and authoredSuccessRate >= 0.75 then
			verdict = if catchRate <= Config.provenRouteMaximumCatchRate then "Proven" else "Promising"
		elseif isAuthored and authoredRatingCount >= 1 and authoredRating >= 3.5 and authoredSuccessRate >= 0.6 then
			verdict = if catchRate <= Config.goodRouteMaximumCatchRate then "Good" else "Promising"
		elseif attempts >= Config.provenRouteMinimumAttempts
			and confidence >= Config.provenRouteMinimumConfidence
			and (averageAdvantage >= 0 or averageOutcome > 0)
			and catchRate <= Config.provenRouteMaximumCatchRate
		then
			verdict = "Proven"
		elseif attempts >= Config.goodRouteMinimumAttempts
			and confidence >= Config.goodRouteMinimumConfidence
			and (averageAdvantage >= 0 or averageOutcome > 0)
			and catchRate <= Config.goodRouteMaximumCatchRate
		then
			verdict = "Good"
		end
		if uses >= 2 and catchRate >= 0.65 then verdict = "Try" end
		local score = averageAdvantage * 1.8
			+ averageOutcome * 8
			+ (tonumber(line.displacement) or 0) / math.max(averageTime, 0.1) * 0.15
			+ reliability * 4
			+ consistency * 2
			+ improvement * 2
			+ (tonumber(line.techCount) or 0) * 0.15
			+ (if isAuthored then (authoredRating - 3) * 2 else 0)
			+ (if isAuthored then (authoredSuccessRate - 0.5) * 3 else 0)
			- catchRate * catchEvidence * Config.routeCatchScorePenalty
		candidates[#candidates + 1] = {
			kind = if isAuthored then "Authored" else "Observed",
			role = role,
			verdict = verdict,
			score = score,
			time = averageTime,
			advantage = averageAdvantage,
			reliability = reliability,
			confidence = confidence,
			consistency = consistency,
			improvement = improvement,
			points = points,
			actions = if typeof(line.actions) == "table" then table.clone(line.actions) else {},
			title = if isAuthored then tostring(line.authoredTitle or "Authored Route") else nil,
			uses = uses,
			catches = catches,
			catchRate = catchRate,
		}
	end
	table.sort(candidates, function(a, b) return a.score > b.score end)
	if maximum then
		while #candidates > maximum do table.remove(candidates) end
	end
	return candidates
end

local function observedSources(memory: RMemory, role: ObservedRole): { RCandidate }
	if cachedObservedMemory ~= memory then
		cachedObservedMemory = memory
		cachedObserved.Chaser = demonstrated(memory, "Chaser", nil)
		cachedObserved.Runner = demonstrated(memory, "Runner", nil)
	end
	if cachedPredictedMemory ~= memory then
		cachedPredictedMemory = memory
		cachedPredicted.Chaser = predicted(memory, "Chaser")
		cachedPredicted.Runner = predicted(memory, "Runner")
	end
	return cachedObserved[role]
end

predicted = function(memory: RMemory, role: ObservedRole): { RCandidate }
	local outgoing: { [string]: { { to: string, time: number, advantage: number, reliability: number, techs: number } } } = {}
	local starts = {}
	local function addEdge(from: string, to: string, time: number, advantage: number, reliability: number, techs: number)
		local list = outgoing[from]
		if not list then
			list = {}
			outgoing[from] = list
			starts[#starts + 1] = from
		end
		list[#list + 1] = {
			to = to,
			time = time,
			advantage = advantage,
			reliability = reliability,
			techs = techs,
		}
	end
	local transitionIndex = 0
	for key, info in memory.transitions do
		transitionIndex += 1
		if transitionIndex % 1500 == 0 then task.wait() end
		local edgeRole, from, to = string.match(key, "^(%a+):([^>]+)>(.+)$")
		if edgeRole ~= role or not from or not to then continue end
		local count = math.max(tonumber(info.count) or 0, 0)
		if count < 2 then continue end
		addEdge(
			from,
			to,
			(tonumber(info.time) or 0) / count,
			(tonumber(info.advantage) or 0) / count,
			math.min(count / 12, 1),
			(tonumber(info.techs) or 0) / count
		)
	end
	for _, line in memory.lines do
		if line.authored ~= true or line.role ~= role or typeof(line.points) ~= "table" then continue end
		local rating = tonumber(line.authoredRating) or 3
		local ratingCount = tonumber(line.authoredRatingCount) or 0
		if ratingCount >= 2 and rating < 2.75 then continue end
		local reliability = math.clamp(0.35 + ratingCount * 0.12 + (rating - 3) * 0.08, 0.2, 0.95)
		local previousCell: string? = nil
		local cellEnteredTime = 0
		for index, point in line.points do
			if typeof(point) ~= "table" or #point < 4 then continue end
			local currentCell = `{math.floor(point[1] / Config.cellSize)}:{math.floor(point[2] / Config.cellSize)}:{math.floor(point[3] / Config.cellSize)}`
			local currentTime = tonumber(point[4]) or index * Config.sampleInterval
			if previousCell and previousCell ~= currentCell then
				local action = if typeof(line.actions) == "table" then tostring(line.actions[index] or "Run") else "Run"
				addEdge(previousCell, currentCell, math.max(currentTime - cellEnteredTime, 0.03), 0, reliability, if action ~= "Run" then 1 else 0)
				cellEnteredTime = currentTime
			end
			previousCell = currentCell
		end
	end

	local beams = {}
	for _, start in starts do
		beams[#beams + 1] = { cells = { start }, score = 0, time = 0, advantage = 0, reliability = 1 }
	end
	for _ = 1, 7 do
		local nextBeams = {}
		for _, beam in beams do
			local from = beam.cells[#beam.cells]
			for _, edge in outgoing[from] or {} do
				if table.find(beam.cells, edge.to) then continue end
				local cells = table.clone(beam.cells)
				cells[#cells + 1] = edge.to
				local advantage = beam.advantage + edge.advantage
				local time = beam.time + edge.time
				local reliability = math.min(beam.reliability, edge.reliability)
				local score = advantage * 1.8 - time * 0.25 + reliability * 3 + edge.techs * 0.2
				nextBeams[#nextBeams + 1] = {
					cells = cells,
					score = score,
					time = time,
					advantage = advantage,
					reliability = reliability,
				}
			end
		end
		table.sort(nextBeams, function(a, b) return a.score > b.score end)
		while #nextBeams > 36 do table.remove(nextBeams) end
		if #nextBeams == 0 then break end
		beams = nextBeams
	end

	local candidates = {}
	for _, beam in beams do
		if #beam.cells < 4 then continue end
		local points = {}
		for _, key in beam.cells do
			local position = cellPosition(key)
			if position then points[#points + 1] = position end
		end
		if #points < 4 then continue end
		candidates[#candidates + 1] = {
			kind = "Predicted",
			role = role,
			verdict = "Try",
			score = beam.score,
			time = beam.time,
			advantage = beam.advantage,
			reliability = beam.reliability,
			confidence = beam.reliability,
			consistency = beam.reliability,
			improvement = 0,
			points = points,
			actions = {},
		}
	end
	table.sort(candidates, function(a, b) return a.score > b.score end)
	while #candidates > 5 do table.remove(candidates) end
	return candidates
end

function MatchLinePredictor.build(memory: RMemory, role: ObservedRole): { RCandidate }
	local candidates = table.clone(observedSources(memory, role))
	while #candidates > 8 do table.remove(candidates) end
	local generated = cachedPredicted[role]
	for _, candidate in generated do candidates[#candidates + 1] = candidate end
	table.sort(candidates, function(a, b) return a.score > b.score end)
	while #candidates > 10 do table.remove(candidates) end
	return candidates
end

-- Selects demonstrated and evidence-backed generated lines that the local
-- player can enter immediately. Only the already-passed prefix is removed, so
-- guidance never asks the player to return to a route's recording start.
function MatchLinePredictor.recommend(
	memory: RMemory,
	role: ObservedRole,
	context: RRecommendationContext
): { RCandidate }
	local recommendations = {}
	local currentOpponentDistance = if context.opponentPosition
		then (context.position - context.opponentPosition).Magnitude
		else 0
	local opponentVelocity = context.opponentVelocity or Vector3.zero
	if opponentVelocity.Magnitude < 2 and context.opponentLook then
		local flatLook = context.opponentLook * Vector3.new(1, 0, 1)
		if flatLook.Magnitude > 0.001 then opponentVelocity = flatLook.Unit * 8 end
	end
	local predictionTimeOffset = math.max(context.predictionTimeOffset or 0, 0)
	local flatLook = context.look * Vector3.new(1, 0, 1)
	if flatLook.Magnitude > 0.001 then flatLook = flatLook.Unit end

	local sources = table.clone(observedSources(memory, role))
	for _, source in cachedPredicted[role] do sources[#sources + 1] = source end
	for _, source in sources do
		if source.kind == "Predicted" and source.confidence < 0.18 then continue end
		local points = source.points
		if #points < Config.recommendationMinimumPoints then continue end

		local entryIndex = 1
		local entryDistance = math.huge
		for index, point in points do
			local distance = (point - context.position).Magnitude
			if distance < entryDistance then
				entryDistance = distance
				entryIndex = index
			end
		end
		if entryDistance > Config.recommendationEntryRadius
			or #points - entryIndex + 1 < Config.recommendationMinimumPoints
		then
			continue
		end
		while entryIndex < #points - Config.recommendationMinimumPoints + 1
			and (points[entryIndex] - context.position).Magnitude <= Config.recommendationAdvanceRadius
		do
			entryIndex += 1
		end

		local routePoints = {}
		local routeActions = {}
		local actions = source.actions
		local previousSourceAction = "Run"
		for index = entryIndex, #points do
			local point = points[index]
			local action = tostring(actions[index] or "Run")
			local previousPoint = routePoints[#routePoints]
			local actionChanged = action ~= previousSourceAction and action ~= "Run"
			local shouldKeep = not previousPoint
				or index == #points
				or (point - previousPoint).Magnitude >= Config.recommendationVisualPointSpacing
				or actionChanged
			if shouldKeep then
				routePoints[#routePoints + 1] = point
				routeActions[#routeActions + 1] = action
			end
			previousSourceAction = action
		end

		local firstDirection = routePoints[1] - context.position
		local flatDirection = firstDirection * Vector3.new(1, 0, 1)
		local heading = if flatDirection.Magnitude > 0.001 and flatLook.Magnitude > 0.001
			then flatLook:Dot(flatDirection.Unit)
			else 0
		local endpoint = routePoints[#routePoints]
		local tacticalGain = 0
		local dangerPenalty = 0
		local closestOpponentDistance = math.huge
		local routeDistance = 0
		for index = 2, #routePoints do routeDistance += (routePoints[index] - routePoints[index - 1]).Magnitude end
		local sourceDistance = 0
		for index = 2, #points do sourceDistance += (points[index] - points[index - 1]).Magnitude end
		local remainingTime = source.time * math.clamp(routeDistance / math.max(sourceDistance, 0.1), 0.05, 1)
		if context.opponentPosition then
			local approachTime = entryDistance / 32
			closestOpponentDistance = currentOpponentDistance
			for step = 1, 3 do
				local alpha = step / 3
				local approachPoint = context.position:Lerp(routePoints[1], alpha)
				local predictionTime = predictionTimeOffset + approachTime * alpha
				local decay = Config.opponentPredictionDecaySeconds
				local effectiveTime = decay * (1 - math.exp(-predictionTime / math.max(decay, 0.01)))
				local predictedOpponent = context.opponentPosition + opponentVelocity * effectiveTime
				closestOpponentDistance = math.min(closestOpponentDistance, (approachPoint - predictedOpponent).Magnitude)
			end
			local traversed = 0
			for index, point in routePoints do
				if index > 1 then traversed += (point - routePoints[index - 1]).Magnitude end
				local routeTime = remainingTime * traversed / math.max(routeDistance, 0.1)
				local predictionTime = predictionTimeOffset + approachTime + routeTime
				local decay = Config.opponentPredictionDecaySeconds
				local effectiveTime = decay * (1 - math.exp(-predictionTime / math.max(decay, 0.01)))
				local predictedOpponent = context.opponentPosition + opponentVelocity * effectiveTime
				closestOpponentDistance = math.min(closestOpponentDistance, (point - predictedOpponent).Magnitude)
			end
			local endpointPredictionTime = predictionTimeOffset + approachTime + remainingTime
			local decay = Config.opponentPredictionDecaySeconds
			local effectiveEndpointTime = decay * (1 - math.exp(-endpointPredictionTime / math.max(decay, 0.01)))
			local predictedOpponentEndpoint = context.opponentPosition + opponentVelocity * effectiveEndpointTime
			local endpointDistance = (endpoint - predictedOpponentEndpoint).Magnitude
			if role == "Runner" then
				tacticalGain = endpointDistance - currentOpponentDistance
				dangerPenalty = math.max(0, Config.runnerDangerRadius - closestOpponentDistance) * Config.runnerDangerWeight
				if closestOpponentDistance <= Config.runnerTagRadius then dangerPenalty += Config.runnerTagRiskPenalty end
			else
				tacticalGain = currentOpponentDistance - closestOpponentDistance
				dangerPenalty = closestOpponentDistance * 0.12
			end
		end

		local score = source.score * 0.75
			+ tacticalGain * (if role == "Chaser" then Config.chaserInterceptWeight else 1.8)
			+ heading * 3
			+ source.confidence * 2
			- entryDistance * 0.35
			- dangerPenalty
		recommendations[#recommendations + 1] = {
			kind = source.kind,
			role = role,
			verdict = source.verdict,
			score = score,
			time = remainingTime,
			advantage = source.advantage,
			reliability = source.reliability,
			confidence = source.confidence,
			consistency = source.consistency,
			improvement = source.improvement,
			points = routePoints,
			actions = routeActions,
			entryDistance = entryDistance,
			tacticalGain = tacticalGain,
			title = source.title,
			uses = source.uses,
			catches = source.catches,
			catchRate = source.catchRate,
			closestOpponentDistance = if closestOpponentDistance < math.huge then closestOpponentDistance else nil,
		}
	end

	local hasRoleValidRoute = false
	for _, candidate in recommendations do
		local separation = candidate.closestOpponentDistance
		if separation and ((role == "Runner" and separation > Config.runnerTagRadius)
			or (role == "Chaser" and separation <= Config.runnerTagRadius and candidate.confidence >= 0.3))
		then
			hasRoleValidRoute = true
			break
		end
	end
	if hasRoleValidRoute then
		for index = #recommendations, 1, -1 do
			local candidate = recommendations[index]
			local separation = candidate.closestOpponentDistance
			local roleValid = separation and ((role == "Runner" and separation > Config.runnerTagRadius)
				or (role == "Chaser" and separation <= Config.runnerTagRadius and candidate.confidence >= 0.3))
			if not roleValid then table.remove(recommendations, index) end
		end
	end

	table.sort(recommendations, function(a, b) return a.score > b.score end)
	while #recommendations > Config.recommendationMaximumLines do table.remove(recommendations) end
	return recommendations
end

function MatchLinePredictor.routeReview(memory: RMemory, role: ObservedRole, points: { Vector3 }): (number, number, number)
	return routeReview(memory, role, points)
end

-- Invalidates derived candidate lists after streamed route pages mutate the
-- current memory table in place.
function MatchLinePredictor.invalidate()
	cachedObservedMemory = nil
	cachedPredictedMemory = nil
	cachedReviewMemory = nil
	table.clear(cachedReviewBuckets)
	table.clear(cachedObserved.Chaser)
	table.clear(cachedObserved.Runner)
	table.clear(cachedPredicted.Chaser)
	table.clear(cachedPredicted.Runner)
end

function MatchLinePredictor.invalidateRoutes()
	cachedObservedMemory = nil
	table.clear(cachedObserved.Chaser)
	table.clear(cachedObserved.Runner)
end

return table.freeze(MatchLinePredictor)
