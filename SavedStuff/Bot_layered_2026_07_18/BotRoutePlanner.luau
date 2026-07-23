--!strict
--[[
    BotRoutePlanner (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Bounded weighted-A* over executable affordances. A binary heap avoids the
    old linear open-list scan, and step() observes a strict wall-clock budget.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotMapModel = require(ReplicatedStorage.Modules.Bot.BotMapModel)
local BotPolicy = require(ReplicatedStorage.Modules.Bot.BotPolicy)
local BotRouteAdvantage = require(ReplicatedStorage.Modules.Bot.BotRouteAdvantage)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole
type RAffordanceGraph = Types.RAffordanceGraph
type RPlan = Types.RPlan
type RSurfaceNode = Types.RSurfaceNode
type RMemory = BotRouteMemory.RMemory

export type RPlannerJob = Types.RPlannerJob & {
	graph: RAffordanceGraph,
	memory: RMemory,
	opponentPosition: Vector3?,
	opponentVelocity: Vector3?,
	blockedEdgeUntil: { [number]: number },
	learningMode: boolean,
	arrivalTimes: { [number]: number },
	cameFromAdvantage: { [number]: BotRouteAdvantage.RResult },
	bestNodeId: number,
	bestHeuristic: number,
	bestReachableNodeId: number,
	bestReachableHeuristic: number,
	startHeuristic: number,
	startDirection: Vector3,
	startedAt: number,
	previewPlan: RPlan?,
	previewIssued: boolean,
}

local BotRoutePlanner = {}
local nextJobId = 0
local nextPlanId = 0

local function heapPush(heap: { { nodeId: number, score: number } }, item: { nodeId: number, score: number })
	heap[#heap + 1] = item
	local index = #heap
	while index > 1 do
		local parent = math.floor(index / 2)
		if heap[parent].score <= item.score then break end
		heap[index] = heap[parent]
		index = parent
	end
	heap[index] = item
end

local function heapPop(heap: { { nodeId: number, score: number } }): { nodeId: number, score: number }?
	local first = heap[1]
	if not first then return nil end
	local last = table.remove(heap)
	if #heap == 0 or not last then return first end

	local index = 1
	while true do
		local left = index * 2
		if left > #heap then break end
		local right = left + 1
		local child = if right <= #heap and heap[right].score < heap[left].score then right else left
		if heap[child].score >= last.score then break end
		heap[index] = heap[child]
		index = child
	end
	heap[index] = last
	return first
end

local function heuristic(graph: RAffordanceGraph, nodeId: number, goalNodeId: number): number
	local from = graph.mapModel.nodes[nodeId].rootPosition
	local goal = graph.mapModel.nodes[goalNodeId].rootPosition
	local delta = goal - from
	local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local verticalCost = if delta.Y >= 0
		then delta.Y / Config.plannerVerticalAscentHeuristicSpeed
		else math.abs(delta.Y) / Config.plannerVerticalDescentHeuristicSpeed
	return flatDistance / Config.botWalkSpeed + verticalCost
end

local function goalRequiresAnotherLayer(job: RPlannerJob): boolean
	local start = job.graph.mapModel.nodes[job.startNodeId]
	local goal = job.graph.mapModel.nodes[job.goalNodeId]
	return math.abs(goal.rootPosition.Y - start.rootPosition.Y) > Config.plannerGoalLayerTolerance
end

local function bestCandidateReachedGoalLayer(job: RPlannerJob): boolean
	local candidate = job.graph.mapModel.nodes[job.bestNodeId]
	local goal = job.graph.mapModel.nodes[job.goalNodeId]
	return math.abs(goal.rootPosition.Y - candidate.rootPosition.Y) <= Config.plannerGoalLayerTolerance
end

-- The geometrically nearest node may be across a thin wall. Starting A* from
-- it produces a valid graph route whose first transition the bot cannot enter.
local function findReachableStartNode(graph: RAffordanceGraph, position: Vector3): RSurfaceNode?
	local candidates = BotMapModel.findNodesInRadius(
		graph.mapModel,
		position,
		Config.plannerStartReachRadius,
		Config.plannerStartCandidateLimit
	)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { graph.mapModel.mapRoot }
	params.IgnoreWater = true
	local bestNode: RSurfaceNode? = nil
	local bestDistance = math.huge
	table.sort(candidates, function(a, b)
		local aDelta = a.rootPosition - position
		local bDelta = b.rootPosition - position
		return aDelta:Dot(aDelta) < bDelta:Dot(bDelta)
	end)
	for index, candidate in candidates do
		if index > Config.plannerStartVisibilityProbeLimit then break end
		local delta = candidate.rootPosition - position
		if math.abs(delta.Y) > Config.maxLearnableWalkStepHeight then continue end
		if Workspace:Raycast(position + Vector3.yAxis * 0.4, delta, params) then continue end
		if Workspace:Raycast(position + Vector3.yAxis * 2.3, delta, params) then continue end
		local distance = delta.Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestNode = candidate
		end
	end
	return bestNode
end

local function edgeTraversalCost(
	job: RPlannerJob,
	edgeId: number,
	arrivalTime: number
): (number, BotRouteAdvantage.RResult)
	local edge = job.graph.edges[edgeId]
	local destination = job.graph.mapModel.nodes[edge.to]
	local source = job.graph.mapModel.nodes[edge.from]
	local goal = job.graph.mapModel.nodes[job.goalNodeId]
	local successProbability = BotRouteMemory.getSuccessProbability(job.memory, edge)
	local expectedCompletionTime = edge.expectedTime / math.max(0.15, successProbability)
	local playerTime, playerEvidence = BotRouteMemory.getPlayerEdgeTransitionTime(
		job.memory,
		edge,
		job.graph.mapModel.nodes[edge.from].rootPosition,
		job.graph.mapModel.nodes[edge.to].rootPosition
	)
	if playerTime
		and playerEvidence >= Config.playerRoutePlannerMinimumEvidence
		and successProbability >= Config.playerRoutePlannerMinimumBotSuccess
		and playerTime < expectedCompletionTime * Config.playerRoutePlannerMinimumTimeRatio
	then
		local evidenceConfidence = math.clamp(
			(playerEvidence - Config.playerRoutePlannerMinimumEvidence + 1)
				/ Config.playerRoutePlannerFullConfidenceEvidence,
			0,
			1
		)
		local confidence = evidenceConfidence * successProbability
		local executableTime = math.max(
			playerTime,
			edge.expectedTime * Config.playerRoutePlannerMinimumExecutionRatio
		)
		expectedCompletionTime += (executableTime - expectedCompletionTime) * confidence
	end
	local taughtTime, taughtEvidence = BotRouteMemory.getTaughtTransition(
		job.memory,
		edge,
		source.rootPosition,
		destination.rootPosition
	)
	local sourceGoalDistance = (goal.rootPosition - source.rootPosition).Magnitude
	local destinationGoalDistance = (goal.rootPosition - destination.rootPosition).Magnitude
	local goalProgress = sourceGoalDistance - destinationGoalDistance
	local usefulClimb = goal.rootPosition.Y > source.rootPosition.Y + Config.directChaseVerticalTolerance
		and destination.rootPosition.Y > source.rootPosition.Y + Config.defaultWalkStepHeight
	local taughtApplicable = taughtEvidence >= Config.taughtRouteMinimumEvidence
		and (goalProgress >= -Config.taughtRouteMaximumRegression or usefulClimb)
	local taughtCostBonus = 0
	if taughtApplicable then
		if taughtTime then expectedCompletionTime = math.min(expectedCompletionTime, taughtTime) end
		taughtCostBonus = math.min(
			Config.taughtRouteMaximumCostBonus,
			Config.taughtRouteBaseCostBonus
				+ taughtEvidence * Config.taughtRouteEvidenceCostBonus
		)
	end
	local complexityCosts = Config.actionComplexityCosts :: { [string]: number }
	local cost = expectedCompletionTime
		+ (1 - successProbability) * Config.plannerFailureRiskWeight
		+ (complexityCosts[edge.action] or 0)
		+ BotRouteMemory.getCostBias(job.memory, edge)
		- taughtCostBonus
	if edge.from == job.startNodeId and job.startDirection.Magnitude > 0.01 then
		local delta = destination.rootPosition - source.rootPosition
		local edgeDirection = Vector3.new(delta.X, 0, delta.Z)
		if edgeDirection.Magnitude > 0.01 then
			local headingDot = edgeDirection.Unit:Dot(job.startDirection)
			cost += (1 - headingDot) * Config.plannerInitialTurnCostWeight
			if job.role == "Runner" and headingDot < 0 then
				local opponentDistance = if job.opponentPosition
					then (source.rootPosition - job.opponentPosition).Magnitude
					else Config.runnerThreatRadius * 2
				local pressure = 1 - math.clamp(
					(opponentDistance - Config.tagRange)
						/ math.max(1, Config.runnerThreatRadius - Config.tagRange),
					0,
					1
				)
				cost += -headingDot * Config.runnerInitialBacktrackCost * (0.25 + pressure * 0.75)
			end
		end
	end
	if job.learningMode then
		local sourceDistance = (goal.rootPosition - source.rootPosition).Magnitude
		local destinationDistance = (goal.rootPosition - destination.rootPosition).Magnitude
		local progress = sourceDistance - destinationDistance
		if progress >= -Config.learningRouteMaxRegression then
			local experience = BotRouteMemory.getExperienceCount(job.memory, edge)
			cost -= Config.learningRouteNoveltyCostBonus / math.sqrt(experience + 1)
			local variation = ((edge.id * 37 + job.id * 17) % 101) / 100 - 0.5
			cost += variation * Config.learningRouteVariation
		end
		if progress < 0 then cost += math.abs(progress) * 0.025 end
		if edge.action == "Walk" then
			cost += Config.learningWalkRouteCostPenalty
		else
			cost -= Config.learningTechRouteCostBonus
		end
	end
	local advantage = BotRouteAdvantage.evaluate(
		job.role,
		source.rootPosition,
		destination.rootPosition,
		edge.expectedTime,
		arrivalTime,
		job.opponentPosition,
		job.opponentVelocity
	)
	cost += advantage.costAdjustment
	if edge.action ~= "Walk" then
		local policyScore = BotPolicy.scoreEdge(
			job.role,
			source,
			destination,
			edge,
			goal,
			0,
			BotRouteMemory.getAreaScore(job.memory, destination.rootPosition, job.role),
			Config.botWalkSpeed
		)
		cost -= policyScore * Config.policyCostWeight
	end

	return math.max(0.02, cost), advantage
end

local function reconstruct(job: RPlannerJob, endNodeId: number, isPartial: boolean): RPlan
	local reverseNodeIds = { endNodeId }
	local reverseEdgeIds = {}
	local current = endNodeId
	while current ~= job.startNodeId do
		local edgeId = job.cameFromEdge[current]
		local previous = job.cameFromNode[current]
		assert(edgeId and previous, "[BotRoutePlanner.reconstruct] incomplete predecessor chain")
		reverseEdgeIds[#reverseEdgeIds + 1] = edgeId
		reverseNodeIds[#reverseNodeIds + 1] = previous
		current = previous
	end
	local nodeIds = table.create(#reverseNodeIds)
	local edgeIds = table.create(#reverseEdgeIds)
	for index = #reverseNodeIds, 1, -1 do nodeIds[#nodeIds + 1] = reverseNodeIds[index] end
	for index = #reverseEdgeIds, 1, -1 do edgeIds[#edgeIds + 1] = reverseEdgeIds[index] end

	local expectedTime = 0
	local successProbability = 1
	local opponentAdvantage = 0
	local minimumOpponentClearance = math.huge
	local interceptionMargin = math.huge
	local edgeAdvantages = {}
	local edgeClearances = {}
	local edgeInterceptionMargins = {}
	for index, edgeId in edgeIds do
		local edge = job.graph.edges[edgeId]
		expectedTime += edge.expectedTime
		successProbability *= BotRouteMemory.getSuccessProbability(job.memory, edge)
		local metric = job.cameFromAdvantage[edge.to]
		if metric then
			opponentAdvantage += metric.advantage
			minimumOpponentClearance = math.min(minimumOpponentClearance, metric.clearance)
			interceptionMargin = math.min(interceptionMargin, metric.interceptionMargin)
			edgeAdvantages[index] = metric.advantage
			edgeClearances[index] = metric.clearance
			edgeInterceptionMargins[index] = metric.interceptionMargin
		end
	end

	nextPlanId += 1
	return {
		id = nextPlanId,
		goalPosition = job.goalPosition,
		goalNodeId = endNodeId,
		nodeIds = nodeIds,
		edgeIds = edgeIds,
		totalCost = job.gScore[endNodeId] or expectedTime,
		expectedTime = expectedTime,
		successProbability = successProbability,
		opponentAdvantage = opponentAdvantage,
		minimumOpponentClearance = minimumOpponentClearance,
		interceptionMargin = interceptionMargin,
		edgeAdvantages = edgeAdvantages,
		edgeClearances = edgeClearances,
		edgeInterceptionMargins = edgeInterceptionMargins,
		isPartial = isPartial,
		createdAt = os.clock(),
	}
end

function BotRoutePlanner.createJob(
	graph: RAffordanceGraph,
	memory: RMemory,
	startPosition: Vector3,
	goalPosition: Vector3,
	role: BotRole,
	startDirection: Vector3,
	opponentPosition: Vector3?,
	opponentVelocity: Vector3?,
	blockedEdgeUntil: { [number]: number },
	learningMode: boolean
): RPlannerJob?
	assert(graph.ready, "[BotRoutePlanner.createJob] affordance graph must be ready")
	local startNode = findReachableStartNode(graph, startPosition)
		or BotMapModel.findNearestNode(graph.mapModel, startPosition, Config.neighborRadius)
	local goalSearchRadius = Config.neighborRadius * 2
	local goalNode = BotMapModel.findNearestNodeOnLayer(
		graph.mapModel,
		goalPosition,
		goalSearchRadius,
		Config.plannerGoalLayerTolerance
	) or BotMapModel.findNearestNodeOnLayer(
		graph.mapModel,
		goalPosition,
		Config.plannerGoalLayerSearchRadius,
		Config.plannerGoalLayerTolerance
	) or BotMapModel.findNearestNode(graph.mapModel, goalPosition, goalSearchRadius)
	if not startNode or not goalNode then return nil end

	nextJobId += 1
	local startHeuristic = heuristic(graph, startNode.id, goalNode.id)
	local job: RPlannerJob = {
		id = nextJobId,
		role = role,
		startNodeId = startNode.id,
		goalNodeId = goalNode.id,
		goalPosition = goalPosition,
		openHeap = {},
		openBest = {},
		cameFromNode = {},
		cameFromEdge = {},
		gScore = { [startNode.id] = 0 },
		closed = {},
		activeNodeId = nil,
		activeEdgeCursor = 1,
		expansions = 0,
		done = false,
		failed = false,
		cancelled = false,
		plan = nil,
		graph = graph,
		memory = memory,
		opponentPosition = opponentPosition,
		opponentVelocity = opponentVelocity,
		blockedEdgeUntil = blockedEdgeUntil,
		learningMode = learningMode,
		arrivalTimes = { [startNode.id] = 0 },
		cameFromAdvantage = {},
		bestNodeId = startNode.id,
		bestHeuristic = startHeuristic,
		bestReachableNodeId = startNode.id,
		bestReachableHeuristic = math.huge,
		startHeuristic = startHeuristic,
		startDirection = if startDirection.Magnitude > 0.01
			then Vector3.new(startDirection.X, 0, startDirection.Z).Unit
			else Vector3.zero,
		startedAt = os.clock(),
		previewPlan = nil,
		previewIssued = false,
	}
	local initialScore = startHeuristic
	job.openBest[startNode.id] = initialScore
	heapPush(job.openHeap, { nodeId = startNode.id, score = initialScore })
	return job
end

function BotRoutePlanner.cancel(job: RPlannerJob?)
	if job then job.cancelled = true end
end

--[=[
	@client

	takePreview
	===========

	Transfers ownership of the one-shot early route prefix to the agent while
	the same frame-budgeted search continues toward its complete goal.
]=]
function BotRoutePlanner.takePreview(job: RPlannerJob): RPlan?
	local preview = job.previewPlan
	job.previewPlan = nil
	return preview
end

local function finishBestReachable(job: RPlannerJob): boolean
	local gained = job.startHeuristic - job.bestHeuristic
	local endNodeId = if job.bestNodeId ~= job.startNodeId
		and gained >= Config.plannerPartialMinimumHeuristicGain
		then job.bestNodeId
		else job.bestReachableNodeId
	if endNodeId ~= job.startNodeId then
		job.plan = reconstruct(job, endNodeId, true)
		job.failed = false
	else
		job.failed = true
	end
	job.done = true
	return true
end

function BotRoutePlanner.step(job: RPlannerJob, budgetSeconds: number?): boolean
	if job.done or job.cancelled then return true end
	local startedAt = os.clock()
	local budget = budgetSeconds or Config.plannerBudgetSeconds

	while os.clock() - startedAt < budget do
		if not job.previewIssued
			and job.expansions >= Config.plannerPreviewMinimumExpansions
			and os.clock() - job.startedAt >= Config.plannerPreviewSeconds
			and job.bestNodeId ~= job.startNodeId
			and job.startHeuristic - job.bestHeuristic >= Config.plannerPartialMinimumHeuristicGain
		then
			job.previewPlan = reconstruct(job, job.bestNodeId, true)
			job.previewIssued = true
		end
		if job.expansions >= Config.plannerDeadlineMinimumExpansions
			and os.clock() - job.startedAt >= Config.plannerDecisionDeadlineSeconds
			and job.bestReachableNodeId ~= job.startNodeId
			and (not goalRequiresAnotherLayer(job) or bestCandidateReachedGoalLayer(job))
		then
			return finishBestReachable(job)
		end

		local activeNodeId = job.activeNodeId
		if activeNodeId then
			local node = job.graph.mapModel.nodes[activeNodeId]
			local edgeId = node.edges[job.activeEdgeCursor]
			if not edgeId then
				job.activeNodeId = nil
				job.activeEdgeCursor = 1
				continue
			end
			job.activeEdgeCursor += 1

			local blockedUntil = job.blockedEdgeUntil[edgeId]
			if blockedUntil then
				if os.clock() < blockedUntil then continue end
				job.blockedEdgeUntil[edgeId] = nil
			end
			local edge = job.graph.edges[edgeId]
			if edge.action == "RollBoost" then
				local previousEdgeId = job.cameFromEdge[activeNodeId]
				local previousEdge = if previousEdgeId then job.graph.edges[previousEdgeId] else nil
				if not previousEdge or previousEdge.action ~= "Drop" then continue end
			end
			if job.closed[edge.to] then continue end
			local currentArrivalTime = job.arrivalTimes[activeNodeId] or 0
			local traversalCost, advantage = edgeTraversalCost(job, edgeId, currentArrivalTime)
			local tentative = (job.gScore[activeNodeId] or math.huge) + traversalCost
			if tentative >= (job.gScore[edge.to] or math.huge) then continue end

			job.cameFromNode[edge.to] = activeNodeId
			job.cameFromEdge[edge.to] = edgeId
			job.cameFromAdvantage[edge.to] = advantage
			job.gScore[edge.to] = tentative
			job.arrivalTimes[edge.to] = currentArrivalTime + edge.expectedTime
			local score = tentative + heuristic(job.graph, edge.to, job.goalNodeId) * Config.plannerHeuristicWeight
			job.openBest[edge.to] = score
			heapPush(job.openHeap, { nodeId = edge.to, score = score })
			continue
		end

		if job.expansions >= Config.plannerMaxExpansions then
			return finishBestReachable(job)
		end

		local entry = heapPop(job.openHeap)
		if not entry then
			return finishBestReachable(job)
		end
		if job.closed[entry.nodeId] then continue end
		if entry.score > (job.openBest[entry.nodeId] or math.huge) + 0.0001 then continue end

		local nodeId = entry.nodeId
		local remainingHeuristic = heuristic(job.graph, nodeId, job.goalNodeId)
		if nodeId ~= job.startNodeId and remainingHeuristic < job.bestReachableHeuristic then
			job.bestReachableHeuristic = remainingHeuristic
			job.bestReachableNodeId = nodeId
		end
		if remainingHeuristic < job.bestHeuristic then
			job.bestHeuristic = remainingHeuristic
			job.bestNodeId = nodeId
		end
		if nodeId == job.goalNodeId then
			job.plan = reconstruct(job, job.goalNodeId, false)
			job.done = true
			return true
		end

		job.closed[nodeId] = true
		job.expansions += 1
		job.activeNodeId = nodeId
		job.activeEdgeCursor = 1
	end

	return false
end

return table.freeze(BotRoutePlanner)
