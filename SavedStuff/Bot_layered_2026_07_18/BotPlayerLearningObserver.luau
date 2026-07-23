--!strict
--[[
    BotPlayerLearningObserver (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Converts short-lived player parkour state into validated affordance
    transitions. Raw inputs are never treated as successful demonstrations.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotMapModel = require(ReplicatedStorage.Modules.Bot.BotMapModel)
local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type ActionKind = Types.ActionKind
type RAffordanceGraph = Types.RAffordanceGraph

export type RState = {
	lastSampleAt: number,
	lastNodeId: number?,
	lastNodeAt: number,
	techAction: ActionKind?,
	techUntil: number,
	lastSliding: boolean,
	lastRolling: boolean,
	lastJumping: boolean,
	lastSlideStartAt: number,
	lastRollAt: number,
	lastSlideCancelAt: number,
	techTiming: number?,
	techFrequencies: { [ActionKind]: number },
}

export type RObservation = {
	fromNodeId: number,
	toNodeId: number,
	fromPosition: Vector3,
	toPosition: Vector3,
	edgeId: number?,
	action: ActionKind?,
	duration: number,
	timing: number?,
	frequency: number,
}

local BotPlayerLearningObserver = {}

local function actionMatches(observed: ActionKind, edgeAction: ActionKind): boolean
	if observed == "Vault" then
		return edgeAction == "Vault" or edgeAction == "HighVault" or edgeAction == "TrussClimb"
	end
	return observed == edgeAction
end

function BotPlayerLearningObserver.create(): RState
	return {
		lastSampleAt = 0,
		lastNodeId = nil,
		lastNodeAt = 0,
		techAction = nil,
		techUntil = 0,
		lastSliding = false,
		lastRolling = false,
		lastJumping = false,
		lastSlideStartAt = -math.huge,
		lastRollAt = -math.huge,
		lastSlideCancelAt = -math.huge,
		techTiming = nil,
		techFrequencies = {},
	}
end

function BotPlayerLearningObserver.reset(state: RState)
	state.lastSampleAt = 0
	state.lastNodeId = nil
	state.lastNodeAt = 0
	state.techAction = nil
	state.techUntil = 0
	state.lastSliding = false
	state.lastRolling = false
	state.lastJumping = false
	state.lastSlideStartAt = -math.huge
	state.lastRollAt = -math.huge
	state.lastSlideCancelAt = -math.huge
	state.techTiming = nil
end

function BotPlayerLearningObserver.update(
	state: RState,
	graph: RAffordanceGraph?,
	character: Model?,
	rootPart: BasePart?
): RObservation?
	if not graph or not graph.ready or not character or not rootPart then
		BotPlayerLearningObserver.reset(state)
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end

	local now = os.clock()
	local sliding = character:GetAttribute("Sliding") == true
	local rolling = character:GetAttribute("Rolling") == true
	local jumping = humanoid:GetState() == Enum.HumanoidStateType.Jumping
	if sliding and not state.lastSliding then state.lastSlideStartAt = now end
	if state.lastSliding and not sliding then state.lastSlideCancelAt = now end
	if rolling and not state.lastRolling then
		state.lastRollAt = now
		state.techAction = "Roll"
		state.techTiming = nil
		state.techUntil = now + Config.playerTechObservationSeconds
	end
	if jumping and not state.lastJumping then
		if now - state.lastSlideCancelAt <= Config.playerSlideBoostSequenceSeconds then
			state.techAction = "SlideBoost"
			state.techTiming = state.lastSlideCancelAt - state.lastSlideStartAt
		elseif now - state.lastRollAt <= Config.playerRollBoostSequenceSeconds then
			state.techAction = "RollBoost"
			state.techTiming = now - state.lastRollAt
		else
			state.techAction = "Jump"
			state.techTiming = nil
		end
		state.techUntil = now + Config.playerTechObservationSeconds
	end
	if character:GetAttribute("Swinging") == true then
		state.techAction = "Swing"
		state.techUntil = now + Config.playerTechObservationSeconds
	elseif character:GetAttribute("Vaulting") == true then
		if state.techAction ~= "SlideBoost" then state.techAction = "Vault" end
		state.techUntil = now + Config.playerTechObservationSeconds
	end
	state.lastSliding = sliding
	state.lastRolling = rolling
	state.lastJumping = jumping
	if state.techAction and now > state.techUntil then
		state.techAction = nil
		state.techTiming = nil
	end

	if now - state.lastSampleAt < Config.playerRouteSampleSeconds then return nil end
	state.lastSampleAt = now
	local node = BotMapModel.findNearestNode(graph.mapModel, rootPart.Position, Config.neighborRadius)
	if not node then return nil end
	local previousId = state.lastNodeId
	local previousAt = state.lastNodeAt
	state.lastNodeId = node.id
	state.lastNodeAt = now
	if not previousId or previousId == node.id then return nil end
	local previous = graph.mapModel.nodes[previousId]
	if not previous or (node.rootPosition - previous.rootPosition).Magnitude > Config.neighborRadius * 1.5 then return nil end

	local observation: RObservation = {
		fromNodeId = previous.id,
		toNodeId = node.id,
		fromPosition = previous.rootPosition,
		toPosition = node.rootPosition,
		edgeId = nil,
		action = state.techAction,
		duration = math.max(0.01, now - previousAt),
		timing = state.techTiming,
		frequency = 0,
	}
	local observedAction = state.techAction
	if not observedAction then return observation end

	local bestDistance = Config.playerAffordanceLandingTolerance
	for _, edgeId in previous.edges do
		local edge = graph.edges[edgeId]
		if not actionMatches(observedAction, edge.action) then continue end
		local destination = graph.mapModel.nodes[edge.to]
		local distance = (destination.rootPosition - rootPart.Position).Magnitude
		if distance <= bestDistance then
			bestDistance = distance
			observation.edgeId = edgeId
		end
	end
	if observation.edgeId then
		local learnedAction = graph.edges[observation.edgeId].action
		state.techFrequencies[learnedAction] = (state.techFrequencies[learnedAction] or 0) + 1
		observation.frequency = state.techFrequencies[learnedAction]
		state.techAction = nil
		state.techTiming = nil
	end
	return observation
end

return table.freeze(BotPlayerLearningObserver)
