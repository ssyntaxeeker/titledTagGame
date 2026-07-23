--!strict
--[[
    BotRouteTeaching (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Records a player's demonstrated movement as executable graph transitions.
    Demonstrations are map-specific, while skill timing remains generalized by
    BotRouteMemory's existing geometry calibration keys.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local PlayerLearningObserver = require(ReplicatedStorage.Modules.Bot.BotPlayerLearningObserver)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type RAffordanceGraph = Types.RAffordanceGraph
type RMemory = BotRouteMemory.RMemory
type RObservation = PlayerLearningObserver.RObservation

export type RStep = {
	edgeId: number,
	duration: number,
	timing: number?,
}

export type RState = {
	recording: boolean,
	startedAt: number,
	steps: { RStep },
	rejectedObservations: number,
	techSteps: number,
}

local BotRouteTeaching = {}

function BotRouteTeaching.create(): RState
	return {
		recording = false,
		startedAt = 0,
		steps = {},
		rejectedObservations = 0,
		techSteps = 0,
	}
end

function BotRouteTeaching.start(state: RState)
	state.recording = true
	state.startedAt = os.clock()
	state.rejectedObservations = 0
	state.techSteps = 0
	table.clear(state.steps)
end

function BotRouteTeaching.cancel(state: RState)
	state.recording = false
	state.startedAt = 0
	state.rejectedObservations = 0
	state.techSteps = 0
	table.clear(state.steps)
end

function BotRouteTeaching.observe(
	state: RState,
	graph: RAffordanceGraph,
	observation: RObservation
): boolean
	if not state.recording then return false end
	local edgeId = observation.edgeId
	if not edgeId then
		local fromNode = graph.mapModel.nodes[observation.fromNodeId]
		local bestDistance = Config.taughtRouteEdgeMatchTolerance
		if fromNode then
			for _, candidateEdgeId in fromNode.edges do
				local candidate = graph.edges[candidateEdgeId]
				if candidate.action ~= "Walk" then continue end
				local destination = graph.mapModel.nodes[candidate.to]
				local distance = (destination.rootPosition - observation.toPosition).Magnitude
				if distance <= bestDistance then
					bestDistance = distance
					edgeId = candidateEdgeId
				end
			end
		end
	end
	if not edgeId then
		state.rejectedObservations += 1
		return false
	end
	local previous = state.steps[#state.steps]
	if previous and previous.edgeId == edgeId then return false end
	if #state.steps >= Config.taughtRouteMaximumSteps then return false end
	local edge = graph.edges[edgeId]
	state.steps[#state.steps + 1] = {
		edgeId = edgeId,
		duration = observation.duration,
		timing = observation.timing,
	}
	if edge.action ~= "Walk" then state.techSteps += 1 end
	return true
end

function BotRouteTeaching.finish(
	state: RState,
	graph: RAffordanceGraph,
	memory: RMemory
): (boolean, string)
	if not state.recording then return false, "route teaching is not recording" end
	state.recording = false
	if #state.steps < Config.taughtRouteMinimumSteps then
		local count = #state.steps
		BotRouteTeaching.cancel(state)
		return false, `only {count} executable transitions were observed`
	end

	for _, step in state.steps do
		local edge = graph.edges[step.edgeId]
		local fromNode = graph.mapModel.nodes[edge.from]
		local toNode = graph.mapModel.nodes[edge.to]
		BotRouteMemory.recordTaughtTransition(
			memory,
			edge,
			fromNode.rootPosition,
			toNode.rootPosition,
			step.duration,
			Config.taughtRouteDemonstrationWeight
		)
		BotRouteMemory.recordPlayerTransition(
			memory,
			fromNode.rootPosition,
			toNode.rootPosition,
			step.duration,
			Config.taughtRouteDemonstrationWeight
		)
		if edge.action ~= "Walk" then
			BotRouteMemory.recordEdge(
				memory,
				edge,
				true,
				Config.taughtRouteTechReward,
				step.duration,
				step.timing,
				Config.taughtRouteSkillWeight
			)
		end
	end
	local summary = `taught {#state.steps} transitions with {state.techSteps} tech steps`
	table.clear(state.steps)
	state.startedAt = 0
	state.techSteps = 0
	state.rejectedObservations = 0
	return true, summary
end

function BotRouteTeaching.getSummary(state: RState): string
	return if state.recording
		then `Teaching route: {#state.steps} transitions, {state.techSteps} tech, {state.rejectedObservations} unmatched`
		else "Teaching route: off"
end

return table.freeze(BotRouteTeaching)
