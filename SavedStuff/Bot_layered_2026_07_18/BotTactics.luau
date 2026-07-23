--!strict
--[[
    BotTactics (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Cheap role-level goal selection. Taggers blend direct pursuit with a
    conservative intercept; runners incrementally score open loop destinations
    instead of greedily maximizing immediate distance.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotMapModel = require(ReplicatedStorage.Modules.Bot.BotMapModel)
local MovementRules = require(ReplicatedStorage.Modules.Bot.BotMovementRules)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole
type RAffordanceGraph = Types.RAffordanceGraph
type RMemory = BotRouteMemory.RMemory

export type RState = {
	lastUpdateAt: number,
	goalPosition: Vector3?,
	decision: string,
	scanCursor: number,
	bestRunnerPosition: Vector3?,
	bestRunnerScore: number,
	lastOpponentPosition: Vector3?,
	lastOpponentVelocity: Vector3,
	lastRunnerCommitAt: number,
}

local BotTactics = {}

function BotTactics.create(): RState
	return {
		lastUpdateAt = 0,
		goalPosition = nil,
		decision = "Waiting for opponent",
		scanCursor = 1,
		bestRunnerPosition = nil,
		bestRunnerScore = -math.huge,
		lastOpponentPosition = nil,
		lastOpponentVelocity = Vector3.zero,
		lastRunnerCommitAt = 0,
	}
end

local function hasDirectLine(botPosition: Vector3, opponentPosition: Vector3, ignore: { Instance }): boolean
	return MovementRules.hasDirectRunCorridor(botPosition, opponentPosition, ignore)
end

local function distanceToSegment(position: Vector3, fromPosition: Vector3, toPosition: Vector3): number
	local segment = toPosition - fromPosition
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 0.001 then return (position - fromPosition).Magnitude end
	local alpha = math.clamp((position - fromPosition):Dot(segment) / lengthSquared, 0, 1)
	return (position - (fromPosition + segment * alpha)).Magnitude
end

local function updateRunnerScan(
	state: RState,
	graph: RAffordanceGraph,
	memory: RMemory,
	botPosition: Vector3,
	opponentPosition: Vector3,
	opponentVelocity: Vector3
)
	local nodes = graph.mapModel.nodes
	if #nodes == 0 then return end
	local scanCount = math.min(72, #nodes)
	local predictedThreat = opponentPosition + opponentVelocity * 0.45
	local opponentDistance = (opponentPosition - botPosition).Magnitude
	local commitSeconds = if opponentDistance < Config.runnerThreatRadius
		then Config.runnerPressureGoalCommitSeconds
		else Config.runnerGoalCommitSeconds

	for _ = 1, scanCount do
		if state.scanCursor > #nodes then
			state.scanCursor = 1
			local reachedGoal = state.goalPosition ~= nil
				and (state.goalPosition - botPosition).Magnitude <= Config.runnerGoalReachedDistance
			if state.bestRunnerPosition
				and (not state.goalPosition
					or reachedGoal
					or os.clock() - state.lastRunnerCommitAt >= commitSeconds)
			then
				state.goalPosition = state.bestRunnerPosition
				state.lastRunnerCommitAt = os.clock()
			end
			state.bestRunnerPosition = nil
			state.bestRunnerScore = -math.huge
		end
		local node = nodes[state.scanCursor]
		state.scanCursor += 1
		if node.isBarrierAdjacent or node.openDirections <= 1 or #node.edges <= 1 then continue end

		local threatDistance = (node.rootPosition - predictedThreat).Magnitude
		local travelDistance = (node.rootPosition - botPosition).Magnitude
		local heightOpportunity = math.max(0, node.rootPosition.Y - botPosition.Y)
		local branchScore = math.min(8, #node.edges) * 1.5 + node.openDirections * 2
		local tooFarPenalty = math.max(0, travelDistance - 120) * 0.08
		local approachThreat = math.max(0, 20 - threatDistance) * 3
		local routeThreatDistance = distanceToSegment(predictedThreat, botPosition, node.rootPosition)
		local routeThreatPenalty = math.max(0, Config.runnerThreatRadius - routeThreatDistance) * 2.5
		if routeThreatDistance <= Config.tagRange + 1 then routeThreatPenalty += 35 end
		local learned = BotRouteMemory.getAreaScore(memory, node.rootPosition, "Runner") * 0.08
		local continuityScore = 0
		if state.goalPosition then
			local currentDirection = state.goalPosition - botPosition
			local candidateDirection = node.rootPosition - botPosition
			local currentFlat = Vector3.new(currentDirection.X, 0, currentDirection.Z)
			local candidateFlat = Vector3.new(candidateDirection.X, 0, candidateDirection.Z)
			if currentFlat.Magnitude > 0.1 and candidateFlat.Magnitude > 0.1 then
				local continuityWeight = if (opponentPosition - botPosition).Magnitude < Config.runnerThreatRadius
					then Config.runnerPressureDirectionContinuityWeight
					else Config.runnerDirectionContinuityWeight
				continuityScore = currentFlat.Unit:Dot(candidateFlat.Unit) * continuityWeight
			end
		end
		local score = threatDistance * 0.7
			+ branchScore
			+ math.min(12, heightOpportunity) * 0.3
			+ learned
			+ continuityScore
			- travelDistance * 0.16
			- tooFarPenalty
			- approachThreat
			- routeThreatPenalty
		if score > state.bestRunnerScore then
			state.bestRunnerScore = score
			state.bestRunnerPosition = node.rootPosition
		end
	end
end

function BotTactics.update(
	state: RState,
	role: BotRole,
	graph: RAffordanceGraph?,
	memory: RMemory,
	botPosition: Vector3,
	opponentPosition: Vector3,
	opponentVelocity: Vector3,
	ignore: { Instance }
): (Vector3, string, boolean)
	local now = os.clock()
	local distance = (opponentPosition - botPosition).Magnitude
	local verticalDelta = math.abs(opponentPosition.Y - botPosition.Y)
	local flatVelocity = Vector3.new(opponentVelocity.X, 0, opponentVelocity.Z)
	local corridorOpen = verticalDelta <= Config.directChaseVerticalTolerance
		and hasDirectLine(botPosition, opponentPosition, ignore)
	local opponentToBot = Vector3.new(
		botPosition.X - opponentPosition.X,
		0,
		botPosition.Z - opponentPosition.Z
	)
	local trailingPlayer = role == "Tagger"
		and corridorOpen
		and distance <= Config.taggerTrailingDirectChaseDistance
		and flatVelocity.Magnitude >= Config.taggerTrailingMinimumSpeed
		and opponentToBot.Magnitude > 0.1
		and opponentToBot.Unit:Dot(flatVelocity.Unit) <= Config.taggerTrailingAlignmentDot
	local direct = corridorOpen and (distance <= Config.directChaseDistance or trailingPlayer)
	local directAvailable = direct

	if now - state.lastUpdateAt < Config.tacticsIntervalSeconds and state.goalPosition then
		if role == "Tagger" and directAvailable then
			state.goalPosition = opponentPosition
			state.decision = if trailingPlayer
				then "Trailing direct chase: stay on the player's route"
				else "Direct chase: mirror nearby player movement"
		elseif role == "Runner" then
			directAvailable = hasDirectLine(botPosition, state.goalPosition, ignore)
				and math.abs(state.goalPosition.Y - botPosition.Y) <= Config.directChaseVerticalTolerance
				and distanceToSegment(opponentPosition, botPosition, state.goalPosition) > Config.runnerThreatRadius
		end
		return state.goalPosition, state.decision, directAvailable
	end
	state.lastUpdateAt = now

	if role == "Tagger" then
		local previousFlatVelocity = Vector3.new(
			state.lastOpponentVelocity.X,
			0,
			state.lastOpponentVelocity.Z
		)
		local directionStable = flatVelocity.Magnitude >= Config.taggerInterceptMinimumSpeed
			and previousFlatVelocity.Magnitude >= Config.taggerInterceptMinimumSpeed
			and flatVelocity.Unit:Dot(previousFlatVelocity.Unit) >= Config.taggerInterceptDirectionStabilityDot
		local shouldIntercept = distance >= Config.taggerInterceptMinimumDistance and directionStable
		local leadSeconds = if shouldIntercept
			then math.clamp(distance / 120, 0.08, Config.taggerInterceptMaximumLeadSeconds)
			else 0
		local predicted = opponentPosition + flatVelocity * leadSeconds
		local routePrediction: Vector3? = nil
		local routeConfidence = 0
		if shouldIntercept and graph and graph.ready then
			local currentNode = BotMapModel.findNearestNodeOnLayer(
				graph.mapModel,
				opponentPosition,
				Config.neighborRadius,
				Config.plannerGoalLayerTolerance
			) or BotMapModel.findNearestNode(graph.mapModel, opponentPosition, Config.neighborRadius)
			if currentNode then
				for _, edgeId in currentNode.edges do
					local edge = graph.edges[edgeId]
					local destination = graph.mapModel.nodes[edge.to]
					local score = BotRouteMemory.getPlayerTransitionScore(memory, currentNode.rootPosition, destination.rootPosition)
					if score > routeConfidence then
						routeConfidence = score
						routePrediction = destination.rootPosition
					end
				end
			end
		end
		if shouldIntercept and routePrediction and routeConfidence >= 2 then
			local routeWeight = math.clamp(routeConfidence / 12, 0.2, 0.65)
			predicted = predicted:Lerp(routePrediction, routeWeight)
		end
		if direct or distance <= Config.taggerEmergencyDirectChaseDistance then
			state.goalPosition = opponentPosition
			state.decision = if trailingPlayer
				then "Trailing direct chase: stay on the player's route"
				else "Direct chase: mirror nearby player movement"
		elseif shouldIntercept then
			state.goalPosition = predicted
			state.decision = if routePrediction and routeConfidence >= 2
				then `Route-history intercept ({math.floor(routeConfidence * 10) / 10} evidence)`
				else `Stable-movement intercept {math.floor(leadSeconds * 1000)}ms ahead`
		else
			state.goalPosition = opponentPosition
			state.decision = "Route chase: movement changed too recently to predict"
		end
	else
		if graph and graph.ready then updateRunnerScan(state, graph, memory, botPosition, opponentPosition, opponentVelocity) end
		if not state.goalPosition then
			local away = botPosition - opponentPosition
			if away.Magnitude <= 0.1 then away = Vector3.xAxis end
			state.goalPosition = botPosition + away.Unit * 48
		end
		state.decision = if distance < 18
			then "Escape pressure: nearest open branch"
			else "Loop route: preserve exits and quadrant movement"
		directAvailable = hasDirectLine(botPosition, state.goalPosition :: Vector3, ignore)
			and math.abs((state.goalPosition :: Vector3).Y - botPosition.Y) <= Config.directChaseVerticalTolerance
			and distanceToSegment(opponentPosition, botPosition, state.goalPosition :: Vector3) > Config.runnerThreatRadius
	end
	state.lastOpponentPosition = opponentPosition
	state.lastOpponentVelocity = opponentVelocity

	return state.goalPosition :: Vector3, state.decision, directAvailable
end

return table.freeze(BotTactics)
