--!strict
--[[
    BotAgent (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    One-owner agent loop. Tactical intent, incremental search, route following,
    and movement execution cannot issue competing movement commands.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotKnowledge = require(ReplicatedStorage.Modules.Bot.BotKnowledge)
local BotMotion = require(ReplicatedStorage.Modules.Bot.BotMotion)
local BotRunnerBrain = require(ReplicatedStorage.Modules.Bot.BotRunnerBrain)
local BotSearch = require(ReplicatedStorage.Shared.Bot.BotSearch)
local BotTaughtRoutes = require(ReplicatedStorage.Modules.Bot.BotTaughtRoutes)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type BotRole = Types.BotRole
type REdge = Types.REdge
type RMemory = BotKnowledge.RMemory
type RMotion = BotMotion.RState
type RPlan = Types.RPlan
type RRunnerBrain = BotRunnerBrain.RState
type RSearch = BotSearch.RJob
type RWorld = Types.RWorld

export type RAgent = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	role: BotRole,
	world: RWorld?,
	memory: RMemory,
	motion: RMotion,
	runnerBrain: RRunnerBrain,
	search: RSearch?,
	searchMode: "Replace" | "Extend",
	searchBasePlanId: number?,
	plan: RPlan?,
	planCursor: number,
	blockedEdges: { [number]: number },
	goal: Vector3?,
	lockedVerticalGoal: Vector3?,
	verticalGoalAt: number,
	lastCorridorCheckAt: number,
	lastCorridorGoal: Vector3?,
	lastCorridorClear: boolean,
	lastPlanAt: number,
	lastPlanGoal: Vector3?,
	lastPosition: Vector3,
	lastMovementAt: number,
	bestGoalDistance: number,
	lastProgressAt: number,
	progressEdgeId: number?,
	progressTarget: Vector3?,
	enabled: boolean,
	decision: string,
	reward: number,
}

local BotAgent = {}

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function clearRoute(agent: RAgent, reason: string)
	agent.search = nil
	agent.searchMode = "Replace"
	agent.searchBasePlanId = nil
	agent.plan = nil
	agent.planCursor = 1
	BotMotion.cancel(agent.motion, reason)
end

local function taggerGoal(agent: RAgent, opponent: BasePart): (Vector3, string, boolean)
	local opponentPosition = opponent.Position
	local delta = opponentPosition - agent.root.Position
	if os.clock() - agent.lastCorridorCheckAt >= Config.taggerCorridorCheckSeconds
		or not agent.lastCorridorGoal
		or (opponentPosition - (agent.lastCorridorGoal :: Vector3)).Magnitude >= Config.taggerCorridorGoalMoveDistance
	then
		agent.lastCorridorClear = BotMotion.directCorridor(agent.motion, opponentPosition)
		agent.lastCorridorGoal = opponentPosition
		agent.lastCorridorCheckAt = os.clock()
	end
	local direct = agent.lastCorridorClear
	if math.abs(delta.Y) >= Config.taggerVerticalCommitDifference then
		if not agent.lockedVerticalGoal then
			agent.lockedVerticalGoal = opponentPosition
			agent.verticalGoalAt = os.clock()
		end
	elseif math.abs(delta.Y) <= Config.plannerGoalLayerTolerance
		or os.clock() - agent.verticalGoalAt > Config.taggerVerticalCommitSeconds
	then
		agent.lockedVerticalGoal = nil
	end
	if agent.lockedVerticalGoal then return agent.lockedVerticalGoal, "committed vertical access", false end
	if direct and delta.Magnitude <= Config.taggerDirectDistance then return opponentPosition, "direct pressure", true end
	local velocity = flat(opponent.AssemblyLinearVelocity)
	local predicted = opponentPosition + velocity * Config.taggerPredictionSeconds
	return predicted, if direct then "predictive pursuit" else "graph pursuit", direct
end

local function requestPlan(agent: RAgent, goal: Vector3, opponent: BasePart)
	local world = agent.world
	if not world or not world.graphReady then return end
	if os.clock() - agent.lastPlanAt < Config.plannerReplanSeconds then return end
	agent.search = BotSearch.create(
		world,
		agent.memory,
		agent.root.Position,
		goal,
		agent.role,
		opponent.Position,
		opponent.AssemblyLinearVelocity,
		agent.root.AssemblyLinearVelocity
	)
	agent.lastPlanAt = os.clock()
	agent.lastPlanGoal = goal
	agent.searchMode = "Replace"
	agent.searchBasePlanId = nil
end

local function requestExtension(agent: RAgent, goal: Vector3, opponent: BasePart)
	local world = agent.world
	local plan = agent.plan
	if not world or not plan or agent.search then return end
	if #plan.edges - agent.planCursor + 1 > Config.plannerExtensionLookahead then return end
	if agent.lastPlanGoal
		and (goal - (agent.lastPlanGoal :: Vector3)).Magnitude < Config.plannerExtensionGoalMoveDistance
	then
		return
	end
	if os.clock() - agent.lastPlanAt < Config.plannerReplanSeconds then return end
	local terminalNode = world.nodes[plan.nodes[#plan.nodes]]
	local lastEdge = world.edges[plan.edges[#plan.edges]]
	agent.search = BotSearch.create(
		world,
		agent.memory,
		terminalNode.position,
		goal,
		agent.role,
		opponent.Position,
		opponent.AssemblyLinearVelocity,
		lastEdge.direction
	)
	if not agent.search then return end
	agent.searchMode = "Extend"
	agent.searchBasePlanId = plan.id
	agent.lastPlanAt = os.clock()
	agent.lastPlanGoal = goal
end

local function stepSearch(agent: RAgent)
	local search = agent.search
	if not search then return end
	if not BotSearch.step(search, if agent.plan then Config.plannerBudget else Config.plannerUrgentBudget) then return end
	agent.search = nil
	if search.failed or not search.plan then return end
	if agent.searchMode == "Extend" then
		local activePlan = agent.plan
		if not activePlan or activePlan.id ~= agent.searchBasePlanId or #search.plan.edges == 0 then return end
		for nodeIndex = 2, #search.plan.nodes do activePlan.nodes[#activePlan.nodes + 1] = search.plan.nodes[nodeIndex] end
		for _, edgeId in search.plan.edges do activePlan.edges[#activePlan.edges + 1] = edgeId end
		activePlan.goal = search.plan.goal
		activePlan.cost += search.plan.cost
		activePlan.time += search.plan.time
		activePlan.success *= search.plan.success
		activePlan.id = search.plan.id
		agent.searchMode = "Replace"
		agent.searchBasePlanId = nil
		return
	end
	if agent.plan then return end
	if #search.plan.edges == 0 then return end
	agent.plan = search.plan
	local world = agent.world
	if not world then return end
	local nearestNodeIndex = 1
	local nearestDistance = math.huge
	for nodeIndex, nodeId in search.plan.nodes do
		if nodeIndex > #search.plan.edges then break end
		if nodeIndex > 1 and world.edges[search.plan.edges[nodeIndex - 1]].action ~= "Walk" then break end
		local distance = (world.nodes[nodeId].position - agent.root.Position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestNodeIndex = nodeIndex
		end
	end
	agent.planCursor = math.clamp(nearestNodeIndex, 1, #search.plan.edges)
end

local function currentEdge(agent: RAgent): REdge?
	local world = agent.world
	local plan = agent.plan
	if not world or not plan then return nil end
	local edgeId = plan.edges[agent.planCursor]
	return if edgeId then world.edges[edgeId] else nil
end

local function beginCurrentEdge(agent: RAgent): boolean
	local world = agent.world
	local plan = agent.plan
	if world and plan then
		local maximum = math.min(#plan.edges, agent.planCursor + Config.plannerWalkLookahead - 1)
		local farthestWalk = agent.planCursor
		for checkCursor = agent.planCursor, maximum do
			if world.edges[plan.edges[checkCursor]].action ~= "Walk" then break end
			farthestWalk = checkCursor
		end
		if farthestWalk > agent.planCursor then
			local candidate = world.edges[plan.edges[farthestWalk]]
			local destination = world.nodes[candidate.to]
			if BotMotion.directCorridor(agent.motion, destination.position) then agent.planCursor = farthestWalk end
		end
	end
	local edge = currentEdge(agent)
	if not edge then return false end
	if (agent.blockedEdges[edge.id] or 0) > os.clock() then
		clearRoute(agent, "Known failed transition")
		return false
	end
	local learnedSlideHold = if edge.action == "SlideBoost"
		then BotKnowledge.timing(agent.memory, edge, 0.275)
		else nil
	BotMotion.start(agent.motion, edge, learnedSlideHold)
	return true
end

local function consumeMotion(agent: RAgent, goal: Vector3)
	if agent.motion.result ~= "Succeeded" and agent.motion.result ~= "Failed" then return end
	local edge = agent.motion.edge
	if edge then
		local progress = (agent.motion.root.Position - goal).Magnitude
		local reward = if agent.motion.result == "Succeeded" then 2 - edge.time * 0.15 else -4
		BotKnowledge.record(
			agent.memory,
			edge,
			agent.motion.result == "Succeeded",
			reward,
			if edge.action == "SlideBoost" then agent.motion.slideHold else nil
		)
		agent.reward += reward - progress * 0.001
		if agent.motion.result == "Failed" then agent.blockedEdges[edge.id] = os.clock() + Config.plannerFailureBlockSeconds end
	end
	if agent.motion.result == "Succeeded" and agent.plan then
		agent.planCursor += 1
		local velocity = flat(agent.root.AssemblyLinearVelocity)
		if velocity.Magnitude > 8 then
			local direction = velocity.Unit
			while agent.planCursor <= #agent.plan.edges do
				local nextEdge = (agent.world :: RWorld).edges[agent.plan.edges[agent.planCursor]]
				if nextEdge.action ~= "Walk" then break end
				local remaining = flat(nextEdge.target - agent.root.Position)
				local predictedDistance = (nextEdge.target - (agent.root.Position + velocity * 0.35)).Magnitude
				if remaining:Dot(direction) > 0.5
					and predictedDistance > Config.plannerReachDistance * 1.5
				then
					break
				end
				agent.planCursor += 1
			end
		end
		BotMotion.clear(agent.motion)
		if agent.planCursor > #agent.plan.edges then
			agent.plan = nil
			agent.planCursor = 1
		end
	else
		clearRoute(agent, agent.motion.reason)
		if agent.role == "Runner" then BotRunnerBrain.invalidate(agent.runnerBrain) end
	end
end

local function updateStuck(agent: RAgent, goal: Vector3)
	local now = os.clock()
	if (agent.root.Position - agent.lastPosition).Magnitude >= Config.stuckMovementDistance then
		agent.lastPosition = agent.root.Position
		agent.lastMovementAt = now
	end
	local edge = currentEdge(agent)
	local progressTarget = if edge then edge.target else goal
	local progressEdgeId = if edge then edge.id else nil
	if agent.progressEdgeId ~= progressEdgeId
		or not agent.progressTarget
		or (progressTarget - (agent.progressTarget :: Vector3)).Magnitude >= Config.plannerGoalMoveDistance
	then
		agent.progressEdgeId = progressEdgeId
		agent.progressTarget = progressTarget
		agent.bestGoalDistance = (progressTarget - agent.root.Position).Magnitude
		agent.lastProgressAt = now
	end
	local distance = (progressTarget - agent.root.Position).Magnitude
	if distance <= agent.bestGoalDistance - Config.stuckProgressDistance then
		agent.bestGoalDistance = distance
		agent.lastProgressAt = now
	end
	if now - agent.lastMovementAt < Config.stuckMovementSeconds
		and now - agent.lastProgressAt < Config.stuckProgressSeconds
	then
		return
	end
	if edge then agent.blockedEdges[edge.id] = now + Config.plannerFailureBlockSeconds end
	clearRoute(agent, "No route progress")
	if agent.role == "Runner" then BotRunnerBrain.invalidate(agent.runnerBrain) end
	agent.lastPosition = agent.root.Position
	agent.lastMovementAt = now
	agent.bestGoalDistance = distance
	agent.lastProgressAt = now
	agent.progressEdgeId = nil
	agent.progressTarget = nil
	agent.decision = "backtracking through a new reachable route"
end

function BotAgent.create(character: Model, humanoid: Humanoid, root: BasePart, role: BotRole, memory: RMemory): RAgent
	humanoid.WalkSpeed = character:GetAttribute("MinRunSpeed") or 16
	humanoid.UseJumpPower = true
	humanoid.JumpPower = character:GetAttribute("MinJumpPower") or 16
	humanoid.AutoRotate = false
	return {
		character = character, humanoid = humanoid, root = root, role = role,
		world = nil, memory = memory, motion = BotMotion.create(character, humanoid, root),
		runnerBrain = BotRunnerBrain.create(), search = nil, searchMode = "Replace", searchBasePlanId = nil,
		plan = nil, planCursor = 1,
			blockedEdges = {}, goal = nil, lockedVerticalGoal = nil, verticalGoalAt = 0,
			lastCorridorCheckAt = 0, lastCorridorGoal = nil, lastCorridorClear = false,
		lastPlanAt = 0, lastPlanGoal = nil, lastPosition = root.Position,
		lastMovementAt = os.clock(), bestGoalDistance = math.huge, lastProgressAt = os.clock(),
		progressEdgeId = nil, progressTarget = nil,
		enabled = false, decision = "idle", reward = 0,
	}
end

function BotAgent.setWorld(agent: RAgent, world: RWorld?)
	if agent.world == world then return end
	clearRoute(agent, "World changed")
	agent.world = world
	table.clear(agent.blockedEdges)
	BotRunnerBrain.invalidate(agent.runnerBrain)
end

function BotAgent.setRole(agent: RAgent, role: BotRole)
	if agent.role == role then return end
	agent.role = role
	clearRoute(agent, "Role changed")
	BotRunnerBrain.invalidate(agent.runnerBrain)
	agent.lockedVerticalGoal = nil
end

function BotAgent.setEnabled(agent: RAgent, enabled: boolean)
	agent.enabled = enabled
	if enabled then return end
	clearRoute(agent, "Disabled")
	agent.humanoid:Move(Vector3.zero, false)
end

function BotAgent.update(agent: RAgent, dt: number, opponent: BasePart)
	if not agent.enabled or not agent.character.Parent then return end
	BotMotion.updateLocomotion(agent.motion, dt)
	local world = agent.world
	local goal: Vector3
	local direct = false
	if agent.role == "Runner" then
		if world and world.graphReady then
			goal, agent.decision = BotRunnerBrain.update(
				agent.runnerBrain,
				world,
				agent.root.Position,
				agent.root.AssemblyLinearVelocity,
				opponent.Position,
				opponent.AssemblyLinearVelocity
			)
		else
			local away = agent.root.Position - opponent.Position
			if away.Magnitude < 0.1 then away = Vector3.xAxis end
			goal = agent.root.Position + away.Unit * 40
			agent.decision = "fallback escape while navigation is unavailable"
		end
	else
		goal, agent.decision, direct = taggerGoal(agent, opponent)
	end
	agent.goal = goal
	if direct and agent.motion.result ~= "Running" and agent.plan then clearRoute(agent, "Direct chase opened") end
	consumeMotion(agent, goal)
	updateStuck(agent, goal)
	if world and world.graphReady and not direct and not agent.plan and not agent.search and agent.motion.result ~= "Running" then
		local taughtEdge = BotTaughtRoutes.findUsefulEdge(world, agent.root.Position, goal, agent.blockedEdges)
		if taughtEdge then
			agent.plan = BotTaughtRoutes.plan(taughtEdge, goal)
			agent.planCursor = 1
			agent.lastPlanGoal = goal
			agent.decision = `using taught {taughtEdge.action} transition`
		end
	end

	if not agent.plan and not agent.search then requestPlan(agent, goal, opponent) end
	if agent.plan and not direct then requestExtension(agent, goal, opponent) end
	stepSearch(agent)

	local nextEdge = currentEdge(agent)
	if BotMotion.updateRoll(agent.motion, goal, dt, nextEdge ~= nil and nextEdge.action == "RollBoost") then return end
	if agent.motion.result == "Running" then
		BotMotion.update(agent.motion, dt)
		return
	end
	if agent.plan then
		if beginCurrentEdge(agent) then BotMotion.update(agent.motion, dt) end
		return
	end
	BotMotion.direct(agent.motion, goal, dt)
	if not direct and not agent.search then requestPlan(agent, goal, opponent) end
end

function BotAgent.getPlan(agent: RAgent): RPlan?
	return agent.plan
end

return table.freeze(BotAgent)
