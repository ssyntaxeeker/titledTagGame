--!strict
--[[
    BotTimeTrials (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Runs repeatable endpoint trials for independent explorers. Promotions use
    clean route signatures, median completion time, and repeated success so a
    single lucky physics outcome cannot dominate shared learning.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotAgent = require(ReplicatedStorage.Modules.Bot.BotAgent)
local BotMapModel = require(ReplicatedStorage.Modules.Bot.BotMapModel)
local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole
type RAffordanceGraph = Types.RAffordanceGraph
type RAgent = BotAgent.RAgent
type RMemory = BotRouteMemory.RMemory
type RSurfaceNode = Types.RSurfaceNode
type WeightedExperienceSink = (RAffordanceGraph, number, BotRole, boolean, number, number, number?, Vector3?) -> ()

type RRouteResult = {
	edgeIds: { number },
	durations: { number },
	successes: number,
}

export type RState = {
	enabled: boolean,
	explorationGoals: number,
	startNodeId: number,
	endNodeId: number,
	changeStartNext: boolean,
	pairAttempts: number,
	attemptStartedAt: number,
	attemptEdgeIds: { number },
	attemptFailed: boolean,
	routes: { [string]: RRouteResult },
	pairsCompleted: number,
	usedEndpointIds: { [number]: boolean },
}

local BotTimeTrials = {}

local function eligibleNode(node: RSurfaceNode): boolean
	return not node.isBarrierAdjacent and node.openDirections > 0 and #node.edges > 0
end

local function routeSignature(edgeIds: { number }): string
	local ids: { string } = {}
	for index, edgeId in edgeIds do ids[index] = tostring(edgeId) end
	return table.concat(ids, ">")
end

local function median(values: { number }): number
	local sorted = table.clone(values)
	table.sort(sorted)
	local middle = math.floor((#sorted + 1) * 0.5)
	if #sorted % 2 == 1 then return sorted[middle] end
	return (sorted[middle] + sorted[middle + 1]) * 0.5
end

local function chooseEndpoint(
	graph: RAffordanceGraph,
	anchor: RSurfaceNode,
	random: Random,
	usedEndpointIds: { [number]: boolean },
	reservedPositions: { Vector3 }
): RSurfaceNode
	local nodes = graph.mapModel.nodes
	local bestElevatedNode: RSurfaceNode? = nil
	local bestElevatedScore = -math.huge
	local bestFallbackNode: RSurfaceNode? = nil
	local bestFallbackScore = -math.huge
	for _ = 1, Config.timeTrialEndpointCandidateSamples do
		local candidate = nodes[random:NextInteger(1, #nodes)]
		if candidate.id == anchor.id or usedEndpointIds[candidate.id] or not eligibleNode(candidate) then continue end
		local separated = true
		for _, reservedPosition in reservedPositions do
			if (candidate.rootPosition - reservedPosition).Magnitude < Config.swarmGoalSeparationDistance then
				separated = false
				break
			end
		end
		if not separated then continue end
		local delta = candidate.rootPosition - anchor.rootPosition
		local distance = delta.Magnitude
		if distance < Config.timeTrialMinimumEndpointDistance then continue end
		local heightDifference = math.abs(delta.Y)
		local distanceScore = -math.abs(distance - Config.timeTrialPreferredEndpointDistance) * 0.02
		local heightScore = math.min(heightDifference, 32) * 0.2
		local score = distanceScore + heightScore + candidate.openDirections * 0.2 + random:NextNumber()
		if score > bestFallbackScore then
			bestFallbackScore = score
			bestFallbackNode = candidate
		end
		if heightDifference >= Config.timeTrialMinimumHeightDifference and score > bestElevatedScore then
			bestElevatedScore = score
			bestElevatedNode = candidate
		end
	end
	if bestElevatedNode then return bestElevatedNode end
	if bestFallbackNode then return bestFallbackNode end
	for _, candidate in nodes do
		local delta = candidate.rootPosition - anchor.rootPosition
		local separated = true
		for _, reservedPosition in reservedPositions do
			if (candidate.rootPosition - reservedPosition).Magnitude < Config.swarmGoalSeparationDistance then
				separated = false
				break
			end
		end
		if candidate.id ~= anchor.id
			and not usedEndpointIds[candidate.id]
			and eligibleNode(candidate)
			and delta.Magnitude >= Config.timeTrialMinimumEndpointDistance
			and math.abs(delta.Y) >= Config.timeTrialMinimumHeightDifference
			and separated
		then
			return candidate
		end
	end
	for _, candidate in nodes do
		local separated = true
		for _, reservedPosition in reservedPositions do
			if (candidate.rootPosition - reservedPosition).Magnitude < Config.swarmGoalSeparationDistance then
				separated = false
				break
			end
		end
		if candidate.id ~= anchor.id
			and not usedEndpointIds[candidate.id]
			and eligibleNode(candidate)
			and (candidate.rootPosition - anchor.rootPosition).Magnitude >= Config.timeTrialMinimumEndpointDistance
			and separated
		then
			return candidate
		end
	end
	for _, candidate in nodes do
		if candidate.id ~= anchor.id
			and not usedEndpointIds[candidate.id]
			and eligibleNode(candidate)
			and (candidate.rootPosition - anchor.rootPosition).Magnitude >= Config.timeTrialMinimumEndpointDistance
		then
			return candidate
		end
	end
	for _, candidate in nodes do
		if candidate.id ~= anchor.id and eligibleNode(candidate) then return candidate end
	end
	error("[BotTimeTrials.chooseEndpoint] graph has no alternate eligible endpoint")
end

local function clearPairEvidence(state: RState)
	state.pairAttempts = 0
	state.attemptStartedAt = 0
	table.clear(state.attemptEdgeIds)
	state.attemptFailed = false
	table.clear(state.routes)
end

function BotTimeTrials.create(): RState
	return {
		enabled = false,
		explorationGoals = 0,
		startNodeId = 0,
		endNodeId = 0,
		changeStartNext = true,
		pairAttempts = 0,
		attemptStartedAt = 0,
		attemptEdgeIds = {},
		attemptFailed = false,
		routes = {},
		pairsCompleted = 0,
		usedEndpointIds = {},
	}
end

function BotTimeTrials.recordExplorationGoal(state: RState)
	if not state.enabled then state.explorationGoals += 1 end
end

function BotTimeTrials.shouldBegin(state: RState): boolean
	return not state.enabled and state.explorationGoals >= Config.timeTrialExplorationGoalsRequired
end

function BotTimeTrials.begin(
	state: RState,
	graph: RAffordanceGraph,
	position: Vector3,
	random: Random,
	reservedPositions: { Vector3 }
)
	local startNode = BotMapModel.findNearestNode(graph.mapModel, position, Config.neighborRadius)
	assert(startNode, "[BotTimeTrials.begin] explorer has no nearby start node")
	state.usedEndpointIds[startNode.id] = true
	local endNode = chooseEndpoint(graph, startNode, random, state.usedEndpointIds, reservedPositions)
	state.usedEndpointIds[endNode.id] = true
	state.enabled = true
	state.startNodeId = startNode.id
	state.endNodeId = endNode.id
	clearPairEvidence(state)
end

function BotTimeTrials.startAttempt(state: RState, agent: RAgent, graph: RAffordanceGraph, target: Part)
	local startNode = graph.mapModel.nodes[state.startNodeId]
	local endNode = graph.mapModel.nodes[state.endNodeId]
	assert(startNode and endNode, "[BotTimeTrials.startAttempt] trial endpoints are missing")
	BotAgent.resetNavigation(agent, "Starting repeatable time trial")
	agent.rootPart.AssemblyLinearVelocity = Vector3.zero
	agent.rootPart.AssemblyAngularVelocity = Vector3.zero
	agent.character:PivotTo(CFrame.new(startNode.rootPosition))
	target.Position = endNode.rootPosition
	state.attemptStartedAt = os.clock()
	table.clear(state.attemptEdgeIds)
	state.attemptFailed = false
end

function BotTimeTrials.recordEdge(state: RState, edgeId: number, succeeded: boolean)
	if not state.enabled or state.attemptStartedAt <= 0 then return end
	if succeeded then
		state.attemptEdgeIds[#state.attemptEdgeIds + 1] = edgeId
	else
		state.attemptFailed = true
	end
end

function BotTimeTrials.timedOut(state: RState, now: number): boolean
	return state.enabled
		and state.attemptStartedAt > 0
		and now - state.attemptStartedAt >= Config.timeTrialTimeoutSeconds
end

-- Returns true after a consistent route is promoted or the pair exhausts its
-- bounded attempts. The caller then changes one endpoint and starts again.
function BotTimeTrials.finishAttempt(
	state: RState,
	reached: boolean,
	graph: RAffordanceGraph,
	memory: RMemory,
	role: BotRole,
	experienceSink: WeightedExperienceSink
): boolean
	state.pairAttempts += 1
	local duration = math.max(0, os.clock() - state.attemptStartedAt)
	if reached and not state.attemptFailed and #state.attemptEdgeIds > 0 then
		local signature = routeSignature(state.attemptEdgeIds)
		local route = state.routes[signature]
		if not route then
			route = { edgeIds = table.clone(state.attemptEdgeIds), durations = {}, successes = 0 }
			state.routes[signature] = route
		end
		route.successes += 1
		route.durations[#route.durations + 1] = duration
	end

	local bestRoute: RRouteResult? = nil
	local bestMedian = math.huge
	if state.pairAttempts >= Config.timeTrialMinimumAttempts then
		for _, route in state.routes do
			local consistency = route.successes / state.pairAttempts
			if route.successes < Config.timeTrialRequiredSuccesses
				or consistency < Config.timeTrialRequiredConsistency
			then
				continue
			end
			local routeMedian = median(route.durations)
			if routeMedian < bestMedian then
				bestMedian = routeMedian
				bestRoute = route
			end
		end
	end

	if bestRoute then
		local edgeDuration = bestMedian / math.max(1, #bestRoute.edgeIds)
		for _, edgeId in bestRoute.edgeIds do
			local edge = graph.edges[edgeId]
			BotRouteMemory.recordEdge(
				memory,
				edge,
				true,
				Config.timeTrialPromotionReward,
				edgeDuration,
				nil,
				Config.timeTrialPromotionWeight
			)
			experienceSink(
				graph,
				edgeId,
				role,
				true,
					Config.timeTrialPromotionReward,
					edgeDuration,
					Config.timeTrialPromotionWeight,
					graph.mapModel.nodes[state.endNodeId].rootPosition
				)
		end
		state.pairsCompleted += 1
		return true
	end
	return state.pairAttempts >= Config.timeTrialMaximumAttempts
end

function BotTimeTrials.changeOneEndpoint(
	state: RState,
	graph: RAffordanceGraph,
	random: Random,
	reservedPositions: { Vector3 }
)
	local startNode = graph.mapModel.nodes[state.startNodeId]
	local endNode = graph.mapModel.nodes[state.endNodeId]
	assert(startNode and endNode, "[BotTimeTrials.changeOneEndpoint] trial endpoints are missing")
	if state.changeStartNext then
		state.startNodeId = chooseEndpoint(graph, endNode, random, state.usedEndpointIds, reservedPositions).id
		state.usedEndpointIds[state.startNodeId] = true
	else
		state.endNodeId = chooseEndpoint(graph, startNode, random, state.usedEndpointIds, reservedPositions).id
		state.usedEndpointIds[state.endNodeId] = true
	end
	state.changeStartNext = not state.changeStartNext
	clearPairEvidence(state)
end

return table.freeze(BotTimeTrials)
