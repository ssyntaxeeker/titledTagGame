--!strict
--[[
    BotAffordanceBuilder (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Incrementally converts map surfaces into executable 3D movement
    transitions. Every non-walk edge carries the setup required by the skill
    controller and is validated against the same geometry rules at execution.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotMapModel = require(ReplicatedStorage.Modules.Bot.BotMapModel)
local MovementRules = require(ReplicatedStorage.Modules.Bot.BotMovementRules)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type ActionKind = Types.ActionKind
type RAffordanceEdge = Types.RAffordanceEdge
type RAffordanceGraph = Types.RAffordanceGraph
type RMapModel = Types.RMapModel
type RSurfaceNode = Types.RSurfaceNode
type RNeighborCandidate = {
	node: RSurfaceNode,
	distance: number,
	surfaceId: number,
}

export type RBuildJob = {
	graph: RAffordanceGraph,
	phase: "Primary" | "Truss" | "RollBoost" | "Done",
	nodeIndex: number,
	trussIndex: number,
	neighborIndex: number,
	neighbors: { RSurfaceNode },
	edgesCreated: number,
	candidatesChecked: number,
	done: boolean,
	status: string,
	raycastParams: RaycastParams,
	rollLandingNodes: { [number]: boolean },
}

local BotAffordanceBuilder = {}

local function addEdge(
	job: RBuildJob,
	fromNode: RSurfaceNode,
	toNode: RSurfaceNode,
	action: ActionKind,
	expectedTime: number,
	risk: number,
	approachPosition: Vector3,
	approachDirection: Vector3,
	lookTarget: Vector3?,
	contactPosition: Vector3?,
	targetPart: BasePart?,
	requiredHeight: number,
	requiredSpeed: number,
	timingMin: number,
	timingMax: number,
	requiresSlide: boolean?
)
	for _, edgeId in fromNode.edges do
		local existing = job.graph.edges[edgeId]
		if existing.to == toNode.id and existing.action == action then return end
	end

	local edge: RAffordanceEdge = {
		id = #job.graph.edges + 1,
		from = fromNode.id,
		to = toNode.id,
		action = action,
		expectedTime = math.max(0.05, expectedTime),
		baseCost = math.max(0.05, expectedTime) + risk * 0.35,
		successProbability = math.clamp(1 - risk, 0.15, 0.99),
		failureRisk = math.clamp(risk, 0.01, 0.9),
		setup = {
			approachPosition = approachPosition,
			approachDirection = approachDirection,
			lookTarget = lookTarget,
			contactPosition = contactPosition,
			targetPart = targetPart,
			requiredHeight = requiredHeight,
			requiredSpeed = requiredSpeed,
			timingMin = timingMin,
			timingMax = timingMax,
			requiresSlide = requiresSlide,
		},
	}
	job.graph.edges[edge.id] = edge
	fromNode.edges[#fromNode.edges + 1] = edge.id
	job.edgesCreated += 1
end

local function horizontalDirection(fromPosition: Vector3, toPosition: Vector3): (Vector3, number)
	local delta = toPosition - fromPosition
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude <= 0.01 then return Vector3.zAxis, 0 end
	return flat.Unit, flat.Magnitude
end

local function selectDirectionalNeighbors(model: RMapModel, fromNode: RSurfaceNode): { RSurfaceNode }
	local nearby = BotMapModel.findNodesInRadius(
		model,
		fromNode.rootPosition,
		math.max(Config.neighborRadius, Config.walkNeighborRadius),
		Config.affordanceNeighborCandidateLimit
	)
	local bestByKey: { [string]: RSurfaceNode } = {}
	local distanceByKey: { [string]: number } = {}
	local upperCandidatesByDirection: { [number]: { RNeighborCandidate } } = {}
	local function consider(key: string, candidate: RSurfaceNode, distance: number)
		if distance >= (distanceByKey[key] or math.huge) then return end
		bestByKey[key] = candidate
		distanceByKey[key] = distance
	end
	for _, candidate in nearby do
		if candidate.id == fromNode.id then continue end
		local delta = candidate.rootPosition - fromNode.rootPosition
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude <= 0.25 then continue end
		local angle = math.atan2(flat.Z, flat.X)
		local directionBucket = math.floor((angle + math.pi) / (math.pi / 4) + 0.5) % 8
		local verticalBand = if delta.Y > Config.defaultWalkStepHeight
			then "Up"
			elseif delta.Y < -Config.maxLearnableWalkStepHeight
			then "Down"
			else "Level"
		local key = `{verticalBand}:{directionBucket}`
		local distance = delta.Magnitude
		consider(key, candidate, distance)
		if verticalBand == "Up" then
			-- A single nearest upper node is often on trim or an unrelated step.
			-- Keep a bounded set of distinct surfaces for ledge validation.
			local surfaceId = model.partIds[candidate.surface] or 0
			local upperCandidates = upperCandidatesByDirection[directionBucket]
			if not upperCandidates then
				upperCandidates = {}
				upperCandidatesByDirection[directionBucket] = upperCandidates
			end
			local replaced = false
			for index, current in upperCandidates do
				if current.surfaceId ~= surfaceId then continue end
				if distance < current.distance then
					upperCandidates[index] = { node = candidate, distance = distance, surfaceId = surfaceId }
				end
				replaced = true
				break
			end
			if not replaced then
				upperCandidates[#upperCandidates + 1] = {
					node = candidate,
					distance = distance,
					surfaceId = surfaceId,
				}
			end
			table.sort(upperCandidates, function(a, b)
				return a.distance < b.distance
			end)
			if #upperCandidates > Config.upperSurfaceCandidatesPerDirection then
				table.remove(upperCandidates)
			end
		end

		local isSmallSurface = math.min(candidate.surface.Size.X, candidate.surface.Size.Z)
			<= Config.mapSmallSurfaceThreshold
		if isSmallSurface and delta.Y > Config.defaultWalkStepHeight then
			local actionBand = if delta.Y <= Config.maxJumpHeight
				then "Jump"
				elseif delta.Y <= Config.maxVaultHeight
				then "Vault"
				elseif delta.Y <= Config.maxSlideBoostHeight
				then "SlideBoost"
				else "TooHigh"
			if actionBand ~= "TooHigh" then
				consider(`Small:{actionBand}:{directionBucket}`, candidate, distance)
			end
		end
	end
	local selected = {}
	local selectedIds: { [number]: boolean } = {}
	for _, node in bestByKey do
		if selectedIds[node.id] then continue end
		selectedIds[node.id] = true
		selected[#selected + 1] = node
	end
	for _, upperCandidates in upperCandidatesByDirection do
		for _, candidate in upperCandidates do
			if selectedIds[candidate.node.id] then continue end
			selectedIds[candidate.node.id] = true
			selected[#selected + 1] = candidate.node
		end
	end
	return selected
end

local function hasWalkClearance(fromNode: RSurfaceNode, toNode: RSurfaceNode, params: RaycastParams): boolean
	local delta = toNode.rootPosition - fromNode.rootPosition
	local lower = Workspace:Raycast(fromNode.rootPosition + Vector3.yAxis * 0.4, delta, params)
	local upper = Workspace:Raycast(fromNode.rootPosition + Vector3.yAxis * 2.3, delta, params)
	return lower == nil and upper == nil
end

local function hasSlideClearance(fromNode: RSurfaceNode, toNode: RSurfaceNode, params: RaycastParams): boolean
	local delta = toNode.rootPosition - fromNode.rootPosition
	local lower = Workspace:Raycast(fromNode.rootPosition - Vector3.yAxis * 2, delta, params)
	local upper = Workspace:Raycast(fromNode.rootPosition - Vector3.yAxis * 0.75, delta, params)
	return lower == nil and upper == nil
end

local function hasWalkSupport(fromNode: RSurfaceNode, toNode: RSurfaceNode, params: RaycastParams): boolean
	if fromNode.surface == toNode.surface then return true end
	for sampleIndex = 1, 3 do
		local alpha = sampleIndex / 4
		local rootPosition = fromNode.rootPosition:Lerp(toNode.rootPosition, alpha)
		local floorHit = Workspace:Raycast(
			rootPosition,
			-Vector3.yAxis * Config.walkSupportProbeDepth,
			params
		)
		if not floorHit or floorHit.Normal.Y < Config.walkableNormalY then return false end
		local expectedFloorY = fromNode.floorPosition.Y
			+ (toNode.floorPosition.Y - fromNode.floorPosition.Y) * alpha
		if math.abs(floorHit.Position.Y - expectedFloorY) > Config.maxLearnableWalkStepHeight then return false end
	end
	return true
end

local function getTraversalClearance(fromNode: RSurfaceNode, toNode: RSurfaceNode, params: RaycastParams): number
	local minimumClearance = math.min(fromNode.clearance, toNode.clearance)
	for sampleIndex = 1, 3 do
		local alpha = sampleIndex / 4
		local floorPosition = fromNode.floorPosition:Lerp(toNode.floorPosition, alpha)
		local ceilingHit = Workspace:Raycast(
			floorPosition + Vector3.yAxis * 0.15,
			Vector3.yAxis * Config.bodyClearanceHeight,
			params
		)
		if ceilingHit then
			minimumClearance = math.min(minimumClearance, (ceilingHit.Position - floorPosition).Magnitude)
		end
	end
	return minimumClearance
end

local function getWallHit(fromNode: RSurfaceNode, direction: Vector3, distance: number, params: RaycastParams): RaycastResult?
	return Workspace:Raycast(fromNode.rootPosition + Vector3.yAxis * 1.3, direction * distance, params)
end

local function landingMatchesLedge(
	toNode: RSurfaceNode,
	ledgePosition: Vector3,
	direction: Vector3
): boolean
	if math.abs(toNode.floorPosition.Y - ledgePosition.Y) > Config.vaultLandingHeightTolerance then return false end
	local offset = toNode.floorPosition - ledgePosition
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	local depth = flatOffset:Dot(direction)
	local lateral = (flatOffset - direction * depth).Magnitude
	return depth >= -0.5
		and depth <= Config.vaultLandingMaximumDepth
		and lateral <= Config.vaultLandingLateralTolerance
end

local function buildCandidate(job: RBuildJob, fromNode: RSurfaceNode, toNode: RSurfaceNode)
	if fromNode.id == toNode.id then return end
	local heightDelta = toNode.floorPosition.Y - fromNode.floorPosition.Y
	local direction, flatDistance = horizontalDirection(fromNode.rootPosition, toNode.rootPosition)
	if flatDistance <= 0.5 or flatDistance > math.max(Config.neighborRadius, Config.walkNeighborRadius) then return end

	if fromNode.isTrampoline and heightDelta > 0 and heightDelta <= 72 and flatDistance <= 18 then
		addEdge(
			job,
			fromNode,
			toNode,
			"Trampoline",
			flatDistance / 42 + 0.55,
			0.12,
			fromNode.rootPosition,
			direction,
			toNode.rootPosition,
			toNode.floorPosition,
			fromNode.surface,
			heightDelta,
			0,
			0,
			0.5
		)
	end

	local walkHeightEligible = heightDelta >= -Config.maxLearnableWalkStepHeight
		and heightDelta <= Config.maxLearnableWalkStepHeight
		and flatDistance <= Config.walkNeighborRadius
	local dropHeightEligible = heightDelta < -Config.maxLearnableWalkStepHeight
		and math.abs(heightDelta) <= Config.maxDropHeight
	local jumpHeightEligible = heightDelta > Config.defaultWalkStepHeight
		and heightDelta <= Config.maxJumpHeight
		and flatDistance <= 8
	local walkClear = if walkHeightEligible or dropHeightEligible or jumpHeightEligible
		then hasWalkClearance(fromNode, toNode, job.raycastParams)
		else false
	if walkHeightEligible and walkClear and hasWalkSupport(fromNode, toNode, job.raycastParams) then
		local traversalClearance = getTraversalClearance(fromNode, toNode, job.raycastParams)
		local slopePenalty = math.abs(heightDelta) / math.max(1, flatDistance)
		local isUncertainUphillStep = heightDelta > Config.defaultWalkStepHeight
		if traversalClearance >= Config.runClearanceHeight then
			local walkRisk = if isUncertainUphillStep
				then math.clamp(0.65 + (heightDelta - Config.defaultWalkStepHeight) * 0.08, 0.65, 0.82)
				else 0.02
			addEdge(
				job,
				fromNode,
				toNode,
				"Walk",
				flatDistance / Config.botWalkSpeed + slopePenalty * 0.08,
				walkRisk,
				fromNode.rootPosition,
				direction,
				nil,
				toNode.floorPosition,
				nil,
				heightDelta,
				0,
				0,
				0
			)
			-- Above the default threshold, retain this as a learnable alternative
			-- while also creating the jump transition preferred by a fresh bot.
			if not isUncertainUphillStep then return end
		elseif traversalClearance >= Config.slideClearanceHeight
			and math.abs(heightDelta) <= Config.defaultWalkStepHeight
			and hasSlideClearance(fromNode, toNode, job.raycastParams)
		then
			addEdge(
				job,
				fromNode,
				toNode,
				"Walk",
				flatDistance / Config.botWalkSpeed + 0.18,
				0.12,
				fromNode.rootPosition,
				direction,
				nil,
				toNode.floorPosition,
				nil,
				heightDelta,
				0,
				0,
				0,
				true
			)
			return
		end
	end
	if flatDistance > Config.neighborRadius then return end

	if heightDelta < -Config.maxLearnableWalkStepHeight then
		if not dropHeightEligible or not walkClear then return end
		local rollEligible = math.abs(heightDelta) >= Config.minRollDropHeight
		local risk = math.clamp(math.abs(heightDelta) / Config.maxDropHeight * 0.35, 0.08, 0.5)
		addEdge(
			job,
			fromNode,
			toNode,
			"Drop",
			flatDistance / Config.botWalkSpeed + math.sqrt(2 * math.abs(heightDelta) / Workspace.Gravity),
			risk,
			fromNode.rootPosition,
			direction,
			toNode.rootPosition,
			toNode.floorPosition,
			toNode.surface,
			heightDelta,
			if rollEligible then Config.rollRequiredFallSpeed else 0,
			0,
			0.7
		)
		if rollEligible then job.rollLandingNodes[toNode.id] = true end
		return
	end

	if heightDelta <= 0 then return end
	if heightDelta > Config.maxSlideBoostHeight then return end
	local hasOverheadClearance = MovementRules.hasOverheadClearance(
		fromNode.rootPosition,
		heightDelta,
		{},
		{ job.graph.mapModel.mapRoot }
	)
	local vaultHeightEligible = heightDelta >= Config.groundVaultMinHeight and heightDelta <= Config.maxVaultHeight
	local slideBoostHeightEligible = heightDelta >= Config.slideBoostMinHeight
		and heightDelta <= Config.maxSlideBoostHeight
	local wallHit = if vaultHeightEligible or slideBoostHeightEligible
		then getWallHit(fromNode, direction, math.min(flatDistance, 12), job.raycastParams)
		else nil
	local wallIsClimbable = wallHit ~= nil
		and math.abs((wallHit :: RaycastResult).Normal.Y) <= Config.climbWallNormalY
		and (wallHit :: RaycastResult).Normal:Dot(direction) <= -0.5
		and not MovementRules.isBarrier((wallHit :: RaycastResult).Instance)
		and (wallHit :: RaycastResult).Instance:GetAttribute("NoClimb") ~= true
	local vaultProbe = if vaultHeightEligible
		then MovementRules.probeVault(fromNode.rootPosition, direction, {})
		else nil
	if vaultProbe and hasOverheadClearance then
		local vaultAction: ActionKind? = if heightDelta >= Config.groundVaultMinHeight
			and heightDelta <= Config.groundVaultMaxHeight
			then "Vault"
			elseif heightDelta > Config.highVaultMinHeight and heightDelta <= Config.maxVaultHeight
			then "HighVault"
			else nil
		if vaultAction
			and vaultProbe.result.Instance:IsA("BasePart")
			and landingMatchesLedge(
				toNode,
				vaultProbe.result.Position,
				direction
			)
		then
			local jumpSetupRisk = math.clamp((heightDelta - Config.groundVaultMaxHeight) / 12, 0, 0.35)
			addEdge(
				job,
				fromNode,
				toNode,
				vaultAction,
				flatDistance / Config.botWalkSpeed + 0.18 + jumpSetupRisk,
				0.1 + jumpSetupRisk,
				fromNode.rootPosition,
				direction,
				vaultProbe.result.Position,
				toNode.floorPosition,
				vaultProbe.result.Instance,
				heightDelta,
				if heightDelta > Config.groundVaultMaxHeight then 24 else 0,
				0.08,
				0.35
			)
		end
	end
	local wallVaultAction: ActionKind? = if heightDelta >= Config.groundVaultMinHeight
		and heightDelta <= Config.groundVaultMaxHeight
		then "Vault"
		elseif heightDelta > Config.highVaultMinHeight and heightDelta <= Config.maxVaultHeight
		then "HighVault"
		else nil
	if wallIsClimbable and wallVaultAction and hasOverheadClearance then
		local validWallHit = wallHit :: RaycastResult
		local landingProbeOrigin = Vector3.new(
			validWallHit.Position.X,
			toNode.floorPosition.Y + 2,
			validWallHit.Position.Z
		) + direction * Config.vaultLandingInset
		local landingHit = Workspace:Raycast(
			landingProbeOrigin,
			-Vector3.yAxis * 4,
			job.raycastParams
		)
		if landingHit
			and landingHit.Instance:IsA("BasePart")
			and landingMatchesLedge(
				toNode,
				landingHit.Position,
				direction
			)
		then
			local jumpSetupRisk = math.clamp((heightDelta - Config.groundVaultMaxHeight) / 12, 0, 0.35)
			local approachPosition = validWallHit.Position - direction * Config.wallApproachDistance
			addEdge(
			job,
			fromNode,
			toNode,
			wallVaultAction,
			flatDistance / Config.botWalkSpeed + 0.18 + jumpSetupRisk,
			0.12 + jumpSetupRisk,
			Vector3.new(approachPosition.X, fromNode.rootPosition.Y, approachPosition.Z),
			direction,
			landingHit.Position,
			toNode.floorPosition,
			landingHit.Instance :: BasePart,
			heightDelta,
			if heightDelta > Config.groundVaultMaxHeight then 24 else 0,
			0.08,
			0.35
			)
		end
	end

	local shouldProbeSwing = false
	if heightDelta <= Config.maxSlideBoostHeight then
		for _, swingBar in job.graph.mapModel.swingBars do
			local barDelta = swingBar.Position - fromNode.rootPosition
			local flatBarDelta = Vector3.new(barDelta.X, 0, barDelta.Z)
			if flatBarDelta.Magnitude > Config.swingAffordanceProbeRadius then continue end
			if barDelta.Y < 0 or barDelta.Y > Config.bodyClearanceHeight + 4 then continue end
			if flatBarDelta.Magnitude > 0.01 and flatBarDelta.Unit:Dot(direction) >= 0.35 then
				shouldProbeSwing = true
				break
			end
		end
	end
	local swingProbe = if shouldProbeSwing
		then MovementRules.probeSwing(fromNode.rootPosition, direction, {})
		else nil
	if swingProbe and heightDelta <= Config.maxSlideBoostHeight and hasOverheadClearance then
		addEdge(
			job,
			fromNode,
			toNode,
			"Swing",
			flatDistance / 42 + 0.45,
			0.22,
			fromNode.rootPosition,
			direction,
			swingProbe.Position,
			swingProbe.Position,
			swingProbe.Instance,
			heightDelta,
			25,
			0.32,
			0.5
		)
	end

	if wallIsClimbable
		and hasOverheadClearance
		and slideBoostHeightEligible
		and flatDistance >= 5
	then
		local validWallHit = wallHit :: RaycastResult
		local minimumRunupDistance = Config.slideBoostJumpWallDistance
			+ Config.botWalkSpeed * (Config.slideHoldMin + Config.slideJumpDelayDefault)
		local runupDistance = Config.botWalkSpeed
			* (Config.slideHoldDefault + Config.slideJumpDelayDefault)
			+ Config.slideBoostRunupPadding
		local selectedRunupDistance = math.max(minimumRunupDistance, runupDistance)
		local approachPosition = validWallHit.Position - direction * selectedRunupDistance
		local slideGroundLength = Config.botWalkSpeed * (Config.slideHoldMax + Config.slideJumpDelayMax)
		local slideStartPosition = Vector3.new(
			approachPosition.X,
			fromNode.rootPosition.Y,
			approachPosition.Z
		)
		if MovementRules.hasFlatSlideBoostGround(
			slideStartPosition,
			direction,
			slideGroundLength,
			fromNode.floorPosition.Y,
			job.raycastParams
		) then
			local risk = math.clamp(0.22 + math.abs(heightDelta - 12) * 0.06, 0.22, 0.65)
			addEdge(
				job,
				fromNode,
				toNode,
				"SlideBoost",
				flatDistance / Config.botWalkSpeed + 0.65,
				risk,
				slideStartPosition,
				direction,
				validWallHit.Position,
				toNode.floorPosition,
				toNode.surface,
				heightDelta,
				28,
				Config.slideHoldMin,
				Config.slideHoldMax
			)
		end
	end

	if jumpHeightEligible and walkClear and hasOverheadClearance then
		addEdge(
			job,
			fromNode,
			toNode,
			"Jump",
			flatDistance / Config.botWalkSpeed + 0.24,
			0.18,
			fromNode.rootPosition,
			direction,
			toNode.rootPosition,
			toNode.floorPosition,
			toNode.surface,
			heightDelta,
			20,
			0,
			0.2
		)
	end
end

local function buildRollBoostCandidate(job: RBuildJob, fromNode: RSurfaceNode, toNode: RSurfaceNode)
	if not job.rollLandingNodes[fromNode.id] or fromNode.id == toNode.id then return end
	local heightDelta = toNode.floorPosition.Y - fromNode.floorPosition.Y
	local direction, flatDistance = horizontalDirection(fromNode.rootPosition, toNode.rootPosition)
	if heightDelta <= 0 or heightDelta > 16 or flatDistance > 12 then return end
	if not hasWalkClearance(fromNode, toNode, job.raycastParams) then return end
	addEdge(
		job,
		fromNode,
		toNode,
		"RollBoost",
		flatDistance / (Config.botWalkSpeed * 1.3) + Config.rollBoostDelayDefault,
		0.28,
		fromNode.rootPosition,
		direction,
		toNode.rootPosition,
		toNode.floorPosition,
		toNode.surface,
		heightDelta,
		28,
		Config.rollBoostDelayMin,
		Config.rollBoostDelayMax
	)
end

local function buildTrussCandidate(job: RBuildJob, truss: TrussPart)
	if not truss.Parent or math.abs(truss.CFrame.UpVector.Y) < Config.walkableNormalY then return end
	local halfHeight = truss.Size.Y * 0.5
	local bottomPosition = truss.Position - truss.CFrame.UpVector * halfHeight
	local topPosition = truss.Position + truss.CFrame.UpVector * halfHeight
	local bottomNodes = BotMapModel.findNodesInRadius(
		job.graph.mapModel,
		bottomPosition + Vector3.yAxis * Config.rootFloorOffset,
		Config.trussNodeSearchRadius,
		Config.trussNodeCandidateLimit
	)
	local topNodes = BotMapModel.findNodesInRadius(
		job.graph.mapModel,
		topPosition + Vector3.yAxis * Config.rootFloorOffset,
		Config.trussNodeSearchRadius,
		Config.trussNodeCandidateLimit
	)
	local bottomNode: RSurfaceNode? = nil
	local topNode: RSurfaceNode? = nil
	local bottomScore = math.huge
	local topScore = math.huge
	for _, node in bottomNodes do
		local heightError = math.abs(node.floorPosition.Y - bottomPosition.Y)
		local flatDelta = Vector3.new(node.rootPosition.X - truss.Position.X, 0, node.rootPosition.Z - truss.Position.Z)
		if heightError > Config.trussLandingHeightTolerance
			or flatDelta.Magnitude > Config.trussLandingHorizontalTolerance
		then
			continue
		end
		local score = flatDelta.Magnitude + heightError * 1.5
		if score < bottomScore then
			bottomScore = score
			bottomNode = node
		end
	end
	for _, node in topNodes do
		local heightError = math.abs(node.floorPosition.Y - topPosition.Y)
		local flatDelta = Vector3.new(node.rootPosition.X - truss.Position.X, 0, node.rootPosition.Z - truss.Position.Z)
		if heightError > Config.trussLandingHeightTolerance
			or flatDelta.Magnitude > Config.trussLandingHorizontalTolerance
		then
			continue
		end
		local score = flatDelta.Magnitude + heightError * 1.5
		if score < topScore then
			topScore = score
			topNode = node
		end
	end
	if not bottomNode or not topNode or bottomNode.id == topNode.id then return end
	local heightDelta = topNode.floorPosition.Y - bottomNode.floorPosition.Y
	if heightDelta <= Config.defaultWalkStepHeight then return end
	local direction, flatDistance = horizontalDirection(bottomNode.rootPosition, truss.Position)
	if flatDistance > Config.trussNodeSearchRadius then return end
	addEdge(
		job,
		bottomNode,
		topNode,
		"TrussClimb",
		heightDelta / Config.trussExpectedVerticalSpeed + flatDistance / Config.botWalkSpeed,
		0.25,
		bottomNode.rootPosition,
		direction,
		truss.Position,
		topNode.floorPosition,
		truss,
		heightDelta,
		0,
		0,
		0
	)
end

function BotAffordanceBuilder.createBuildJob(model: RMapModel): RBuildJob
	assert(model.ready, "[BotAffordanceBuilder.createBuildJob] map model must be ready")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model.mapRoot }
	params.IgnoreWater = true
	params.RespectCanCollide = true

	return {
		graph = {
			mapModel = model,
			edges = {},
			ready = false,
			buildVersion = model.buildVersion,
		},
		phase = "Primary",
		nodeIndex = 1,
		trussIndex = 1,
		neighborIndex = 1,
		neighbors = {},
		edgesCreated = 0,
		candidatesChecked = 0,
		done = false,
		status = "Preparing affordances",
		raycastParams = params,
		rollLandingNodes = {},
	}
end

function BotAffordanceBuilder.stepBuild(job: RBuildJob, budgetSeconds: number?): boolean
	if job.done then return true end
	local startedAt = os.clock()
	local budget = budgetSeconds or Config.affordanceBuildBudgetSeconds
	local nodes = job.graph.mapModel.nodes

	while os.clock() - startedAt < budget do
		if job.phase == "Truss" then
			local truss = job.graph.mapModel.trusses[job.trussIndex]
			if truss then
				buildTrussCandidate(job, truss)
				job.trussIndex += 1
				job.status = `Truss affordances {job.trussIndex - 1}/{#job.graph.mapModel.trusses} | {job.edgesCreated} transitions`
				continue
			end
			job.phase = "RollBoost"
			job.nodeIndex = 1
			job.neighborIndex = 1
			job.neighbors = {}
			continue
		end
		if job.nodeIndex > #nodes then
			if job.phase == "Primary" then
				job.phase = "Truss"
				job.trussIndex = 1
				job.neighborIndex = 1
				job.neighbors = {}
				continue
			end
			job.phase = "Done"
			job.graph.ready = true
			job.done = true
			job.status = `Graph ready: {#nodes} nodes, {#job.graph.edges} transitions`
			return true
		end

		local fromNode = nodes[job.nodeIndex]
		if job.phase == "RollBoost" and not job.rollLandingNodes[fromNode.id] then
			job.nodeIndex += 1
			job.neighbors = {}
			job.neighborIndex = 1
			continue
		end
		if #job.neighbors == 0 then
			job.neighbors = selectDirectionalNeighbors(job.graph.mapModel, fromNode)
			job.neighborIndex = 1
		end

		local toNode = job.neighbors[job.neighborIndex]
		if toNode then
			if job.phase == "Primary" then
				buildCandidate(job, fromNode, toNode)
			else
				buildRollBoostCandidate(job, fromNode, toNode)
			end
			job.candidatesChecked += 1
			job.neighborIndex += 1
		else
			job.nodeIndex += 1
			job.neighbors = {}
			job.neighborIndex = 1
		end
		job.status = `{job.phase} affordances {job.nodeIndex}/{#nodes} | {job.edgesCreated} transitions`
	end

	return false
end

function BotAffordanceBuilder.getEdge(graph: RAffordanceGraph, fromNodeId: number, toNodeId: number): RAffordanceEdge?
	local node = graph.mapModel.nodes[fromNodeId]
	if not node then return nil end
	for _, edgeId in node.edges do
		local edge = graph.edges[edgeId]
		if edge.to == toNodeId then return edge end
	end
	return nil
end

return table.freeze(BotAffordanceBuilder)
