--!strict
--[[
    BotAgent (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Single-owner bot orchestration. Exactly one of direct locomotion or the
    active skill controls movement, while planning runs incrementally in the
    background and stale jobs are cancelled by identity.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotLearningExplorer = require(ReplicatedStorage.Modules.Bot.BotLearningExplorer)
local BotMapModel = require(ReplicatedStorage.Modules.Bot.BotMapModel)
local BotNavigationIntent = require(ReplicatedStorage.Modules.Bot.BotNavigationIntent)
local MovementRules = require(ReplicatedStorage.Modules.Bot.BotMovementRules)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local BotRoutePlanner = require(ReplicatedStorage.Modules.Bot.BotRoutePlanner)
local BotSkillController = require(ReplicatedStorage.Modules.Bot.BotSkillController)
local BotStuckRecovery = require(ReplicatedStorage.Modules.Bot.BotStuckRecovery)
local BotTactics = require(ReplicatedStorage.Modules.Bot.BotTactics)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole
type ActionKind = Types.ActionKind
type RAffordanceEdge = Types.RAffordanceEdge
type RAffordanceGraph = Types.RAffordanceGraph
type RPlan = Types.RPlan
type RPlannerJob = BotRoutePlanner.RPlannerJob
type RMemory = BotRouteMemory.RMemory
type RController = BotSkillController.RController
type RExplorer = BotLearningExplorer.RState
type RStuckRecovery = BotStuckRecovery.RState
type RTactics = BotTactics.RState
type RNavigationIntent = BotNavigationIntent.RState

export type RAgent = {
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	role: BotRole,
	graph: RAffordanceGraph?,
	memory: RMemory,
	controller: RController,
	tactics: RTactics,
	navigationIntent: RNavigationIntent,
	plannerJob: RPlannerJob?,
	plan: RPlan?,
	queuedPlan: RPlan?,
	planEdgeCursor: number,
	planAttempts: { [string]: number },
	lastPlanRequestAt: number,
	lastPlanGoal: Vector3?,
	lastPlanOpponentPosition: Vector3?,
	lastPositionSample: Vector3,
	lastProgressAt: number,
	progressGoalPosition: Vector3?,
	bestGoalDistance: number,
	lastGoalProgressAt: number,
	lastRecoveryAt: number,
	lastOpportunityAt: number,
	lastFlingAt: number,
	stuckStrikeCount: number,
	lastStuckStrikeAt: number,
	blockedEdgeUntil: { [number]: number },
	forcedNavigationUntil: number,
	recoveryGoalPosition: Vector3?,
	recoveryGoalUntil: number,
	lastRecoveryGoalPosition: Vector3?,
	decision: string,
	thought: string,
	enabled: boolean,
	moveDirection: Vector3,
	lastRewardDistance: number?,
	activeSkillStartOpponentDistance: number?,
	rewardTotal: number,
	experienceSink: ((RAffordanceGraph, number, BotRole, boolean, number, number, Vector3?) -> ())?,
	explorer: RExplorer,
	stuckRecovery: RStuckRecovery,
}

local BotAgent = {}

local function getOpponentAction(opponentRoot: BasePart): ActionKind?
	local character = opponentRoot.Parent
	if not character or not character:IsA("Model") then return nil end
	if character:GetAttribute("Rolling") == true then return "Roll" end
	if character:GetAttribute("Vaulting") == true then return "Vault" end
	if character:GetAttribute("Swinging") == true then return "Swing" end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Jumping then return "Jump" end
	return nil
end

local function horizontalDirection(fromPosition: Vector3, toPosition: Vector3): Vector3
	local delta = toPosition - fromPosition
	local flat = Vector3.new(delta.X, 0, delta.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
end

local function shouldUseOpportunisticRoll(agent: RAgent, goalPosition: Vector3): boolean
	local goalDelta = goalPosition - agent.rootPart.Position
	local horizontalGoal = Vector3.new(goalDelta.X, 0, goalDelta.Z)
	if horizontalGoal.Magnitude < Config.opportunisticRollMinimumGoalDistance then return false end

	local graph = agent.graph
	local nextEdge = if graph and agent.plan
		then graph.edges[agent.plan.edgeIds[agent.planEdgeCursor]]
		else nil
	if nextEdge and nextEdge.action == "RollBoost" then return true end
	if goalDelta.Y > Config.opportunisticRollMaximumGoalRise then return false end
	if nextEdge
		and (nextEdge.action == "Vault"
			or nextEdge.action == "HighVault"
			or nextEdge.action == "Swing"
			or nextEdge.action == "SlideBoost"
			or nextEdge.action == "TrussClimb")
		and (nextEdge.setup.approachPosition - agent.rootPart.Position).Magnitude <= Config.planLookaheadDistance
	then
		return false
	end

	local velocity = agent.rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	return horizontalVelocity.Magnitude <= 1
		or horizontalVelocity.Unit:Dot(horizontalGoal.Unit) >= Config.opportunisticRollMinimumAlignment
end

local function directMove(agent: RAgent, targetPosition: Vector3, dt: number, preserveMomentum: boolean?)
	local direction = horizontalDirection(agent.rootPart.Position, targetPosition)
	if direction.Magnitude <= 0.01 then
		if preserveMomentum then
			local fallback = if agent.moveDirection.Magnitude > 0.01
				then agent.moveDirection.Unit
				else horizontalDirection(Vector3.zero, agent.rootPart.CFrame.LookVector)
			agent.humanoid:Move(fallback, false)
		else
			agent.humanoid:Move(Vector3.zero, false)
		end
		return
	end
	local map = Workspace:FindFirstChild("Map")
	if map then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { map }
		params.IgnoreWater = true
		local wallHit = Workspace:Raycast(
			agent.rootPart.Position + Vector3.yAxis * 1.2,
			direction * Config.wallNearDistance,
			params
		)
		if wallHit and math.abs(wallHit.Normal.Y) <= Config.climbWallNormalY then
			local tangent = Vector3.yAxis:Cross(wallHit.Normal)
			if tangent:Dot(direction) < 0 then tangent = -tangent end
			direction = (tangent + wallHit.Normal * 0.2).Unit
		end
	end

	agent.moveDirection = agent.moveDirection:Lerp(direction, math.clamp(dt / Config.moveDirectionSmoothing, 0, 1))
	if agent.moveDirection.Magnitude > 0.01 then agent.moveDirection = agent.moveDirection.Unit end
	local desired = CFrame.lookAt(agent.rootPart.Position, agent.rootPart.Position + agent.moveDirection)
	agent.rootPart.CFrame = agent.rootPart.CFrame:Lerp(desired, math.clamp(Config.turnRate * dt, 0, 1))
	agent.humanoid:Move(agent.moveDirection, false)
end

local function clearPlan(agent: RAgent, reason: string)
	BotRoutePlanner.cancel(agent.plannerJob)
	agent.plannerJob = nil
	agent.plan = nil
	agent.queuedPlan = nil
	agent.planEdgeCursor = 1
	agent.lastPlanOpponentPosition = nil
	if agent.controller.result.status == "Running" then BotSkillController.cancel(agent.controller, reason) end
	BotSkillController.clear(agent.controller)
end

local function planAttemptKey(agent: RAgent, edgeId: number): string
	local graph = agent.graph
	if not graph then return tostring(edgeId) end
	local edge = graph.edges[edgeId]
	return BotRouteMemory.edgeKey(edge)
end

local function furthestReachedPlanEdge(agent: RAgent, minimumCursor: number, walkOnly: boolean): number?
	local graph = agent.graph
	local plan = agent.plan
	if not graph or not plan then return nil end

	local furthest: number? = nil
	local maximumCursor = math.min(#plan.edgeIds, minimumCursor + Config.planResyncLookaheadEdges - 1)
	for cursor = minimumCursor, maximumCursor do
		local edge = graph.edges[plan.edgeIds[cursor]]
		if walkOnly and edge and edge.action ~= "Walk" then break end
		local destination = if edge then graph.mapModel.nodes[edge.to] else nil
		if not destination then continue end
		if not walkOnly and edge.action ~= "Walk" then
			local source = graph.mapModel.nodes[edge.from]
			local requiredDelta = if source then destination.rootPosition.Y - source.rootPosition.Y else 0
			if requiredDelta > Config.planResyncVerticalTolerance
				and agent.rootPart.Position.Y < destination.rootPosition.Y - Config.planResyncVerticalTolerance
			then
				break
			end
			if requiredDelta < -Config.planResyncVerticalTolerance
				and agent.rootPart.Position.Y > destination.rootPosition.Y + Config.planResyncVerticalTolerance
			then
				break
			end
		end
		local delta = destination.rootPosition - agent.rootPart.Position
		local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if horizontalDistance <= Config.planResyncHorizontalDistance
			and math.abs(delta.Y) <= Config.planResyncVerticalTolerance
		then
			furthest = cursor
		end
	end
	return furthest
end

local function advancePastReachedPlanNodes(agent: RAgent)
	local plan = agent.plan
	if not plan then return end
	local furthest = furthestReachedPlanEdge(agent, agent.planEdgeCursor, true)
	if not furthest then return end
	agent.planEdgeCursor = furthest + 1
	if agent.planEdgeCursor > #plan.edgeIds then
		agent.plan = nil
		agent.planEdgeCursor = 1
	end
end

local function consumeSkillResult(
	agent: RAgent,
	goalPosition: Vector3,
	opponentPosition: Vector3,
	isIndependentGoal: boolean
)
	local result = agent.controller.result
	if result.status ~= "Succeeded" and result.status ~= "Failed" then return end
	local graph = agent.graph
	local edge = if graph and result.edgeId then graph.edges[result.edgeId] else nil
	if edge then
		local duration = os.clock() - agent.controller.startedAt
		local startDistance = (agent.controller.startPosition - goalPosition).Magnitude
		local endDistance = (agent.rootPart.Position - goalPosition).Magnitude
		local progress = startDistance - endDistance
		local opponentDistance = (agent.rootPart.Position - opponentPosition).Magnitude
		local startOpponentDistance = agent.activeSkillStartOpponentDistance or opponentDistance
		local opponentProgress = if isIndependentGoal
			then 0
			elseif agent.role == "Tagger"
			then startOpponentDistance - opponentDistance
			else opponentDistance - startOpponentDistance
		local isTech = edge.action ~= "Walk"
		local outcomeReward = if not isTech
			then 0
			elseif result.status == "Succeeded"
			then Config.skillSuccessReward
			else -Config.skillFailurePenalty
		local reward = progress * Config.goalProgressRewardWeight
			+ opponentProgress * Config.opponentProgressRewardWeight
			+ outcomeReward
		if edge.action == "Roll" then
			reward += math.max(0, progress) * Config.rollGoalProgressRewardWeight
				+ math.max(0, opponentProgress) * Config.rollOpponentProgressRewardWeight
			if result.status == "Succeeded" then reward += Config.rollSuccessRewardBonus end
		end
		local timing = if edge.action == "SlideBoost"
			then agent.controller.slideHold
			elseif edge.action == "RollBoost"
			then agent.controller.rollBoostDelay
			else nil
		BotRouteMemory.recordEdge(agent.memory, edge, result.status == "Succeeded", reward, duration, timing)
		BotLearningExplorer.recordResult(agent.explorer, edge, result.status == "Succeeded")
		if agent.experienceSink and graph and result.edgeId then
			agent.experienceSink(
				graph,
				result.edgeId,
				agent.role,
				result.status == "Succeeded",
				reward,
				duration,
				goalPosition
			)
		end
		agent.rewardTotal += reward
	end
	agent.activeSkillStartOpponentDistance = nil
	if result.status == "Succeeded" and result.edgeId then
		agent.planAttempts[planAttemptKey(agent, result.edgeId)] = 0
	end

	if result.status == "Succeeded" and agent.plan then
		agent.stuckStrikeCount = 0
		agent.planEdgeCursor += 1
		BotSkillController.clear(agent.controller)
		advancePastReachedPlanNodes(agent)
		local source = if edge and graph then graph.mapModel.nodes[edge.from] else nil
		local destination = if edge and graph then graph.mapModel.nodes[edge.to] else nil
		local climbed = source ~= nil
			and destination ~= nil
			and destination.rootPosition.Y - source.rootPosition.Y > Config.planResyncVerticalTolerance
		if climbed and agent.plan then
			local nextEdgeId = agent.plan.edgeIds[agent.planEdgeCursor]
			local nextEdge = if nextEdgeId and graph then graph.edges[nextEdgeId] else nil
			local nextDestination = if nextEdge and graph then graph.mapModel.nodes[nextEdge.to] else nil
			local targetIsDirect = math.abs(goalPosition.Y - agent.rootPart.Position.Y)
				<= Config.directChaseVerticalTolerance
				and MovementRules.hasDirectRunCorridor(
					agent.rootPart.Position,
					goalPosition,
					{ agent.character }
				)
			local staleDescent = nextDestination ~= nil
				and nextDestination.rootPosition.Y
					< agent.rootPart.Position.Y - Config.planResyncVerticalTolerance
				and goalPosition.Y >= agent.rootPart.Position.Y - Config.planResyncVerticalTolerance
			if targetIsDirect or staleDescent then
				agent.plan = nil
				agent.planEdgeCursor = 1
				agent.decision = if targetIsDirect
					then "Climb complete: direct route to target is now open"
					else "Climb complete: replanning instead of dropping from gained height"
			end
		end
		if agent.plan and agent.planEdgeCursor > #agent.plan.edgeIds then
			agent.plan = nil
			agent.planEdgeCursor = 1
		end
		return
	end
	if result.status == "Succeeded" then
		agent.stuckStrikeCount = 0
		BotSkillController.clear(agent.controller)
		return
	end

	if result.status == "Failed" and result.edgeId then
		local key = planAttemptKey(agent, result.edgeId)
		agent.planAttempts[key] = (agent.planAttempts[key] or 0) + 1
		local attempts = agent.planAttempts[key]
		if attempts >= Config.maxEdgeAttempts then
			agent.blockedEdgeUntil[result.edgeId] = os.clock() + Config.failedRouteScrapSeconds
			agent.planAttempts[key] = 0
			agent.decision = `Scrapped failed {tostring(result.action)} route temporarily`
		elseif agent.explorer.enabled and agent.plan then
			BotSkillController.clear(agent.controller)
			agent.forcedNavigationUntil = os.clock() + 1.5
			agent.lastPositionSample = agent.rootPart.Position
			agent.lastProgressAt = os.clock()
			agent.lastGoalProgressAt = os.clock()
			agent.decision = `Retrying {tostring(result.action)} route ({attempts}/{Config.maxEdgeAttempts})`
			return
		end
	end
	BotNavigationIntent.invalidate(agent.navigationIntent)
	clearPlan(agent, `Transition failed: {result.reason}`)
	agent.forcedNavigationUntil = os.clock() + 1.5
end

local function requestPlan(
	agent: RAgent,
	goalPosition: Vector3,
	opponentPosition: Vector3?,
	opponentVelocity: Vector3?
)
	local graph = agent.graph
	if not graph or not graph.ready then return end
	local now = os.clock()
	if now - agent.lastPlanRequestAt < Config.plannerReplanCooldownSeconds then return end

	if agent.plannerJob then BotRoutePlanner.cancel(agent.plannerJob) end
	local horizontalVelocity = Vector3.new(
		agent.rootPart.AssemblyLinearVelocity.X,
		0,
		agent.rootPart.AssemblyLinearVelocity.Z
	)
	local startDirection = if horizontalVelocity.Magnitude >= Config.planInitialMotionSpeed
		then horizontalVelocity.Unit
		elseif agent.moveDirection.Magnitude > 0.01
		then agent.moveDirection.Unit
		else Vector3.new(agent.rootPart.CFrame.LookVector.X, 0, agent.rootPart.CFrame.LookVector.Z).Unit
	agent.plannerJob = BotRoutePlanner.createJob(
		graph,
		agent.memory,
		agent.rootPart.Position,
		goalPosition,
		agent.role,
		startDirection,
		opponentPosition,
		opponentVelocity,
		agent.blockedEdgeUntil,
		agent.explorer.enabled
	)
	agent.lastPlanRequestAt = now
	agent.lastPlanGoal = goalPosition
	agent.lastPlanOpponentPosition = opponentPosition
end

local function furthestDirectWalkCursor(
	agent: RAgent,
	plan: RPlan,
	startCursor: number,
	ignore: { Instance },
	requiredHeading: Vector3?
): number
	local graph = agent.graph
	if not graph then return startCursor end
	local furthestCandidate = startCursor
	local maximumCursor = math.min(#plan.edgeIds, startCursor + Config.planWalkLookaheadEdges - 1)
	for cursor = startCursor, maximumCursor do
		local edge = graph.edges[plan.edgeIds[cursor]]
		if not edge or edge.action ~= "Walk" or edge.setup.requiresSlide then break end
		local destination = graph.mapModel.nodes[edge.to]
		if not destination then break end
		local delta = destination.rootPosition - agent.rootPart.Position
		if math.abs(delta.Y) > Config.planResyncVerticalTolerance then break end
		local horizontalDelta = Vector3.new(delta.X, 0, delta.Z)
		if requiredHeading and horizontalDelta.Magnitude > 0.01
			and horizontalDelta.Unit:Dot(requiredHeading) < Config.planInitialMinimumHeadingDot
		then
			break
		end
		furthestCandidate = cursor
	end

	local minimumProbeCursor = math.max(
		startCursor,
		furthestCandidate - Config.planWalkShortcutProbeLimit + 1
	)
	for cursor = furthestCandidate, minimumProbeCursor, -1 do
		local edge = graph.edges[plan.edgeIds[cursor]]
		local destination = graph.mapModel.nodes[edge.to]
		if MovementRules.hasGroundedRunCorridor(
			agent.rootPart.Position,
			destination.rootPosition,
			ignore
		) then
			return cursor
		end
	end
	return startCursor
end

local function initialPlanCursor(agent: RAgent, plan: RPlan): number
	local velocity = agent.rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local heading = if horizontalVelocity.Magnitude >= Config.planInitialMotionSpeed
		then horizontalVelocity.Unit
		elseif agent.moveDirection.Magnitude > 0.01
		then agent.moveDirection.Unit
		else Vector3.new(agent.rootPart.CFrame.LookVector.X, 0, agent.rootPart.CFrame.LookVector.Z).Unit
	return furthestDirectWalkCursor(agent, plan, 1, { agent.character }, heading)
end

local function installPlan(agent: RAgent, plan: RPlan)
	agent.plan = plan
	agent.planEdgeCursor = initialPlanCursor(agent, plan)
	agent.queuedPlan = nil
end

local function stepPlanner(agent: RAgent, budgetSeconds: number?)
	local job = agent.plannerJob
	if not job then return end
	local selectedBudget = if budgetSeconds
		then budgetSeconds
		elseif agent.plan
		then Config.plannerBudgetSeconds
		else Config.plannerUrgentBudgetSeconds
	debug.profilebegin("BotRoutePlanner.step")
	local done = BotRoutePlanner.step(job, selectedBudget)
	debug.profileend()
	local preview = BotRoutePlanner.takePreview(job)
	if preview and not agent.plan then installPlan(agent, preview) end
	if not done then return end
	if not job.cancelled and not job.failed and job.plan then
		if agent.plan then
			agent.queuedPlan = job.plan
		else
			installPlan(agent, job.plan)
		end
	end
	agent.plannerJob = nil
end

local function chooseRecoveryGoal(agent: RAgent, tacticalGoal: Vector3): Vector3?
	local graph = agent.graph
	if not graph or not graph.ready then return nil end
	local nearbyNodes = BotMapModel.findNodesInRadius(
		graph.mapModel,
		agent.rootPart.Position,
		Config.stuckEscapeSearchRadius,
		Config.stuckEscapeCandidateLimit
	)
	local bestPosition: Vector3? = nil
	local bestScore = -math.huge
	local checked = 0

	for _, node in nearbyNodes do
		checked += 1
		if checked > Config.stuckEscapeCandidateLimit then break end
		if node.isBarrierAdjacent or node.openDirections <= 1 or #node.edges <= 1 then continue end
		local travelDistance = (node.rootPosition - agent.rootPart.Position).Magnitude
		if travelDistance < Config.planLookaheadDistance then continue end
		local tacticalProgress = (tacticalGoal - agent.rootPart.Position).Magnitude
			- (tacticalGoal - node.rootPosition).Magnitude
		local score = node.openDirections * 4
			+ math.min(8, #node.edges) * 1.5
			+ math.min(node.nearestWallDistance, Config.wallProbeDistance)
			+ tacticalProgress * 0.08
			- math.abs(travelDistance - 28) * 0.12
			+ BotRouteMemory.getAreaScore(agent.memory, node.rootPosition, agent.role) * 0.05
		if agent.lastRecoveryGoalPosition
			and (node.rootPosition - agent.lastRecoveryGoalPosition).Magnitude <= Config.planLookaheadDistance
		then
			score -= 20
		end
		if score > bestScore then
			bestScore = score
			bestPosition = node.rootPosition
		end
	end
	return bestPosition
end

local function chooseBacktrackGoal(agent: RAgent): Vector3?
	local graph = agent.graph
	local plan = agent.plan
	if not graph or not plan then return nil end

	local startIndex = math.min(agent.planEdgeCursor, #plan.nodeIds)
	for index = startIndex, 1, -1 do
		local node = graph.mapModel.nodes[plan.nodeIds[index]]
		if not node or node.isBarrierAdjacent then continue end
		if (node.rootPosition - agent.rootPart.Position).Magnitude >= Config.planNodeReachDistance * 1.5 then
			return node.rootPosition
		end
	end
	return nil
end

local function activeTransitionHeightReached(agent: RAgent): boolean
	local graph = agent.graph
	local edge = agent.controller.activeEdge
	if not graph or not edge then return false end
	local source = graph.mapModel.nodes[edge.from]
	local destination = graph.mapModel.nodes[edge.to]
	if not source or not destination then return false end
	local requiredDelta = destination.rootPosition.Y - source.rootPosition.Y
	if requiredDelta > Config.planResyncVerticalTolerance then
		return agent.rootPart.Position.Y >= destination.rootPosition.Y - Config.planResyncVerticalTolerance
	end
	if requiredDelta < -Config.planResyncVerticalTolerance then
		return agent.rootPart.Position.Y <= destination.rootPosition.Y + Config.planResyncVerticalTolerance
	end
	return true
end

local function tryLastResortFling(agent: RAgent, targetPosition: Vector3, now: number): boolean
	if agent.stuckStrikeCount < Config.stuckFlingStrikeThreshold then return false end
	if now - agent.lastFlingAt < Config.stuckFlingCooldownSeconds then return false end
	local velocity = agent.rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if horizontalVelocity.Magnitude > Config.stuckFlingMaximumCurrentSpeed then return false end
	if not MovementRules.isGrounded(agent.humanoid, agent.rootPart, { agent.character }) then return false end

	local direction = horizontalDirection(agent.rootPart.Position, targetPosition)
	if direction.Magnitude <= 0.01 then
		direction = horizontalDirection(agent.rootPart.Position, agent.rootPart.Position - agent.rootPart.CFrame.LookVector)
	end
	agent.rootPart.AssemblyLinearVelocity = direction * Config.stuckFlingHorizontalSpeed
		+ Vector3.yAxis * Config.stuckFlingVerticalSpeed
	agent.humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	agent.lastFlingAt = now
	agent.stuckStrikeCount = 0
	return true
end

local function recoverFromStuck(agent: RAgent, reason: string, tacticalGoal: Vector3)
	local now = os.clock()
	if now - agent.lastRecoveryAt < Config.stuckRecoveryCooldownSeconds then return end
	if now - agent.lastStuckStrikeAt > Config.stuckRecoveryStrikeWindowSeconds then
		agent.stuckStrikeCount = 0
	end
	agent.stuckStrikeCount += 1
	agent.lastStuckStrikeAt = now
	local graph = agent.graph
	local edgeId = if agent.controller.activeEdge then agent.controller.activeEdge.id else nil
	local backtrackGoal = chooseBacktrackGoal(agent)
	if graph and edgeId and graph.edges[edgeId] then
		local edge = graph.edges[edgeId]
		agent.blockedEdgeUntil[edgeId] = now + Config.stuckEdgeBlockSeconds
		BotRouteMemory.recordEdge(agent.memory, edge, false, -8, now - agent.lastGoalProgressAt, nil)
			if agent.experienceSink then
				agent.experienceSink(
					graph,
					edgeId,
					agent.role,
					false,
					-8,
					now - agent.lastGoalProgressAt,
					tacticalGoal
				)
			end
	end
	BotRouteMemory.recordArea(agent.memory, agent.rootPart.Position, -3, agent.role)
	clearPlan(agent, reason)
	local experiment = BotLearningExplorer.choose(
		agent.explorer,
		agent.graph,
		agent.memory,
		agent.rootPart.Position,
		tacticalGoal,
		agent.role,
		true,
		agent.blockedEdgeUntil,
		true
	)
	if experiment then
		BotSkillController.start(agent.controller, experiment)
		agent.forcedNavigationUntil = now + Config.stuckEdgeBlockSeconds
		agent.lastPositionSample = agent.rootPart.Position
		agent.lastProgressAt = now
		agent.progressGoalPosition = nil
		agent.bestGoalDistance = math.huge
		agent.lastGoalProgressAt = now
		agent.lastRecoveryAt = now
		agent.decision = `{reason}: experimenting with {experiment.action} before abandoning the route`
		return
	end
	local preferredDirection = horizontalDirection(agent.rootPart.Position, tacticalGoal)
	local slideStarted = BotStuckRecovery.tryStart(
		agent.stuckRecovery,
		agent.memory,
		agent.character,
		agent.humanoid,
		agent.rootPart,
		preferredDirection
	)
	local selectedRecoveryGoal = if slideStarted
		then nil
		elseif backtrackGoal
		then backtrackGoal
		else chooseRecoveryGoal(agent, tacticalGoal)
	local flingTarget = if selectedRecoveryGoal then selectedRecoveryGoal else tacticalGoal
	local flung = not slideStarted and tryLastResortFling(agent, flingTarget, now)
	agent.recoveryGoalPosition = if flung then nil else selectedRecoveryGoal
	if agent.recoveryGoalPosition then agent.lastRecoveryGoalPosition = agent.recoveryGoalPosition end
	agent.recoveryGoalUntil = if agent.recoveryGoalPosition
		then now + Config.stuckEscapeCommitSeconds
		else 0
	agent.forcedNavigationUntil = now + Config.stuckEdgeBlockSeconds
	agent.lastPositionSample = agent.rootPart.Position
	agent.lastProgressAt = now
	agent.progressGoalPosition = nil
	agent.bestGoalDistance = math.huge
	agent.lastGoalProgressAt = now
	agent.lastRecoveryAt = now
	agent.decision = if slideStarted
		then `{reason}: root penetrated geometry; sliding out`
		elseif flung
		then `{reason}: last-resort escape fling`
		elseif backtrackGoal
		then `{reason}: backtracking through the previous graph path`
		elseif agent.recoveryGoalPosition
		then `{reason}: pathfinding to an open recovery node`
		else `{reason}: replanning toward the tactical goal before detouring`
end

local function updateStuck(agent: RAgent, goalPosition: Vector3)
	local now = os.clock()
	local goalDistance = (goalPosition - agent.rootPart.Position).Magnitude
	if goalDistance <= Config.planNodeReachDistance * 1.5 then
		agent.stuckStrikeCount = 0
		agent.lastPositionSample = agent.rootPart.Position
		agent.lastProgressAt = now
		agent.bestGoalDistance = goalDistance
		agent.lastGoalProgressAt = now
		return
	end
	if (agent.rootPart.Position - agent.lastPositionSample).Magnitude >= Config.stuckDistance then
		agent.lastPositionSample = agent.rootPart.Position
		agent.lastProgressAt = now
	elseif now - agent.lastProgressAt >= Config.stuckSeconds then
		recoverFromStuck(agent, "No body movement", goalPosition)
		return
	end

	if not agent.progressGoalPosition
		or (goalPosition - agent.progressGoalPosition).Magnitude >= Config.goalProgressResetDistance
	then
		agent.progressGoalPosition = goalPosition
		agent.bestGoalDistance = (goalPosition - agent.rootPart.Position).Magnitude
		agent.lastGoalProgressAt = now
		return
	end

	if goalDistance <= agent.bestGoalDistance - Config.goalProgressDistance then
		agent.stuckStrikeCount = 0
		agent.bestGoalDistance = goalDistance
		agent.lastGoalProgressAt = now
		return
	end
	if now - agent.lastGoalProgressAt >= Config.goalProgressTimeoutSeconds then
		recoverFromStuck(agent, "No goal progress", goalPosition)
	end
end

local function startCurrentTransition(agent: RAgent, ignore: { Instance }): boolean
	local graph = agent.graph
	local plan = agent.plan
	if not graph or not plan then return false end
	local selectedCursor = agent.planEdgeCursor
	local selectedEdgeId = plan.edgeIds[selectedCursor]
	local selectedEdge = if selectedEdgeId then graph.edges[selectedEdgeId] else nil
	if selectedEdge and selectedEdge.action == "Walk" then
		selectedCursor = furthestDirectWalkCursor(agent, plan, selectedCursor, ignore, nil)
		selectedEdgeId = plan.edgeIds[selectedCursor]
		agent.planEdgeCursor = selectedCursor
	end
	local edgeId = selectedEdgeId
	if not edgeId then return false end
	local edge = graph.edges[edgeId]
	if edge.action == "RollBoost" then
		local previousEdgeId = plan.edgeIds[selectedCursor - 1]
		local previousEdge = if previousEdgeId then graph.edges[previousEdgeId] else nil
		if not previousEdge or previousEdge.action ~= "Drop" then
			agent.blockedEdgeUntil[edgeId] = os.clock() + Config.failedRouteScrapSeconds
			clearPlan(agent, "Rejected rollboost without an immediately preceding drop")
			return false
		end
	end
	local key = BotRouteMemory.edgeKey(edge)
	if (agent.planAttempts[key] or 0) >= Config.maxEdgeAttempts then
		BotRouteMemory.recordEdge(agent.memory, edge, false, -5, 0, nil)
		agent.blockedEdgeUntil[edgeId] = os.clock() + Config.failedRouteScrapSeconds
		agent.planAttempts[key] = 0
		clearPlan(agent, "Transition exhausted three attempts")
		return false
	end
	BotSkillController.start(agent.controller, edge)
	return true
end

function BotAgent.create(
	character: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	role: BotRole,
	memory: RMemory,
	experienceSink: ((RAffordanceGraph, number, BotRole, boolean, number, number, Vector3?) -> ())?
): RAgent
	humanoid.WalkSpeed = Config.botWalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.botJumpPower
	humanoid.AutoRotate = false
	return {
		character = character,
		humanoid = humanoid,
		rootPart = rootPart,
		role = role,
		graph = nil,
		memory = memory,
		controller = BotSkillController.create(character, humanoid, rootPart, memory),
		tactics = BotTactics.create(),
		navigationIntent = BotNavigationIntent.create(),
		plannerJob = nil,
		plan = nil,
		queuedPlan = nil,
		planEdgeCursor = 1,
		planAttempts = {},
		lastPlanRequestAt = 0,
		lastPlanGoal = nil,
		lastPlanOpponentPosition = nil,
		lastPositionSample = rootPart.Position,
		lastProgressAt = os.clock(),
		progressGoalPosition = nil,
		bestGoalDistance = math.huge,
		lastGoalProgressAt = os.clock(),
		lastRecoveryAt = 0,
		lastOpportunityAt = 0,
		lastFlingAt = 0,
		stuckStrikeCount = 0,
		lastStuckStrikeAt = 0,
		blockedEdgeUntil = {},
		forcedNavigationUntil = 0,
		recoveryGoalPosition = nil,
		recoveryGoalUntil = 0,
		lastRecoveryGoalPosition = nil,
		decision = "Idle",
		thought = "No target",
		enabled = false,
		moveDirection = Vector3.zero,
		lastRewardDistance = nil,
		activeSkillStartOpponentDistance = nil,
		rewardTotal = 0,
		experienceSink = experienceSink,
		explorer = BotLearningExplorer.create(),
		stuckRecovery = BotStuckRecovery.create(),
	}
end

function BotAgent.setGraph(agent: RAgent, graph: RAffordanceGraph?)
	if agent.graph == graph then return end
	clearPlan(agent, "Navigation graph changed")
	BotNavigationIntent.invalidate(agent.navigationIntent)
	table.clear(agent.blockedEdgeUntil)
	agent.graph = graph
end

function BotAgent.setRole(agent: RAgent, role: BotRole)
	if agent.role == role then return end
	BotStuckRecovery.cancel(agent.stuckRecovery, agent.character, agent.humanoid)
	BotSkillController.stopOpportunisticRoll(agent.controller)
	agent.role = role
	clearPlan(agent, "Role changed")
	agent.recoveryGoalPosition = nil
	agent.recoveryGoalUntil = 0
	agent.lastRecoveryGoalPosition = nil
	agent.progressGoalPosition = nil
	agent.bestGoalDistance = math.huge
	agent.lastRewardDistance = nil
	agent.activeSkillStartOpponentDistance = nil
	agent.stuckStrikeCount = 0
	agent.lastStuckStrikeAt = 0
	agent.tactics = BotTactics.create()
	BotNavigationIntent.invalidate(agent.navigationIntent)
end

function BotAgent.recordTagOutcome(agent: RAgent, taggedOpponent: boolean, goalPosition: Vector3?)
	local reward = if taggedOpponent then Config.taggerTagReward else -Config.runnerTagPenalty
	local graph = agent.graph
	local edge = if agent.controller.activeEdge
		then agent.controller.activeEdge
		elseif graph and agent.plan
		then graph.edges[agent.plan.edgeIds[agent.planEdgeCursor]]
		else nil
	if edge and graph then
		local duration = if agent.controller.activeEdge
			then math.max(0, os.clock() - agent.controller.startedAt)
			else 0
		BotRouteMemory.recordEdge(agent.memory, edge, taggedOpponent, reward, duration, nil)
			if agent.experienceSink then
				agent.experienceSink(
					graph,
					edge.id,
					agent.role,
					taggedOpponent,
					reward,
					duration,
					goalPosition or agent.lastPlanGoal
				)
			end
	end
	BotRouteMemory.recordArea(agent.memory, agent.rootPart.Position, reward * 0.25, agent.role)
	agent.rewardTotal += reward
	clearPlan(agent, if taggedOpponent then "Tag succeeded" else "Runner was tagged")
end

--[=[
	@client

	recordTrialOutcome
	==================

	Records the transition owning locomotion when an external start-to-goal
	time trial ends. The runtime calls this before resetNavigation cancels that
	transition, preserving timeout failures as useful route evidence.
]=]
function BotAgent.recordTrialOutcome(
	agent: RAgent,
	succeeded: boolean,
	reward: number,
	duration: number,
	goalPosition: Vector3
)
	local graph = agent.graph
	local edge = if agent.controller.activeEdge
		then agent.controller.activeEdge
		elseif graph and agent.plan
		then graph.edges[agent.plan.edgeIds[agent.planEdgeCursor]]
		else nil
	if not graph or not edge then return end
	BotRouteMemory.recordEdge(agent.memory, edge, succeeded, reward, duration, nil)
	BotLearningExplorer.recordResult(agent.explorer, edge, succeeded)
	if agent.experienceSink then
		agent.experienceSink(
			graph,
			edge.id,
			agent.role,
			succeeded,
			reward,
			duration,
			goalPosition
		)
	end
	agent.rewardTotal += reward
end

function BotAgent.setEnabled(agent: RAgent, enabled: boolean)
	agent.enabled = enabled
	if enabled then return end
	BotStuckRecovery.cancel(agent.stuckRecovery, agent.character, agent.humanoid)
	BotSkillController.stopOpportunisticRoll(agent.controller)
	clearPlan(agent, "Agent disabled")
	agent.humanoid:Move(Vector3.zero, false)
end

function BotAgent.setLearningEnabled(agent: RAgent, enabled: boolean)
	BotLearningExplorer.setEnabled(agent.explorer, enabled)
end

--[=[
	@client

	resetNavigation
	===============

	Cancels plan, skill, and recovery ownership before an external controller
	assigns a materially different fixed goal.
]=]
function BotAgent.resetNavigation(agent: RAgent, reason: string)
	BotStuckRecovery.cancel(agent.stuckRecovery, agent.character, agent.humanoid)
	BotSkillController.stopOpportunisticRoll(agent.controller)
	clearPlan(agent, reason)
	BotNavigationIntent.invalidate(agent.navigationIntent)
	agent.recoveryGoalPosition = nil
	agent.recoveryGoalUntil = 0
	agent.progressGoalPosition = nil
	agent.bestGoalDistance = math.huge
	agent.lastRewardDistance = nil
end

function BotAgent.update(
	agent: RAgent,
	dt: number,
	opponentRoot: BasePart,
	ignore: { Instance },
	goalOverride: Vector3?,
	plannerBudgetSeconds: number?
)
	if not agent.enabled or not agent.character.Parent then return end

	local isIndependentGoal = goalOverride ~= nil
	local tacticalGoal: Vector3
	local tacticalDecision: string
	local directAvailable: boolean
	if goalOverride then
		tacticalGoal = goalOverride
		tacticalDecision = "Independent route exploration"
		directAvailable = false
	else
		tacticalGoal, tacticalDecision, directAvailable = BotTactics.update(
			agent.tactics,
			agent.role,
			agent.graph,
			agent.memory,
			agent.rootPart.Position,
			opponentRoot.Position,
			opponentRoot.AssemblyLinearVelocity,
			ignore
		)
	end
	local intentGoal, intentMode = BotNavigationIntent.update(
		agent.navigationIntent,
		agent.role,
		agent.rootPart.Position,
		tacticalGoal,
		opponentRoot.Position,
		isIndependentGoal
	)
	if intentMode == "VerticalAccess" then
		directAvailable = false
		agent.decision = `Committed vertical access: {tacticalDecision}`
	else
		agent.decision = tacticalDecision
	end
	local now = os.clock()
	if agent.recoveryGoalPosition
		and (now >= agent.recoveryGoalUntil
			or (agent.rootPart.Position - agent.recoveryGoalPosition).Magnitude <= Config.planNodeReachDistance * 1.5)
	then
		clearPlan(agent, "Recovery goal completed or expired")
		agent.recoveryGoalPosition = nil
		agent.recoveryGoalUntil = 0
	end
	local goalPosition = agent.recoveryGoalPosition or intentGoal
	local lightweightDirectChase = not isIndependentGoal
		and agent.role == "Tagger"
		and directAvailable
		and agent.recoveryGoalPosition == nil
	if lightweightDirectChase then
		BotRoutePlanner.cancel(agent.plannerJob)
		agent.plannerJob = nil
		agent.queuedPlan = nil
		if agent.controller.result.status ~= "Running" then
			agent.plan = nil
			agent.planEdgeCursor = 1
		end
	end
	if not agent.stuckRecovery.active and agent.controller.result.status ~= "Running" then
		updateStuck(agent, goalPosition)
	end
	goalPosition = agent.recoveryGoalPosition or intentGoal
	if agent.recoveryGoalPosition then agent.decision = `Recovery path: {tacticalDecision}` end
	if agent.stuckRecovery.active then
		local recoveryStatus = BotStuckRecovery.update(
			agent.stuckRecovery,
			agent.memory,
			agent.character,
			agent.humanoid,
			agent.rootPart,
			dt
		)
		agent.decision = `Wall escape {recoveryStatus}: {agent.stuckRecovery.reason}`
		agent.thought = `{agent.role}: {agent.decision}\nFallback movement owns locomotion\nSkill: RecoverySlide\nLearning: local escape outcome`
		if recoveryStatus == "Running" then return end
		agent.lastPositionSample = agent.rootPart.Position
		agent.lastProgressAt = now
		agent.lastGoalProgressAt = now
	end

	local activePlanGoal = if agent.queuedPlan
		then agent.queuedPlan.goalPosition
		elseif agent.plan
		then agent.plan.goalPosition
		else agent.lastPlanGoal
	local goalDelta = if activePlanGoal then goalPosition - (activePlanGoal :: Vector3) else Vector3.zero
	local goalLayerMoved = activePlanGoal ~= nil
		and math.abs(goalDelta.Y) > Config.plannerGoalLayerTolerance
	local goalMoved = activePlanGoal ~= nil
		and (goalDelta.Magnitude > Config.plannerLookaheadGoalDistance or goalLayerMoved)
	if goalLayerMoved and agent.plannerJob then
		BotRoutePlanner.cancel(agent.plannerJob)
		agent.plannerJob = nil
	end
	if not lightweightDirectChase and goalMoved and not agent.plannerJob then
		requestPlan(
			agent,
			goalPosition,
			if isIndependentGoal then nil else opponentRoot.Position,
			if isIndependentGoal then nil else opponentRoot.AssemblyLinearVelocity
		)
	end
	if agent.plan and agent.controller.result.status == "Running" then
		local reachedLaterEdge = if activeTransitionHeightReached(agent)
			then furthestReachedPlanEdge(agent, agent.planEdgeCursor + 1, false)
			else nil
		if reachedLaterEdge then
			BotSkillController.complete(agent.controller, `Landed ahead at plan edge {reachedLaterEdge}`)
		end
	elseif agent.plan then
		advancePastReachedPlanNodes(agent)
	end

	consumeSkillResult(agent, goalPosition, opponentRoot.Position, isIndependentGoal)
	local queuedPlan = agent.queuedPlan
	if agent.controller.result.status ~= "Running" and queuedPlan then
		if not agent.plan then
			installPlan(agent, queuedPlan)
		else
			local activeRemainingEdges = math.max(1, #agent.plan.edgeIds - agent.planEdgeCursor + 1)
			local activeAdvantage = agent.plan.opponentAdvantage / activeRemainingEdges
			local queuedAdvantage = queuedPlan.opponentAdvantage / math.max(1, #queuedPlan.edgeIds)
			if queuedAdvantage >= activeAdvantage + Config.plannerReplacementAdvantagePerEdge then
				installPlan(agent, queuedPlan)
				agent.decision = "Replacing route with a materially better opponent cutoff"
			end
		end
	end
	stepPlanner(agent, plannerBudgetSeconds)
	if agent.plan
		and not agent.plannerJob
		and not agent.queuedPlan
		and #agent.plan.edgeIds - agent.planEdgeCursor + 1 <= Config.plannerExtensionRemainingEdges
	then
		requestPlan(
			agent,
			goalPosition,
			if isIndependentGoal then nil else opponentRoot.Position,
			if isIndependentGoal then nil else opponentRoot.AssemblyLinearVelocity
		)
	end

	local directTime = (goalPosition - agent.rootPart.Position).Magnitude / Config.botWalkSpeed
	local planUseful = not lightweightDirectChase
		and agent.plan ~= nil
		and (not directAvailable
			or agent.plan.totalCost < directTime * Config.planDirectTimeTolerance
			or (agent.explorer.enabled and agent.plan.totalCost < directTime * Config.learningPlanTimeTolerance)
			or os.clock() < agent.forcedNavigationUntil)
	local difficult = not directAvailable
		or (not lightweightDirectChase and os.clock() < agent.forcedNavigationUntil)
		or math.abs(goalPosition.Y - agent.rootPart.Position.Y) > Config.directChaseVerticalTolerance
	local preferredAction = if agent.role == "Tagger" and directAvailable
		then getOpponentAction(opponentRoot)
		else nil
	local chaseOpportunity: RAffordanceEdge? = nil
	if agent.controller.result.status ~= "Running"
		and not planUseful
		and directAvailable
		and now - agent.lastOpportunityAt >= Config.chaseOpportunityIntervalSeconds
	then
		agent.lastOpportunityAt = now
		chaseOpportunity = BotLearningExplorer.chooseChaseOpportunity(
			agent.graph,
			agent.memory,
			agent.rootPart.Position,
			goalPosition,
			agent.role,
			preferredAction,
			agent.blockedEdgeUntil
		)
	end
	local explorationEdge = if agent.controller.result.status ~= "Running"
		and difficult
		and chaseOpportunity == nil
		and agent.plan == nil
		and agent.plannerJob == nil
		then BotLearningExplorer.choose(
			agent.explorer,
			agent.graph,
			agent.memory,
			agent.rootPart.Position,
			goalPosition,
			agent.role,
			difficult
		)
		else nil
	if not lightweightDirectChase
		and not agent.plan
		and not agent.plannerJob
		and not explorationEdge
		and not chaseOpportunity
	then
		requestPlan(
			agent,
			goalPosition,
			if isIndependentGoal then nil else opponentRoot.Position,
			if isIndependentGoal then nil else opponentRoot.AssemblyLinearVelocity
		)
	end
	local opportunisticRolling = BotSkillController.updateOpportunisticRoll(
		agent.controller,
		goalPosition,
		dt,
		ignore,
		shouldUseOpportunisticRoll(agent, goalPosition)
	)

	if opportunisticRolling then
		agent.decision = "Opportunistic roll: landing momentum helps current route"
	elseif agent.controller.result.status == "Running" then
		BotSkillController.update(agent.controller, dt, ignore)
	elseif chaseOpportunity then
		clearPlan(agent, `Direct-chase opportunity: {chaseOpportunity.action}`)
		BotSkillController.start(agent.controller, chaseOpportunity)
		BotSkillController.update(agent.controller, dt, ignore)
		agent.decision = `Direct chase: taking useful {chaseOpportunity.action} opportunity`
	elseif explorationEdge then
		clearPlan(agent, `Learning experiment: {explorationEdge.action}`)
		BotSkillController.start(agent.controller, explorationEdge)
		BotSkillController.update(agent.controller, dt, ignore)
		agent.decision = `Learning experiment: {explorationEdge.action}`
	elseif planUseful then
		if startCurrentTransition(agent, ignore) then BotSkillController.update(agent.controller, dt, ignore) end
	else
		if agent.plan and directAvailable then
			agent.plan = nil
			agent.planEdgeCursor = 1
		end
		directMove(
			agent,
			goalPosition,
			dt,
			agent.plannerJob ~= nil or difficult or lightweightDirectChase
		)
	end
	if agent.controller.moveDirection.Magnitude > 0.01 then
		agent.moveDirection = agent.controller.moveDirection
	end
	if agent.controller.result.status == "Running" and not agent.activeSkillStartOpponentDistance then
		agent.activeSkillStartOpponentDistance = (agent.rootPart.Position - opponentRoot.Position).Magnitude
	end

	local rewardTarget = if isIndependentGoal then goalPosition else opponentRoot.Position
	local distance = (agent.rootPart.Position - rewardTarget).Magnitude
	if agent.lastRewardDistance then
		local delta = agent.lastRewardDistance - distance
		local reward = if isIndependentGoal then delta elseif agent.role == "Tagger" then delta else -delta
		agent.rewardTotal += math.clamp(reward, -2, 2) * 0.02
	end
	agent.lastRewardDistance = distance

	local planText = if agent.plan
		then `{if agent.plan.isPartial then "partial " else ""}plan #{agent.plan.id} edge {agent.planEdgeCursor}/{#agent.plan.edgeIds}, {math.floor(agent.plan.expectedTime * 100) / 100}s, {math.floor(agent.plan.successProbability * 100)}%, advantage {math.floor(agent.plan.opponentAdvantage * 10) / 10}, clearance {if agent.plan.minimumOpponentClearance == math.huge then "n/a" else tostring(math.floor(agent.plan.minimumOpponentClearance * 10) / 10)}, margin {if agent.plan.interceptionMargin == math.huge then "n/a" else tostring(math.floor(agent.plan.interceptionMargin * 10) / 10)}s`
	elseif agent.plannerJob
		then `planning #{agent.plannerJob.id}, {agent.plannerJob.expansions} expansions, {math.floor((os.clock() - agent.plannerJob.startedAt) * 1000)}ms`
		else "direct locomotion"
	local skill = agent.controller.result
	local learningText = if agent.explorer.enabled
		then `Learning: {agent.explorer.successes}/{agent.explorer.experiments} experiments; last {tostring(agent.explorer.lastAction)}`
		else "Learning: off"
	agent.thought = `{agent.role}: {agent.decision}\n{planText}\nSkill: {tostring(skill.action)} / {agent.controller.phase} / {skill.reason}\n{learningText}`
end

function BotAgent.destroy(agent: RAgent)
	BotStuckRecovery.cancel(agent.stuckRecovery, agent.character, agent.humanoid)
	clearPlan(agent, "Agent destroyed")
	if agent.character.Parent then agent.character:Destroy() end
end

return table.freeze(BotAgent)
