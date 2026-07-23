--!strict
--[[
    BotSearch (Shared)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Shared frame-budgeted A* over executable affordances. Client agents and
    server-owned route-lab markers use the same search and route costs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotKnowledge = require(ReplicatedStorage.Modules.Bot.BotKnowledge)
local BotWorld = require(ReplicatedStorage.Modules.Bot.BotWorld)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type BotRole = Types.BotRole
type RPlan = Types.RPlan
type RWorld = Types.RWorld
type RMemory = BotKnowledge.RMemory

export type RJob = {
	id: number,
	world: RWorld,
	memory: RMemory,
	role: BotRole,
	startId: number,
	goalId: number,
	goal: Vector3,
	opponentPosition: Vector3?,
	opponentVelocity: Vector3,
	startDirection: Vector3,
	open: { { id: number, score: number } },
	bestOpen: { [number]: number },
	cameNode: { [number]: number },
	cameEdge: { [number]: number },
	cost: { [number]: number },
	arrival: { [number]: number },
	closed: { [number]: boolean },
	expansions: number,
	activeNode: number?,
	activeEdge: number,
	bestId: number,
	bestHeuristic: number,
	startedAt: number,
	done: boolean,
	failed: boolean,
	plan: RPlan?,
	excludedEdges: { [number]: boolean },
	maximumSearchSeconds: number,
	timeOnly: boolean,
	heuristicWeight: number,
}

export type CreateParams = {
	excludedEdges: { [number]: boolean }?,
	maximumSearchSeconds: number?,
	timeOnly: boolean?,
	heuristicWeight: number?,
}

local BotSearch = {}
local nextJobId = 0
local nextPlanId = 0

local function push(heap: { { id: number, score: number } }, item: { id: number, score: number })
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

local function pop(heap: { { id: number, score: number } }): { id: number, score: number }?
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

local function heuristic(world: RWorld, fromId: number, goalId: number): number
	local delta = world.nodes[goalId].position - world.nodes[fromId].position
	local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local vertical = if delta.Y > 0 then delta.Y / 11 else math.abs(delta.Y) / 28
	return flat / Config.walkSpeed + vertical
end

local function reachableStart(world: RWorld, position: Vector3): Types.RNode?
	local best: Types.RNode? = nil
	local bestDistance = math.huge
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world.map }
	for _, node in BotWorld.findNearby(world, position, Config.climbNeighborRadius * 2) do
		local delta = node.position - position
		if math.abs(delta.Y) > Config.plannerGoalLayerTolerance then continue end
		if Workspace:Raycast(position + Vector3.yAxis * 0.5, delta, params)
			or Workspace:Raycast(position + Vector3.yAxis * 2.2, delta, params)
		then
			continue
		end
		if delta.Magnitude < bestDistance then
			best = node
			bestDistance = delta.Magnitude
		end
	end
	return best
end

local function segmentDistance(point: Vector3, fromPosition: Vector3, toPosition: Vector3): number
	local segment = toPosition - fromPosition
	local lengthSquared = segment:Dot(segment)
	if lengthSquared < 0.01 then return (point - fromPosition).Magnitude end
	local alpha = math.clamp((point - fromPosition):Dot(segment) / lengthSquared, 0, 1)
	return (point - fromPosition - segment * alpha).Magnitude
end

local function runnerCost(job: RJob, edgeId: number, arrival: number): number
	if job.role ~= "Runner" or not job.opponentPosition then return 0 end
	local edge = job.world.edges[edgeId]
	local source = job.world.nodes[edge.from]
	local destination = job.world.nodes[edge.to]
	local predicted = job.opponentPosition + job.opponentVelocity * math.min(arrival + edge.time * 0.5, 2.5)
	local clearance = segmentDistance(predicted, source.position, destination.position)
	local exits = math.max(0, destination.exitCount - 1)
	local cost = 0
	if destination.barrierAdjacent then cost += Config.runnerBarrierPenalty end
	if exits == 0 then cost += Config.runnerDeadEndPenalty end
	if exits == 1 then cost += Config.runnerCorridorPenalty end
	if clearance <= Config.tagRange + 1 then
		cost += Config.runnerInterceptPenalty
	elseif clearance < Config.runnerSafeClearance then
		cost += (Config.runnerSafeClearance - clearance) * 1.2
	end
	local startDistance = (source.position - job.opponentPosition).Magnitude
	local endDistance = (destination.position - predicted).Magnitude
	cost -= math.clamp(endDistance - startDistance, -12, 12) * 0.08
	return cost
end

-- Consecutive graph cells are useful to A*, but making the motor visit every
-- cell causes visible hesitation. Keep turns and authored/parkour transitions
-- while reducing straight walk runs to stable steering waypoints.
local function compactPath(world: RWorld, nodes: { number }, edges: { number }): ({ number }, { number })
	if #edges < 2 then return nodes, edges end
	local compactNodes = { nodes[1] }
	local compactEdges = {}
	local cursor = 1
	while cursor <= #edges do
		local edge = world.edges[edges[cursor]]
		if edge.action ~= "Walk" or edge.taught then
			compactEdges[#compactEdges + 1] = edges[cursor]
			compactNodes[#compactNodes + 1] = nodes[cursor + 1]
			cursor += 1
			continue
		end

		local selected = cursor
		local sourcePosition = world.nodes[nodes[cursor]].position
		local heading = Vector3.new(edge.direction.X, 0, edge.direction.Z)
		if heading.Magnitude > 0.01 then heading = heading.Unit end
		while selected < #edges do
			local nextEdge = world.edges[edges[selected + 1]]
			if nextEdge.action ~= "Walk" or nextEdge.taught then break end
			local destination = world.nodes[nodes[selected + 2]].position
			local flatDelta = Vector3.new(destination.X - sourcePosition.X, 0, destination.Z - sourcePosition.Z)
			if flatDelta.Magnitude > Config.plannerWalkSimplifyMaximumDistance then break end
			local lateralOffset = (flatDelta - heading * flatDelta:Dot(heading)).Magnitude
			if lateralOffset > Config.plannerWalkSimplifyLateralTolerance then break end
			local nextHeading = Vector3.new(nextEdge.direction.X, 0, nextEdge.direction.Z)
			if heading.Magnitude < 0.01
				or nextHeading.Magnitude < 0.01
				or heading:Dot(nextHeading.Unit) < Config.plannerWalkSimplifyDirectionDot
			then
				break
			end
			selected += 1
		end

		compactEdges[#compactEdges + 1] = edges[selected]
		compactNodes[#compactNodes + 1] = nodes[selected + 1]
		cursor = selected + 1
	end
	return compactNodes, compactEdges
end

local function reconstruct(job: RJob, endId: number): RPlan
	local reverseNodes = { endId }
	local reverseEdges = {}
	local current = endId
	while current ~= job.startId do
		local previous = job.cameNode[current]
		local edge = job.cameEdge[current]
		assert(previous and edge, "[BotSearch.reconstruct] incomplete path")
		reverseNodes[#reverseNodes + 1] = previous
		reverseEdges[#reverseEdges + 1] = edge
		current = previous
	end
	local nodes = {}
	local edges = {}
	for index = #reverseNodes, 1, -1 do nodes[#nodes + 1] = reverseNodes[index] end
	for index = #reverseEdges, 1, -1 do edges[#edges + 1] = reverseEdges[index] end
	local time = 0
	local success = 1
	for _, edgeId in edges do
		local edge = job.world.edges[edgeId]
		time += edge.time
		success *= 1 - edge.risk
	end
	nodes, edges = compactPath(job.world, nodes, edges)
	nextPlanId += 1
	return { id = nextPlanId, goal = job.goal, nodes = nodes, edges = edges, cost = job.cost[endId] or time, time = time, success = success, createdAt = os.clock() }
end

function BotSearch.create(
	world: RWorld,
	memory: RMemory,
	startPosition: Vector3,
	goalPosition: Vector3,
	role: BotRole,
	opponentPosition: Vector3?,
	opponentVelocity: Vector3?,
	startDirection: Vector3?,
	searchParams: CreateParams?
): RJob?
	assert(
		startDirection == nil or typeof(startDirection) == "Vector3",
		"[BotSearch.create] startDirection must be a Vector3 or nil"
	)
	if not world.graphReady then return nil end
	local start = reachableStart(world, startPosition)
		or BotWorld.findNearest(world, startPosition, Config.climbNeighborRadius * 2)
	local goal = BotWorld.findNearest(world, goalPosition, Config.climbNeighborRadius * 4)
	if not start or not goal then return nil end
	nextJobId += 1
	local initial = heuristic(world, start.id, goal.id)
	local job: RJob = {
		id = nextJobId,
		world = world,
		memory = memory,
		role = role,
		startId = start.id,
		goalId = goal.id,
		goal = goalPosition,
		opponentPosition = opponentPosition,
		opponentVelocity = opponentVelocity or Vector3.zero,
		startDirection = if startDirection and startDirection.Magnitude > 0.1
			then Vector3.new(startDirection.X, 0, startDirection.Z).Unit
			else Vector3.zero,
		open = {},
		bestOpen = { [start.id] = initial },
		cameNode = {},
		cameEdge = {},
		cost = { [start.id] = 0 },
		arrival = { [start.id] = 0 },
		closed = {},
		expansions = 0,
		activeNode = nil,
		activeEdge = 1,
		bestId = start.id,
		bestHeuristic = initial,
		startedAt = os.clock(),
		done = false,
		failed = false,
		plan = nil,
		excludedEdges = if searchParams and searchParams.excludedEdges
			then searchParams.excludedEdges
			else {},
		maximumSearchSeconds = if searchParams and searchParams.maximumSearchSeconds
			then searchParams.maximumSearchSeconds
			else Config.plannerMaximumSearchSeconds,
		timeOnly = searchParams ~= nil and searchParams.timeOnly == true,
		heuristicWeight = if searchParams and searchParams.heuristicWeight
			then searchParams.heuristicWeight
			else Config.plannerHeuristicWeight,
	}
	push(job.open, { id = start.id, score = initial })
	return job
end

function BotSearch.step(job: RJob, budget: number?): boolean
	if job.done then return true end
	local started = os.clock()
	while os.clock() - started < (budget or Config.plannerBudget) do
		if job.expansions >= Config.plannerMinimumPartialExpansions
			and os.clock() - job.startedAt >= job.maximumSearchSeconds
			and job.bestId ~= job.startId
		then
			job.plan = reconstruct(job, job.bestId)
			job.done = true
			return true
		end
		if job.activeNode then
			local source = job.world.nodes[job.activeNode]
			local edgeId = source.edges[job.activeEdge]
			if not edgeId then
				job.activeNode = nil
				job.activeEdge = 1
				continue
			end
			job.activeEdge += 1
			if job.excludedEdges[edgeId] then continue end
			local edge = job.world.edges[edgeId]
			if edge.action == "RollBoost" then
				local previousEdgeId = job.cameEdge[source.id]
				local previousEdge = if previousEdgeId then job.world.edges[previousEdgeId] else nil
				if not previousEdge or previousEdge.action ~= "Drop" then continue end
			end
			if job.closed[edge.to] then continue end
			local arrival = (job.arrival[source.id] or 0) + edge.time
			local complexity = (Config.actionCost :: { [string]: number })[edge.action] or 0
			local headingCost = 0
			if source.id == job.startId and job.startDirection.Magnitude > 0.1 then
				local dot = edge.direction:Dot(job.startDirection)
				headingCost = (1 - dot) * 0.3
				if job.role == "Runner" and dot < 0 then headingCost += -dot * Config.runnerReversalPenalty end
			end
			local nextCost = (job.cost[source.id] or math.huge) + edge.time
			if not job.timeOnly then
				nextCost += edge.risk * 0.8
					+ complexity
					+ headingCost
					+ BotKnowledge.cost(job.memory, edge)
					+ runnerCost(job, edgeId, arrival)
			end
			if nextCost >= (job.cost[edge.to] or math.huge) then continue end
			job.cost[edge.to] = nextCost
			job.arrival[edge.to] = arrival
			job.cameNode[edge.to] = source.id
			job.cameEdge[edge.to] = edgeId
			local score = nextCost + heuristic(job.world, edge.to, job.goalId) * job.heuristicWeight
			job.bestOpen[edge.to] = score
			push(job.open, { id = edge.to, score = score })
			continue
		end

		if job.expansions >= Config.plannerMaximumExpansions then
			job.done = true
			job.failed = job.bestId == job.startId
			if not job.failed then job.plan = reconstruct(job, job.bestId) end
			return true
		end
		local entry = pop(job.open)
		if not entry then
			job.done = true
			job.failed = job.bestId == job.startId
			if not job.failed then job.plan = reconstruct(job, job.bestId) end
			return true
		end
		if job.closed[entry.id] or entry.score > (job.bestOpen[entry.id] or math.huge) + 0.001 then continue end
		if entry.id == job.goalId then
			job.plan = reconstruct(job, entry.id)
			job.done = true
			return true
		end
		local remaining = heuristic(job.world, entry.id, job.goalId)
		if remaining < job.bestHeuristic then
			job.bestHeuristic = remaining
			job.bestId = entry.id
		end
		job.closed[entry.id] = true
		job.expansions += 1
		job.activeNode = entry.id
		job.activeEdge = 1
	end
	return false
end

return table.freeze(BotSearch)
