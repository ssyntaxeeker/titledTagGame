--!strict
--[[
    BotTechDrill (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Repeats one authored affordance at a fixed start and goal so skill
    calibration can isolate timing parameters from tactics and route planning.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotAgent = require(ReplicatedStorage.Modules.Bot.BotAgent)
local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotSkillController = require(ReplicatedStorage.Modules.Bot.BotSkillController)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type ActionKind = Types.ActionKind
type RAffordanceEdge = Types.RAffordanceEdge
type RAffordanceGraph = Types.RAffordanceGraph
type RAgent = BotAgent.RAgent

export type RState = {
	running: boolean,
	mastered: boolean,
	action: ActionKind,
	edge: RAffordanceEdge?,
	startPosition: Vector3?,
	goalPosition: Vector3?,
	attemptActive: boolean,
	attempts: number,
	successes: number,
	failures: number,
	resetAt: number,
	recentOutcomes: { boolean },
	lastResult: string,
	rapid: boolean,
}

export type REvent = {
	kind: "Attempt" | "Result" | "Mastered",
	message: string,
}

local VALID_ACTIONS: { [string]: ActionKind } = table.freeze({
	jump = "Jump",
	vault = "Vault",
	highvault = "HighVault",
	trussclimb = "TrussClimb",
	swing = "Swing",
	drop = "Drop",
	roll = "Roll",
	rollboost = "RollBoost",
	slideboost = "SlideBoost",
	trampoline = "Trampoline",
})

local BotTechDrill = {}

local function getSummary(state: RState): string
	local edgeId = if state.edge then tostring(state.edge.id) else "none"
	return `Focused drill: {state.action} | {if state.rapid then "RAPID" else "normal"} | running {state.running} | mastered {state.mastered} | edge {edgeId}\nAttempts {state.attempts} | success {state.successes} | fail {state.failures}\n{state.lastResult}`
end

local function findEdge(
	graph: RAffordanceGraph,
	action: ActionKind,
	startPosition: Vector3,
	goalPosition: Vector3
): (RAffordanceEdge?, number, number, number)
	local bestEdge: RAffordanceEdge? = nil
	local bestScore = math.huge
	local matchingEdges = 0
	local nearestStartDistance = math.huge
	local nearestGoalDistance = math.huge
	local markerDelta = goalPosition - startPosition
	local markerDirection = Vector3.new(markerDelta.X, 0, markerDelta.Z)
	if markerDirection.Magnitude > 0.01 then markerDirection = markerDirection.Unit end
	for _, edge in graph.edges do
		if edge.action ~= action then continue end
		matchingEdges += 1
		local toNode = graph.mapModel.nodes[edge.to]
		local landingPosition = edge.setup.contactPosition or toNode.rootPosition
		local startDistance = (edge.setup.approachPosition - startPosition).Magnitude
		local goalDistance = (landingPosition - goalPosition).Magnitude
		nearestStartDistance = math.min(nearestStartDistance, startDistance)
		nearestGoalDistance = math.min(nearestGoalDistance, goalDistance)
		if startDistance > Config.techDrillStartSearchRadius
			or goalDistance > Config.techDrillGoalSearchRadius
		then
			continue
		end
		local edgeDirection = Vector3.new(
			edge.setup.approachDirection.X,
			0,
			edge.setup.approachDirection.Z
		)
		local alignment = if markerDirection.Magnitude > 0.01 and edgeDirection.Magnitude > 0.01
			then edgeDirection.Unit:Dot(markerDirection)
			else 1
		if alignment < Config.techDrillMinimumDirectionAlignment then continue end
		local score = startDistance * 0.7
			+ goalDistance * 1.25
			+ (1 - alignment) * Config.techDrillDirectionPenalty
		if score >= bestScore then continue end
		bestScore = score
		bestEdge = edge
	end
	return bestEdge, matchingEdges, nearestStartDistance, nearestGoalDistance
end

local function beginAttempt(state: RState, agent: RAgent): REvent
	local edge = state.edge
	local startPosition = state.startPosition
	local goalPosition = state.goalPosition
	assert(edge and startPosition and goalPosition, "[BotTechDrill.beginAttempt] configured drill is required")
	BotAgent.resetNavigation(agent, "Focused tech drill reset")
	local flatDirection = Vector3.new(edge.setup.approachDirection.X, 0, edge.setup.approachDirection.Z)
	local spawnCFrame = if flatDirection.Magnitude > 0.1
		then CFrame.lookAt(startPosition, startPosition + flatDirection.Unit)
		else CFrame.new(startPosition)
	agent.character:PivotTo(spawnCFrame)
	agent.rootPart.AssemblyLinearVelocity = Vector3.zero
	agent.rootPart.AssemblyAngularVelocity = Vector3.zero
	agent.humanoid:Move(Vector3.zero, false)
	state.attempts += 1
	state.attemptActive = true
	BotSkillController.start(agent.controller, edge, {
		preventApproachBacktrack = true,
		lockApproachDirection = state.action == "SlideBoost",
	})
	return {
		kind = "Attempt",
		message = `{state.action} drill attempt #{state.attempts} started on edge {edge.id}`,
	}
end

function BotTechDrill.create(): RState
	return {
		running = false,
		mastered = false,
		action = "SlideBoost",
		edge = nil,
		startPosition = nil,
		goalPosition = nil,
		attemptActive = false,
		attempts = 0,
		successes = 0,
		failures = 0,
		resetAt = 0,
		recentOutcomes = {},
		lastResult = "not configured",
		rapid = false,
	}
end

function BotTechDrill.start(
	state: RState,
	graph: RAffordanceGraph,
	actionName: string,
	startPosition: Vector3,
	goalPosition: Vector3,
	rapidMode: boolean?
): (boolean, string)
	local normalizedActionName = string.lower((string.gsub(actionName, "%s+", "")))
	local action = VALID_ACTIONS[normalizedActionName]
	if not action then return false, `unknown tech '{actionName}'` end
	local edge, matchingEdges, nearestStartDistance, nearestGoalDistance = findEdge(
		graph,
		action,
		startPosition,
		goalPosition
	)
	if not edge then
		if matchingEdges == 0 then return false, `graph contains no {action} affordances` end
		return false,
			`no {action} affordance matches the markers; closest approach {math.floor(nearestStartDistance * 10) / 10} studs, closest landing {math.floor(nearestGoalDistance * 10) / 10} studs`
	end
	state.running = true
	state.mastered = false
	state.action = action
	state.edge = edge
	state.startPosition = startPosition
	state.goalPosition = goalPosition
	state.attemptActive = false
	state.attempts = 0
	state.successes = 0
	state.failures = 0
	state.resetAt = 0
	state.lastResult = "ready"
	state.rapid = rapidMode == true
	table.clear(state.recentOutcomes)
	return true, `{action} drill selected edge {edge.id}`
end

function BotTechDrill.stop(state: RState, agent: RAgent?, reason: string)
	state.running = false
	state.mastered = false
	state.attemptActive = false
	state.lastResult = reason
	if agent then BotAgent.resetNavigation(agent, reason) end
end

function BotTechDrill.update(state: RState, agent: RAgent, dt: number, ignore: { Instance }): REvent?
	if not state.running then return nil end
	if not state.attemptActive then
		agent.decision = `Focused {state.action} drill reset`
		agent.thought = getSummary(state)
		agent.humanoid:Move(Vector3.zero, false)
		if os.clock() < state.resetAt then return nil end
		return beginAttempt(state, agent)
	end

	agent.decision = `Focused {state.action}: {agent.controller.phase}`
	agent.thought = `{getSummary(state)}\nPhase {agent.controller.phase} | runup {math.floor(agent.controller.approachOffset * 100) / 100}\nSlide hold {math.floor(agent.controller.slideHold * 1000)}ms | cancel-jump {math.floor(agent.controller.slideJumpDelay * 1000)}ms | follow-up vault {agent.controller.slideBoostShouldVault}\nRoll-jump {math.floor(agent.controller.rollBoostDelay * 1000)}ms`
	local result = BotSkillController.update(agent.controller, dt, ignore)
	if result.status ~= "Succeeded" and result.status ~= "Failed" then return nil end
	local succeeded = result.status == "Succeeded"
	local duration = math.max(0, os.clock() - agent.controller.startedAt)
	local goalPosition = state.goalPosition or agent.rootPart.Position
	local reward = if succeeded
		then Config.techDrillSuccessReward - duration * Config.skillDurationPenaltyWeight
		else -Config.techDrillFailurePenalty
	BotAgent.recordTrialOutcome(agent, succeeded, reward, duration, goalPosition)
	state.attemptActive = false
	local resetDelay = if state.rapid
		then Config.techDrillRapidResetDelaySeconds
		else Config.techDrillResetDelaySeconds
	state.resetAt = os.clock() + resetDelay
	state.successes += if succeeded then 1 else 0
	state.failures += if succeeded then 0 else 1
	state.recentOutcomes[#state.recentOutcomes + 1] = succeeded
	if #state.recentOutcomes > Config.techDrillMasteryWindow then table.remove(state.recentOutcomes, 1) end
	local recentSuccesses = 0
	for _, outcome in state.recentOutcomes do
		if outcome then recentSuccesses += 1 end
	end
	local recentRate = recentSuccesses / math.max(1, #state.recentOutcomes)
	state.lastResult = `{result.status}: {result.reason} ({math.floor(duration * 100) / 100}s, recent {math.floor(recentRate * 100)}%)`
	if state.attempts >= Config.techDrillMinimumAttempts
		and #state.recentOutcomes >= Config.techDrillMasteryWindow
		and recentRate >= Config.techDrillMasteryRate
	then
		state.running = false
		state.mastered = true
		return {
			kind = "Mastered",
			message = `{state.action} drill reached {math.floor(recentRate * 100)}% consistency over the last {#state.recentOutcomes} attempts`,
		}
	end
	return {
		kind = "Result",
		message = `{state.action} #{state.attempts} {state.lastResult}`,
	}
end

function BotTechDrill.getSummary(state: RState): string
	return getSummary(state)
end

return table.freeze(BotTechDrill)
