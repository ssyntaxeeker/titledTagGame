--!strict
--[[
    BotRunnerBrain (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Incremental reachable-route rollout for runner gamesense. It scores whole
    graph corridors instead of selecting globally distant Euclidean points.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotWorld = require(ReplicatedStorage.Modules.Bot.BotWorld)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type RWorld = Types.RWorld

type REntry = {
	nodeId: number,
	previousId: number,
	depth: number,
	time: number,
	minimumClearance: number,
	firstDirection: Vector3,
}

export type RState = {
	goal: Vector3?,
	goalNodeId: number?,
	goalScore: number,
	committedAt: number,
	lapSign: number,
	recentGoals: { number },
	queue: { REntry },
	queueCursor: number,
	visited: { [number]: number },
	bestNodeId: number?,
	bestScore: number,
	scanStart: Vector3,
	scanOpponent: Vector3,
	scanning: boolean,
	processedTransitions: number,
}

local BotRunnerBrain = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function segmentDistance(point: Vector3, fromPosition: Vector3, toPosition: Vector3): number
	local segment = toPosition - fromPosition
	local lengthSquared = segment:Dot(segment)
	if lengthSquared < 0.01 then return (point - fromPosition).Magnitude end
	local alpha = math.clamp((point - fromPosition):Dot(segment) / lengthSquared, 0, 1)
	return (point - fromPosition - segment * alpha).Magnitude
end

function BotRunnerBrain.create(): RState
	return {
		goal = nil,
		goalNodeId = nil,
		goalScore = -math.huge,
		committedAt = 0,
		lapSign = if math.random() < 0.5 then -1 else 1,
		recentGoals = {},
		queue = {},
		queueCursor = 1,
		visited = {},
		bestNodeId = nil,
		bestScore = -math.huge,
		scanStart = Vector3.zero,
		scanOpponent = Vector3.zero,
		scanning = false,
		processedTransitions = 0,
	}
end

function BotRunnerBrain.invalidate(state: RState)
	state.goal = nil
	state.goalNodeId = nil
	state.goalScore = -math.huge
	state.scanning = false
	table.clear(state.queue)
	table.clear(state.visited)
end

local function beginScan(state: RState, world: RWorld, botPosition: Vector3, opponentPosition: Vector3)
	local start = BotWorld.findNearest(world, botPosition, Config.climbNeighborRadius * 2)
	if not start then return end
	table.clear(state.queue)
	table.clear(state.visited)
	state.queue[1] = {
		nodeId = start.id,
		previousId = 0,
		depth = 0,
		time = 0,
		minimumClearance = (flat(start.position) - flat(opponentPosition)).Magnitude,
		firstDirection = Vector3.zero,
	}
	state.queueCursor = 1
	state.visited[start.id] = 0
	state.bestNodeId = nil
	state.bestScore = -math.huge
	state.scanStart = botPosition
	state.scanOpponent = opponentPosition
	state.scanning = true
	state.processedTransitions = 0
end

local function candidateScore(
	state: RState,
	world: RWorld,
	entry: REntry,
	botPosition: Vector3,
	botVelocity: Vector3,
	opponentPosition: Vector3,
	opponentVelocity: Vector3
): number
	local node = world.nodes[entry.nodeId]
	local predictedThreat = opponentPosition + flat(opponentVelocity) * math.min(entry.time, 2.5)
	local separation = (flat(node.position) - flat(predictedThreat)).Magnitude
	local travelDistance = (flat(node.position) - flat(botPosition)).Magnitude
	local exits = math.max(0, node.exitCount - 1)
	local away = flat(botPosition - opponentPosition)
	local route = flat(node.position - botPosition)
	local tangentScore = 0
	if away.Magnitude > 0.1 and route.Magnitude > 0.1 then
		local tangent = Vector3.new(-away.Unit.Z, 0, away.Unit.X) * state.lapSign
		tangentScore = route.Unit:Dot(tangent)
	end
	local heading = flat(botVelocity)
	local reversalPenalty = if heading.Magnitude > 4 and entry.firstDirection.Magnitude > 0
		then math.max(0, -heading.Unit:Dot(entry.firstDirection)) * Config.runnerReversalPenalty
		else 0
	local recentPenalty = if table.find(state.recentGoals, node.id) then Config.runnerRecentGoalPenalty else 0
	local topologyPenalty = 0
	if node.barrierAdjacent then topologyPenalty += Config.runnerBarrierPenalty end
	if exits == 0 then topologyPenalty += Config.runnerDeadEndPenalty end
	if exits == 1 then topologyPenalty += Config.runnerCorridorPenalty end
	if entry.minimumClearance <= Config.tagRange + 1 then topologyPenalty += Config.runnerInterceptPenalty end
	local preferredDistanceScore = -math.abs(travelDistance - Config.runnerGoalPreferredDistance) * 0.08
	return separation * Config.runnerDistanceWeight
		+ exits * Config.runnerBranchWeight
		+ (if node.hasVerticalExit then 4 else 0)
		+ math.max(0, node.position.Y - botPosition.Y) * Config.runnerVerticalBonus
		+ tangentScore * Config.runnerOrbitWeight
		+ preferredDistanceScore
		- entry.time * Config.runnerTravelTimeWeight
		- reversalPenalty
		- recentPenalty
		- topologyPenalty
end

function BotRunnerBrain.update(
	state: RState,
	world: RWorld,
	botPosition: Vector3,
	botVelocity: Vector3,
	opponentPosition: Vector3,
	opponentVelocity: Vector3
): (Vector3, string)
	local opponentDistance = (botPosition - opponentPosition).Magnitude
	local commitSeconds = if opponentDistance <= Config.runnerThreatRadius
		then Config.runnerPressureCommitSeconds
		else Config.runnerGoalCommitSeconds
	local reached = state.goal ~= nil and (state.goal - botPosition).Magnitude <= Config.plannerReachDistance * 2
	local threatMoved = state.scanning and (opponentPosition - state.scanOpponent).Magnitude > Config.runnerThreatRadius
	if not state.scanning and (not state.goal or reached or os.clock() - state.committedAt >= commitSeconds)
		or threatMoved
	then
		beginScan(state, world, botPosition, opponentPosition)
	end

	local processed = 0
	while state.scanning and processed < Config.runnerRolloutTransitionsPerStep do
		if state.processedTransitions >= Config.runnerRolloutMaximumTransitions then
			state.queueCursor = #state.queue + 1
		end
		local entry = state.queue[state.queueCursor]
		if not entry then
			state.scanning = false
			local bestNode = if state.bestNodeId then world.nodes[state.bestNodeId] else nil
			if bestNode then
				state.goal = bestNode.position
				state.goalNodeId = bestNode.id
				state.goalScore = state.bestScore
				state.committedAt = os.clock()
				state.recentGoals[#state.recentGoals + 1] = bestNode.id
				if #state.recentGoals > Config.runnerRecentGoalCount then table.remove(state.recentGoals, 1) end
			end
			break
		end
		state.queueCursor += 1
		local node = world.nodes[entry.nodeId]
		if entry.depth > 0 and (node.position - botPosition).Magnitude >= Config.runnerGoalMinimumDistance then
			local score = candidateScore(state, world, entry, botPosition, botVelocity, opponentPosition, opponentVelocity)
			if score > state.bestScore then
				state.bestScore = score
				state.bestNodeId = node.id
			end
		end
		if entry.depth >= Config.runnerRolloutMaximumDepth or entry.time >= Config.runnerRolloutMaximumTravelTime then
			continue
		end
			for _, edgeId in node.edges do
				processed += 1
				state.processedTransitions += 1
			local edge = world.edges[edgeId]
			local destination = world.nodes[edge.to]
			local arrivalTime = entry.time + edge.time
			local predictedThreat = opponentPosition + flat(opponentVelocity) * math.min(arrivalTime, 2.5)
			local clearance = segmentDistance(flat(predictedThreat), flat(node.position), flat(destination.position))
			local pathCost = arrivalTime + math.max(0, Config.runnerSafeClearance - clearance) * 0.15
			if state.visited[edge.to] and (state.visited[edge.to] :: number) <= pathCost then continue end
			local firstDirection = entry.firstDirection
			if firstDirection.Magnitude == 0 then firstDirection = flat(destination.position - node.position).Unit end
			state.visited[edge.to] = pathCost
			state.queue[#state.queue + 1] = {
				nodeId = edge.to,
				previousId = node.id,
				depth = entry.depth + 1,
				time = arrivalTime,
				minimumClearance = math.min(entry.minimumClearance, clearance),
				firstDirection = firstDirection,
			}
			if processed >= Config.runnerRolloutTransitionsPerStep then break end
		end
	end

	if state.goal then
		return state.goal, `reachable escape score {math.floor(state.goalScore * 10) / 10}`
	end
	local away = botPosition - opponentPosition
	if away.Magnitude < 0.1 then away = Vector3.xAxis end
	return botPosition + away.Unit * 40, "emergency open-space escape"
end

return table.freeze(BotRunnerBrain)
