--!strict
--[[
    BotExplorationSwarm (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Owns a frame-staggered pool of independent route explorers. Explorers
    share the map and learning memory, but each owns its agent, planner, goal,
    execution state, and role-specific policy samples.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BotAgent = require(ReplicatedStorage.Modules.Bot.BotAgent)
local BotMapModel = require(ReplicatedStorage.Modules.Bot.BotMapModel)
local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotPresentation = require(ReplicatedStorage.Modules.Bot.BotPresentation)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local BotTimeTrials = require(ReplicatedStorage.Modules.Bot.BotTimeTrials)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole
type RAffordanceEdge = Types.RAffordanceEdge
type RAffordanceGraph = Types.RAffordanceGraph
type RPlan = Types.RPlan
type RSurfaceNode = Types.RSurfaceNode
type RAgent = BotAgent.RAgent
type RMemory = BotRouteMemory.RMemory
type RTimeTrial = BotTimeTrials.RState
type ExperienceSink = (RAffordanceGraph, number, BotRole, boolean, number, number, number?, Vector3?) -> ()

export type REntry = {
	agent: RAgent,
	cleanup: () -> (),
	target: Part,
	goalNodeId: number,
	goalAction: string,
	goalStartedAt: number,
	lastUpdateAt: number,
	recentGoalIds: { number },
	recentGoalSet: { [number]: boolean },
	timeTrial: RTimeTrial,
}

export type RState = {
	entries: { REntry },
	cursor: number,
	generation: number,
	spawning: boolean,
	completions: number,
	timeouts: number,
	random: Random,
	nodeVisits: { [number]: number },
	experienceSink: ExperienceSink?,
}

local BotExplorationSwarm = {}

local function destroyEntry(entry: REntry)
	entry.cleanup()
	BotAgent.destroy(entry.agent)
	if entry.target.Parent then entry.target:Destroy() end
end

local function eligibleNode(node: RSurfaceNode): boolean
	return not node.isBarrierAdjacent and node.openDirections > 0 and #node.edges > 0
end

local function isSeparatedFromExplorerGoals(
	state: RState,
	entry: REntry,
	graph: RAffordanceGraph,
	position: Vector3
): boolean
	for _, otherEntry in state.entries do
		if otherEntry == entry or otherEntry.goalNodeId <= 0 then continue end
		local otherGoal = graph.mapModel.nodes[otherEntry.goalNodeId]
		if otherGoal and (otherGoal.rootPosition - position).Magnitude < Config.swarmGoalSeparationDistance then
			return false
		end
	end
	return true
end

local function collectOtherGoalPositions(state: RState, entry: REntry, graph: RAffordanceGraph): { Vector3 }
	local positions: { Vector3 } = {}
	for _, otherEntry in state.entries do
		if otherEntry == entry or otherEntry.goalNodeId <= 0 then continue end
		local otherGoal = graph.mapModel.nodes[otherEntry.goalNodeId]
		if otherGoal then positions[#positions + 1] = otherGoal.rootPosition end
	end
	return positions
end

local function chooseSpawnNode(graph: RAffordanceGraph, index: number, count: number): RSurfaceNode
	local nodes = graph.mapModel.nodes
	local startIndex = math.clamp(math.floor((index - 0.5) / math.max(1, count) * #nodes), 1, #nodes)
	for offset = 0, #nodes - 1 do
		local node = nodes[(startIndex + offset - 1) % #nodes + 1]
		if eligibleNode(node) then return node end
	end
	error("[BotExplorationSwarm.chooseSpawnNode] graph has no eligible spawn node")
end

local function chooseLocalTechGoal(state: RState, entry: REntry, graph: RAffordanceGraph, memory: RMemory): (RSurfaceNode?, string?)
	local source = BotMapModel.findNearestNode(graph.mapModel, entry.agent.rootPart.Position, Config.neighborRadius)
	if not source then return nil, nil end
	local candidates: { RAffordanceEdge } = {}
	local bestExperience = math.huge
	for _, edgeId in source.edges do
		local edge = graph.edges[edgeId]
		if edge.action == "Walk" and not edge.setup.requiresSlide then continue end
		local destination = graph.mapModel.nodes[edge.to]
		if not eligibleNode(destination)
			or entry.recentGoalSet[destination.id]
			or not isSeparatedFromExplorerGoals(state, entry, graph, destination.rootPosition)
		then
			continue
		end
		local experience = BotRouteMemory.getExperienceCount(memory, edge)
		if experience < bestExperience then
			table.clear(candidates)
			bestExperience = experience
		end
		if experience == bestExperience then candidates[#candidates + 1] = edge end
	end
	if #candidates == 0 then return nil, nil end
	local edge = candidates[state.random:NextInteger(1, #candidates)]
	return graph.mapModel.nodes[edge.to], edge.action
end

local function chooseMapGoal(state: RState, entry: REntry, graph: RAffordanceGraph, memory: RMemory): (RSurfaceNode, string)
	local nodes = graph.mapModel.nodes
	local origin = entry.agent.rootPart.Position
	local bestNode: RSurfaceNode? = nil
	local bestScore = -math.huge
	for _ = 1, Config.swarmGoalCandidateSamples do
		local node = nodes[state.random:NextInteger(1, #nodes)]
		if not eligibleNode(node)
			or entry.recentGoalSet[node.id]
			or not isSeparatedFromExplorerGoals(state, entry, graph, node.rootPosition)
		then
			continue
		end
		local delta = node.rootPosition - origin
		local distance = delta.Magnitude
		if distance < Config.swarmGoalMinimumDistance then continue end
		local distanceScore = -math.abs(distance - Config.swarmGoalPreferredDistance) * 0.025
		local verticalScore = math.min(math.abs(delta.Y), 24) * 0.12
		local branchScore = node.openDirections * (if entry.agent.role == "Runner" then 0.8 else 0.35)
		local memoryScore = -BotRouteMemory.getAreaScore(memory, node.rootPosition, entry.agent.role) * 0.02
		local noveltyScore = -(state.nodeVisits[node.id] or 0) * Config.swarmGoalVisitPenalty
		local score = distanceScore
			+ verticalScore
			+ branchScore
			+ memoryScore
			+ noveltyScore
			+ state.random:NextNumber() * 1.5
		if score > bestScore then
			bestScore = score
			bestNode = node
		end
	end
	if bestNode then return bestNode, "Route" end
	local startIndex = state.random:NextInteger(1, #nodes)
	for offset = 0, #nodes - 1 do
		local node = nodes[(startIndex + offset - 1) % #nodes + 1]
		if eligibleNode(node)
			and not entry.recentGoalSet[node.id]
			and (node.rootPosition - origin).Magnitude >= Config.swarmGoalMinimumDistance
			and isSeparatedFromExplorerGoals(state, entry, graph, node.rootPosition)
		then
			return node, "Route"
		end
	end
	for offset = 0, #nodes - 1 do
		local node = nodes[(startIndex + offset - 1) % #nodes + 1]
		if eligibleNode(node)
			and not entry.recentGoalSet[node.id]
			and (node.rootPosition - origin).Magnitude >= Config.swarmGoalMinimumDistance
		then
			return node, "Route"
		end
	end
	return chooseSpawnNode(graph, state.random:NextInteger(1, #nodes), #nodes), "Route"
end

local function rememberGoal(state: RState, entry: REntry, nodeId: number)
	if #entry.recentGoalIds >= Config.swarmRecentGoalCount then
		local expiredNodeId = table.remove(entry.recentGoalIds, 1)
		entry.recentGoalSet[expiredNodeId] = nil
	end
	entry.recentGoalIds[#entry.recentGoalIds + 1] = nodeId
	entry.recentGoalSet[nodeId] = true
	state.nodeVisits[nodeId] = (state.nodeVisits[nodeId] or 0) + 1
end

local function assignGoal(state: RState, entry: REntry, graph: RAffordanceGraph, memory: RMemory)
	BotAgent.resetNavigation(entry.agent, "Exploration destination changed")
	local localGoal, action = chooseLocalTechGoal(state, entry, graph, memory)
	local goal: RSurfaceNode
	local goalAction: string
	if localGoal and action and state.random:NextNumber() <= Config.swarmLocalTechGoalChance then
		goal = localGoal
		goalAction = action
	else
		goal, goalAction = chooseMapGoal(state, entry, graph, memory)
	end
	entry.goalNodeId = goal.id
	entry.goalAction = goalAction
	entry.goalStartedAt = os.clock()
	entry.target.Position = goal.rootPosition
	rememberGoal(state, entry, goal.id)
end

local function startTimeTrialAttempt(entry: REntry, graph: RAffordanceGraph)
	BotTimeTrials.startAttempt(entry.timeTrial, entry.agent, graph, entry.target)
	entry.goalNodeId = entry.timeTrial.endNodeId
	entry.goalAction = "TimeTrial"
	entry.goalStartedAt = entry.timeTrial.attemptStartedAt
end

function BotExplorationSwarm.create(): RState
	return {
		entries = {},
		cursor = 1,
		generation = 0,
		spawning = false,
		completions = 0,
		timeouts = 0,
		random = Random.new(),
		nodeVisits = {},
		experienceSink = nil,
	}
end

function BotExplorationSwarm.clear(state: RState)
	state.generation += 1
	state.spawning = false
	for _, entry in state.entries do destroyEntry(entry) end
	table.clear(state.entries)
	table.clear(state.nodeVisits)
	state.cursor = 1
	state.experienceSink = nil
end

-- Spawning yields between clones because cloning and animation setup are much
-- more expensive than steady-state swarm updates.
function BotExplorationSwarm.spawn(
	state: RState,
	count: number,
	graph: RAffordanceGraph,
	memory: RMemory,
	experienceSink: ExperienceSink,
	enabled: boolean
)
	assert(graph.ready and #graph.mapModel.nodes > 0, "[BotExplorationSwarm.spawn] a ready graph is required")
	BotExplorationSwarm.clear(state)
	state.generation += 1
	local generation = state.generation
	local botCount = math.clamp(math.floor(count), 1, Config.swarmMaximumBots)
	state.experienceSink = experienceSink
	state.spawning = true
	task.spawn(function()
		for index = 1, botCount do
			if state.generation ~= generation then return end
			local spawnNode = chooseSpawnNode(graph, index, botCount)
			local role: BotRole = if index % 2 == 1 then "Runner" else "Tagger"
			local bot, humanoid, rootPart, cleanup = BotPresentation.spawn(
				`RouteExplorer{index}`,
				CFrame.new(spawnNode.rootPosition),
				role
			)
			local target = Instance.new("Part")
			target.Name = `ExplorerTarget{index}`
			target.Size = Vector3.one * 0.1
			target.Anchored = true
			target.CanCollide = false
			target.CanQuery = false
			target.CanTouch = false
			target.Transparency = 1
			target.Parent = BotPresentation.getBotsFolder()
			local timeTrial = BotTimeTrials.create()
			local agent = BotAgent.create(bot, humanoid, rootPart, role, memory, function(
				experienceGraph: RAffordanceGraph,
				edgeId: number,
				experienceRole: BotRole,
				succeeded: boolean,
				reward: number,
				duration: number,
				goalPosition: Vector3?
			)
				experienceSink(experienceGraph, edgeId, experienceRole, succeeded, reward, duration, nil, goalPosition)
				BotTimeTrials.recordEdge(timeTrial, edgeId, succeeded)
			end)
			BotAgent.setGraph(agent, graph)
			BotAgent.setLearningEnabled(agent, true)
			BotAgent.setEnabled(agent, enabled)
			local entry: REntry = {
				agent = agent,
				cleanup = cleanup,
				target = target,
				goalNodeId = 0,
				goalAction = "Route",
				goalStartedAt = 0,
				lastUpdateAt = os.clock(),
				recentGoalIds = {},
				recentGoalSet = {},
				timeTrial = timeTrial,
			}
			state.entries[#state.entries + 1] = entry
			assignGoal(state, entry, graph, memory)
			RunService.Heartbeat:Wait()
		end
		if state.generation == generation then state.spawning = false end
	end)
end

function BotExplorationSwarm.setGraph(state: RState, graph: RAffordanceGraph?)
	for _, entry in state.entries do BotAgent.setGraph(entry.agent, graph) end
end

function BotExplorationSwarm.setEnabled(state: RState, enabled: boolean)
	for _, entry in state.entries do BotAgent.setEnabled(entry.agent, enabled) end
end

function BotExplorationSwarm.setLearningEnabled(state: RState, enabled: boolean)
	for _, entry in state.entries do BotAgent.setLearningEnabled(entry.agent, enabled) end
end

function BotExplorationSwarm.update(
	state: RState,
	dt: number,
	graph: RAffordanceGraph?,
	memory: RMemory,
	ignore: { Instance }
)
	if not graph or not graph.ready or #state.entries == 0 then return end
	local updateCount = math.min(Config.swarmAgentsPerUpdate, #state.entries)
	local now = os.clock()
	for _ = 1, updateCount do
		if state.cursor > #state.entries then state.cursor = 1 end
		local entry = state.entries[state.cursor]
		state.cursor += 1
		if not entry.agent.character.Parent then continue end
		local goalNode = graph.mapModel.nodes[entry.goalNodeId]
		local reached = goalNode ~= nil
			and (entry.agent.rootPart.Position - goalNode.rootPosition).Magnitude <= Config.swarmGoalReachDistance
		local timedOut = if entry.timeTrial.enabled
			then BotTimeTrials.timedOut(entry.timeTrial, now)
			else now - entry.goalStartedAt >= Config.swarmGoalTimeoutSeconds
		if entry.timeTrial.enabled and (reached or timedOut) then
			local experienceSink = state.experienceSink
			assert(experienceSink, "[BotExplorationSwarm.update] time trial has no experience sink")
			local pairFinished = BotTimeTrials.finishAttempt(
				entry.timeTrial,
				reached,
				graph,
				memory,
				entry.agent.role,
				experienceSink
			)
			if pairFinished then
				BotTimeTrials.changeOneEndpoint(
					entry.timeTrial,
					graph,
					state.random,
					collectOtherGoalPositions(state, entry, graph)
				)
			end
			startTimeTrialAttempt(entry, graph)
		elseif reached or timedOut then
			if reached then
				state.completions += 1
				BotRouteMemory.recordArea(memory, goalNode.rootPosition, 0.25, entry.agent.role)
			else
				state.timeouts += 1
				if goalNode then BotRouteMemory.recordArea(memory, goalNode.rootPosition, -0.2, entry.agent.role) end
			end
			BotTimeTrials.recordExplorationGoal(entry.timeTrial)
			if BotTimeTrials.shouldBegin(entry.timeTrial) then
				BotTimeTrials.begin(
					entry.timeTrial,
					graph,
					entry.agent.rootPart.Position,
					state.random,
					collectOtherGoalPositions(state, entry, graph)
				)
				startTimeTrialAttempt(entry, graph)
			else
				assignGoal(state, entry, graph, memory)
			end
		end
		local entryDt = math.clamp(now - entry.lastUpdateAt, dt, Config.swarmMaximumUpdateDt)
		entry.lastUpdateAt = now
		BotAgent.update(
			entry.agent,
			entryDt,
			entry.target,
			ignore,
			entry.target.Position,
			Config.swarmPlannerBudgetSeconds
		)
	end
end

function BotExplorationSwarm.findAgent(state: RState, bot: Model): RAgent?
	for _, entry in state.entries do
		if entry.agent.character == bot then return entry.agent end
	end
	return nil
end

function BotExplorationSwarm.getSummary(state: RState): string
	local activeTrials = 0
	local completedPairs = 0
	for _, entry in state.entries do
		if entry.timeTrial.enabled then activeTrials += 1 end
		completedPairs += entry.timeTrial.pairsCompleted
	end
	return `{#state.entries} bots{if state.spawning then " (spawning)" else ""} | {state.completions} goals | {state.timeouts} timeouts | {activeTrials} trials | {completedPairs} promoted pairs`
end

function BotExplorationSwarm.getPlans(state: RState): { RPlan }
	local plans: { RPlan } = {}
	for _, entry in state.entries do
		if entry.agent.plan then plans[#plans + 1] = entry.agent.plan end
	end
	return plans
end

return table.freeze(BotExplorationSwarm)
