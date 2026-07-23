--!strict
--[[
    BotLearningExplorer (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Chooses bounded, executable local affordance experiments while learning is
    enabled. Exploration stays goal-aware and never scans the full graph.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotMapModel = require(ReplicatedStorage.Modules.Bot.BotMapModel)
local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole
type ActionKind = Types.ActionKind
type RAffordanceEdge = Types.RAffordanceEdge
type RAffordanceGraph = Types.RAffordanceGraph
type RMemory = BotRouteMemory.RMemory

export type RState = {
	enabled: boolean,
	nextAttemptAt: number,
	attempts: { [string]: number },
	experiments: number,
	successes: number,
	lastAction: string?,
	activeKey: string?,
}

local BotLearningExplorer = {}

function BotLearningExplorer.create(): RState
	return {
		enabled = false,
		nextAttemptAt = 0,
		attempts = {},
		experiments = 0,
		successes = 0,
		lastAction = nil,
		activeKey = nil,
	}
end

function BotLearningExplorer.setEnabled(state: RState, enabled: boolean)
	state.enabled = enabled
	state.nextAttemptAt = if enabled then os.clock() + Config.learningWarmupSeconds else 0
end

function BotLearningExplorer.choose(
	state: RState,
	graph: RAffordanceGraph?,
	memory: RMemory,
	position: Vector3,
	goalPosition: Vector3,
	role: BotRole,
	difficult: boolean,
	blockedEdgeUntil: { [number]: number }?,
	forceAttempt: boolean?
): RAffordanceEdge?
	if not state.enabled or not graph or not graph.ready then return nil end
	if os.clock() < state.nextAttemptAt and forceAttempt ~= true then return nil end
	state.nextAttemptAt = os.clock() + Config.learningExperimentIntervalSeconds

	local nearbyNodes = BotMapModel.findNodesInRadius(graph.mapModel, position, Config.learningApproachRadius)
	local startDistance = (goalPosition - position).Magnitude
	local bestEdge: RAffordanceEdge? = nil
	local bestScore = -math.huge
	local checked = 0

	for _, node in nearbyNodes do
		if math.abs(node.rootPosition.Y - position.Y) > Config.skillSourceLayerTolerance then continue end
		for _, edgeId in node.edges do
			if blockedEdgeUntil and (blockedEdgeUntil[edgeId] or 0) > os.clock() then continue end
			local edge = graph.edges[edgeId]
			local isLearnableUphillWalk = edge.action == "Walk"
				and edge.setup.requiredHeight > Config.defaultWalkStepHeight
				and edge.setup.requiredHeight <= Config.maxLearnableWalkStepHeight
			if (edge.action == "Walk" and not isLearnableUphillWalk) or edge.action == "RollBoost" then continue end
			checked += 1
			if checked > Config.learningCandidateLimit then break end

			local key = BotRouteMemory.edgeKey(edge)
			local attempts = state.attempts[key] or 0
			if attempts >= Config.learningMaxAttemptsPerAffordance then continue end
			local destination = graph.mapModel.nodes[edge.to]

			local approachDistance = (edge.setup.approachPosition - position).Magnitude
			if approachDistance > Config.learningApproachRadius then continue end
			local goalProgress = startDistance - (goalPosition - destination.rootPosition).Magnitude
			if not difficult and goalProgress < Config.learningMinimumGoalProgress then continue end

			local novelty = Config.learningMaxAttemptsPerAffordance - attempts
			local heightChange = destination.floorPosition.Y - node.floorPosition.Y
			local successProbability = BotRouteMemory.getSuccessProbability(memory, edge)
			local roleUtility = if role == "Runner" then destination.openDirections * 0.12 else 0
			local score = novelty * 0.8
				+ goalProgress * 0.22
				+ math.max(0, heightChange) * 0.06
				+ successProbability
				+ roleUtility
				- approachDistance * 0.08
				- edge.expectedTime * 0.35
			if score > bestScore then
				bestScore = score
				bestEdge = edge
			end
		end
		if checked > Config.learningCandidateLimit then break end
	end

	if bestEdge then
		local key = BotRouteMemory.edgeKey(bestEdge)
		state.attempts[key] = (state.attempts[key] or 0) + 1
		state.experiments += 1
		state.lastAction = bestEdge.action
		state.activeKey = key
	end
	return bestEdge
end

local function actionsMatch(preferredAction: ActionKind?, edgeAction: ActionKind): boolean
	if not preferredAction then return false end
	if preferredAction == "Vault" then return edgeAction == "Vault" or edgeAction == "HighVault" end
	return preferredAction == edgeAction
end

function BotLearningExplorer.chooseChaseOpportunity(
	graph: RAffordanceGraph?,
	memory: RMemory,
	position: Vector3,
	goalPosition: Vector3,
	role: BotRole,
	preferredAction: ActionKind?,
	blockedEdgeUntil: { [number]: number }
): RAffordanceEdge?
	if not graph or not graph.ready then return nil end
	local nearbyNodes = BotMapModel.findNodesInRadius(
		graph.mapModel,
		position,
		Config.chaseOpportunityRadius
	)
	local directTime = (goalPosition - position).Magnitude / Config.botWalkSpeed
	local startDistance = (goalPosition - position).Magnitude
	local bestEdge: RAffordanceEdge? = nil
	local bestScore = -math.huge
	local checked = 0

	for _, node in nearbyNodes do
		if math.abs(node.rootPosition.Y - position.Y) > Config.skillSourceLayerTolerance then continue end
		for _, edgeId in node.edges do
			if (blockedEdgeUntil[edgeId] or 0) > os.clock() then continue end
			local edge = graph.edges[edgeId]
			if edge.action == "Walk" or edge.action == "Drop" or edge.action == "RollBoost" then continue end
			checked += 1
			if checked > Config.chaseOpportunityCandidateLimit then break end
			local destination = graph.mapModel.nodes[edge.to]
			local approachDistance = (edge.setup.approachPosition - position).Magnitude
			if approachDistance > Config.chaseOpportunityRadius then continue end
			local destinationDistance = (goalPosition - destination.rootPosition).Magnitude
			local progress = startDistance - destinationDistance
			if progress < Config.chaseOpportunityMinimumProgress then continue end
			local estimatedTime = approachDistance / Config.botWalkSpeed
				+ edge.expectedTime
				+ destinationDistance / Config.botWalkSpeed
			local timeGain = directTime - estimatedTime
			local matchesPlayer = actionsMatch(preferredAction, edge.action)
			if timeGain < Config.chaseOpportunityMinimumTimeGain and not matchesPlayer then continue end
			local successProbability = BotRouteMemory.getSuccessProbability(memory, edge)
			local roleUtility = if role == "Runner" then destination.openDirections * 0.12 else 0
			local score = timeGain * 5
				+ progress * 0.16
				+ successProbability * 1.5
				+ roleUtility
				+ (if matchesPlayer then Config.chaseOpportunityPreferredActionBonus else 0)
				+ (if edge.action == "Roll" then Config.chaseOpportunityRollBonus else 0)
			if score > bestScore then
				bestScore = score
				bestEdge = edge
			end
		end
		if checked > Config.chaseOpportunityCandidateLimit then break end
	end
	return bestEdge
end

function BotLearningExplorer.recordResult(state: RState, edge: RAffordanceEdge, succeeded: boolean)
	local key = BotRouteMemory.edgeKey(edge)
	if state.activeKey ~= key then return end
	if succeeded then state.successes += 1 end
	state.lastAction = edge.action
	state.activeKey = nil
	state.nextAttemptAt = os.clock() + Config.learningResultCooldownSeconds
end

return table.freeze(BotLearningExplorer)
