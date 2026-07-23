--!strict
--[[
    NavigationMesh (Shared)
    =======================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Standalone, frame-budgeted graph navigation for static Roblox maps. The
    builder samples real part surfaces, indexes nodes in a 3D spatial hash,
    validates walk and jump transitions, and links nearby floors without using
    PathfindingService. Games can add movement rules without modifying this
    module. Search uses incremental A* and never needs to finish an entire
    route in one frame.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

export type EdgeKind = string

export type RNavEdge = {
	to: number,
	cost: number,
	kind: EdgeKind,
	metadata: { [string]: any }?,
}

export type RNavNode = {
	id: number,
	position: Vector3,
	floorPosition: Vector3,
	surface: BasePart,
	edges: { RNavEdge },
}

export type RMovementTransition = {
	kind: EdgeKind,
	cost: number,
	metadata: { [string]: any }?,
}

export type IMovementRule = {
	maximumDistance: number,
	evaluate: (fromNode: RNavNode, toNode: RNavNode) -> RMovementTransition?,
}

type BucketByZ = { [number]: { number } }
type BucketByY = { [number]: BucketByZ }
type Buckets = { [number]: BucketByY }

type BuildSettings = {
	step: number,
	precisionStep: number,
	precisionTag: string,
	maximumNodes: number,
	maximumSamplesPerPart: number,
	minimumNodeSpacing: number,
	bucketSize: number,
	walkableNormalY: number,
	agentHeight: number,
	agentRadius: number,
	rootFloorOffset: number,
	maximumWalkStepUp: number,
	maximumWalkDropDown: number,
	maximumWalkDistance: number,
	maximumJumpUp: number,
	maximumJumpDown: number,
	maximumJumpDistance: number,
	jumpArcHeight: number,
	jumpArcSegments: number,
	jumpCostMultiplier: number,
	maximumCandidateDistance: number,
	sampleProbeHeight: number,
	validateOccupancy: boolean,
	requireAnchored: boolean,
	includePart: ((part: BasePart) -> boolean)?,
	movementRules: { IMovementRule },
}

export type RBuildStats = {
	partsVisited: number,
	walkableParts: number,
	samples: number,
	nodes: number,
	edges: number,
	rejectedOccupied: number,
	rejectedBlocked: number,
}

export type RNavigationMesh = {
	root: Instance,
	nodes: { RNavNode },
	ready: boolean,
	version: number,
	stats: RBuildStats,
	_settings: BuildSettings,
	_buckets: Buckets,
	_raycastParams: RaycastParams,
	_overlapParams: OverlapParams,
}

export type BuildParams = {
	root: Instance,
	step: number?,
	precisionStep: number?,
	precisionTag: string?,
	maximumNodes: number?,
	maximumSamplesPerPart: number?,
	minimumNodeSpacing: number?,
	walkableNormalY: number?,
	agentHeight: number?,
	agentRadius: number?,
	rootFloorOffset: number?,
	maximumWalkStepUp: number?,
	maximumWalkDropDown: number?,
	maximumWalkDistance: number?,
	maximumJumpUp: number?,
	maximumJumpDown: number?,
	maximumJumpDistance: number?,
	jumpArcHeight: number?,
	jumpArcSegments: number?,
	jumpCostMultiplier: number?,
	sampleProbeHeight: number?,
	validateOccupancy: boolean?,
	requireAnchored: boolean?,
	includePart: ((part: BasePart) -> boolean)?,
	movementRules: { IMovementRule }?,
}

export type RBuildJob = {
	mesh: RNavigationMesh,
	phase: "Collect" | "Sample" | "Link" | "Done" | "Cancelled",
	stack: { Instance },
	parts: { BasePart },
	partIndex: number,
	partInitialized: boolean,
	xIndex: number,
	zIndex: number,
	xCount: number,
	zCount: number,
	xStart: number,
	zStart: number,
	xSpan: number,
	zSpan: number,
	linkNodeIndex: number,
	linkCandidates: { number },
	linkCandidateIndex: number,
	done: boolean,
}

export type RWaypoint = {
	nodeId: number,
	position: Vector3,
	kind: EdgeKind,
	metadata: { [string]: any }?,
}

export type RPath = {
	nodeIds: { number },
	waypoints: { RWaypoint },
	cost: number,
	reachedGoal: boolean,
	expansions: number,
}

export type SearchParams = {
	startRadius: number?,
	goalRadius: number?,
	maximumExpansions: number?,
	heuristicWeight: number?,
	allowPartial: boolean?,
	simplifyDirectionDot: number?,
	edgeCost: ((edge: RNavEdge, fromNode: RNavNode, toNode: RNavNode) -> number?)?,
}

type HeapEntry = {
	id: number,
	score: number,
}

export type RSearchJob = {
	mesh: RNavigationMesh,
	startId: number,
	goalId: number,
	open: { HeapEntry },
	bestOpenScore: { [number]: number },
	cameFrom: { [number]: number },
	cameEdge: { [number]: RNavEdge },
	cost: { [number]: number },
	closed: { [number]: boolean },
	expansions: number,
	maximumExpansions: number,
	heuristicWeight: number,
	allowPartial: boolean,
	simplifyDirectionDot: number,
	edgeCost: ((edge: RNavEdge, fromNode: RNavNode, toNode: RNavNode) -> number?)?,
	bestId: number,
	bestDistance: number,
	activeNodeId: number?,
	activeEdgeIndex: number,
	phase: "Search" | "Reconstruct" | "Reverse" | "Compact" | "Done" | "Cancelled",
	reachedGoal: boolean,
	reconstructId: number?,
	reverseNodeIds: { number },
	reverseIndex: number,
	nodeIds: { number },
	compactIndex: number,
	waypoints: { RWaypoint },
	result: RPath?,
	done: boolean,
	failed: boolean,
}

local DEFAULTS = table.freeze({
	step = 4,
	precisionStep = 1,
	precisionTag = "NavigationPrecisionSurface",
	maximumNodes = 12000,
	maximumSamplesPerPart = 900,
	minimumNodeSpacing = 1.5,
	walkableNormalY = 0.72,
	agentHeight = 5,
	agentRadius = 1.25,
	rootFloorOffset = 2.75,
	maximumWalkStepUp = 1.5,
	maximumWalkDropDown = 2,
	maximumJumpUp = 6,
	maximumJumpDown = 8,
	maximumJumpDistance = 8,
	jumpArcHeight = 5,
	jumpArcSegments = 4,
	jumpCostMultiplier = 1.15,
	sampleProbeHeight = 1.5,
	validateOccupancy = true,
	requireAnchored = true,
})

local NavigationMesh = {}

local function positive(value: number?, fallback: number, name: string): number
	local resolved = if value == nil then fallback else value
	assert(resolved > 0 and resolved < math.huge, `[NavigationMesh] {name} must be finite and positive`)
	return resolved
end

local function getBucket(buckets: Buckets, x: number, y: number, z: number, create: boolean): { number }?
	local byY = buckets[x]
	if not byY then
		if not create then return nil end
		byY = {}
		buckets[x] = byY
	end
	local byZ = byY[y]
	if not byZ then
		if not create then return nil end
		byZ = {}
		byY[y] = byZ
	end
	local bucket = byZ[z]
	if not bucket and create then
		bucket = {}
		byZ[z] = bucket
	end
	return bucket
end

local function cell(position: Vector3, bucketSize: number): (number, number, number)
	return math.floor(position.X / bucketSize), math.floor(position.Y / bucketSize), math.floor(position.Z / bucketSize)
end

local function isBarrier(part: BasePart, root: Instance): boolean
	local current: Instance? = part
	while current and current ~= root.Parent do
		if current.Name == "Barriers" or current:GetAttribute("NavigationBlocked") == true then return true end
		current = current.Parent
	end
	return false
end

local function isWalkablePart(part: BasePart, root: Instance, settings: BuildSettings): boolean
	if not part.CanCollide or part.Name == "SpawnLocation" then return false end
	if settings.requireAnchored and not part.Anchored then return false end
	if part.CFrame.UpVector.Y < settings.walkableNormalY or isBarrier(part, root) then return false end
	if settings.includePart and not settings.includePart(part) then return false end
	return true
end

local function nearbyNode(mesh: RNavigationMesh, position: Vector3, radius: number): boolean
	local bucketRadius = math.ceil(radius / mesh._settings.bucketSize)
	local centerX, centerY, centerZ = cell(position, mesh._settings.bucketSize)
	for x = centerX - bucketRadius, centerX + bucketRadius do
		for y = centerY - bucketRadius, centerY + bucketRadius do
			for z = centerZ - bucketRadius, centerZ + bucketRadius do
				local bucket = getBucket(mesh._buckets, x, y, z, false)
				if not bucket then continue end
				for _, nodeId in bucket do
					if (mesh.nodes[nodeId].position - position).Magnitude < radius then return true end
				end
			end
		end
	end
	return false
end

local function insertNode(mesh: RNavigationMesh, hit: RaycastResult): boolean
	local settings = mesh._settings
	if #mesh.nodes >= settings.maximumNodes then return false end
	if hit.Normal.Y < settings.walkableNormalY or not hit.Instance:IsA("BasePart") then return false end
	local surface = hit.Instance :: BasePart
	if not isWalkablePart(surface, mesh.root, settings) then return false end
	local rootPosition = hit.Position + Vector3.yAxis * settings.rootFloorOffset
	if nearbyNode(mesh, rootPosition, settings.minimumNodeSpacing) then return false end

	if settings.validateOccupancy then
		local bodyCenter = hit.Position + Vector3.yAxis * (settings.agentHeight * 0.5 + 0.2)
		local bodySize = Vector3.new(settings.agentRadius * 2, settings.agentHeight - 0.4, settings.agentRadius * 2)
		for _, overlap in Workspace:GetPartBoundsInBox(CFrame.new(bodyCenter), bodySize, mesh._overlapParams) do
			if overlap ~= surface and overlap.CanCollide then
				mesh.stats.rejectedOccupied += 1
				return false
			end
		end
	end

	local node: RNavNode = {
		id = #mesh.nodes + 1,
		position = rootPosition,
		floorPosition = hit.Position,
		surface = surface,
		edges = {},
	}
	mesh.nodes[node.id] = node
	local x, y, z = cell(rootPosition, settings.bucketSize)
	local bucket = getBucket(mesh._buckets, x, y, z, true)
	assert(bucket, "[NavigationMesh.insertNode] failed creating spatial bucket")
	bucket[#bucket + 1] = node.id
	mesh.stats.nodes = #mesh.nodes
	return true
end

local function initializePart(job: RBuildJob, part: BasePart)
	local settings = job.mesh._settings
	local precision = settings.precisionTag ~= "" and CollectionService:HasTag(part, settings.precisionTag)
		or math.min(part.Size.X, part.Size.Z) <= settings.step
	local step = if precision then settings.precisionStep else settings.step
	local xInset = math.min(settings.agentRadius, part.Size.X * 0.5)
	local zInset = math.min(settings.agentRadius, part.Size.Z * 0.5)
	local xSpan = math.max(0, part.Size.X - xInset * 2)
	local zSpan = math.max(0, part.Size.Z - zInset * 2)

	local function counts(sampleStep: number): (number, number)
		local xCount = if xSpan <= 0 then 1 else math.max(2, math.ceil(xSpan / sampleStep) + 1)
		local zCount = if zSpan <= 0 then 1 else math.max(2, math.ceil(zSpan / sampleStep) + 1)
		return xCount, zCount
	end

	local xCount, zCount = counts(step)
	local estimatedSamples = xCount * zCount
	if estimatedSamples > settings.maximumSamplesPerPart then
		step *= math.sqrt(estimatedSamples / settings.maximumSamplesPerPart)
		xCount, zCount = counts(step)
	end

	job.xIndex = 0
	job.zIndex = 0
	job.xCount = xCount
	job.zCount = zCount
	job.xStart = -part.Size.X * 0.5 + xInset
	job.zStart = -part.Size.Z * 0.5 + zInset
	job.xSpan = xSpan
	job.zSpan = zSpan
	job.partInitialized = true
end

local function samplePart(job: RBuildJob, part: BasePart): boolean
	if not job.partInitialized then initializePart(job, part) end
	local xAlpha = if job.xCount <= 1 then 0.5 else job.xIndex / (job.xCount - 1)
	local zAlpha = if job.zCount <= 1 then 0.5 else job.zIndex / (job.zCount - 1)
	local localPosition = Vector3.new(
		job.xStart + job.xSpan * xAlpha,
		part.Size.Y * 0.5,
		job.zStart + job.zSpan * zAlpha
	)
	local surfacePosition = part.CFrame:PointToWorldSpace(localPosition)
	local probeHeight = job.mesh._settings.sampleProbeHeight
	local hit = Workspace:Raycast(
		surfacePosition + Vector3.yAxis * probeHeight,
		-Vector3.yAxis * (probeHeight * 2 + 0.5),
		job.mesh._raycastParams
	)
	job.mesh.stats.samples += 1
	if hit and hit.Instance == part then insertNode(job.mesh, hit) end

	job.xIndex += 1
	if job.xIndex < job.xCount then return false end
	job.xIndex = 0
	job.zIndex += 1
	return job.zIndex >= job.zCount
end

local function collectNearbyNodeIds(mesh: RNavigationMesh, node: RNavNode, radius: number): { number }
	local result = {}
	local bucketRadius = math.ceil(radius / mesh._settings.bucketSize)
	local centerX, centerY, centerZ = cell(node.position, mesh._settings.bucketSize)
	for x = centerX - bucketRadius, centerX + bucketRadius do
		for y = centerY - bucketRadius, centerY + bucketRadius do
			for z = centerZ - bucketRadius, centerZ + bucketRadius do
				local bucket = getBucket(mesh._buckets, x, y, z, false)
				if not bucket then continue end
				for _, candidateId in bucket do
					if candidateId > node.id then result[#result + 1] = candidateId end
				end
			end
		end
	end
	return result
end

local function walkCorridorClear(mesh: RNavigationMesh, fromNode: RNavNode, toNode: RNavNode): boolean
	local settings = mesh._settings
	local delta = toNode.position - fromNode.position
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude < 0.05 then return false end
	local bodySize = Vector3.new(settings.agentRadius * 1.6, settings.agentHeight - 0.5, settings.agentRadius * 1.6)
	if Workspace:Blockcast(CFrame.new(fromNode.position), bodySize, delta, mesh._raycastParams) then
		mesh.stats.rejectedBlocked += 1
		return false
	end

	local midpointFloor = fromNode.floorPosition:Lerp(toNode.floorPosition, 0.5)
	local supportOrigin = midpointFloor + Vector3.yAxis * (settings.maximumWalkStepUp + 0.75)
	local support = Workspace:Raycast(
		supportOrigin,
		-Vector3.yAxis * (settings.maximumWalkStepUp + settings.maximumWalkDropDown + 1.5),
		mesh._raycastParams
	)
	if not support or support.Normal.Y < settings.walkableNormalY then return false end
	return math.abs(support.Position.Y - midpointFloor.Y)
		<= math.max(settings.maximumWalkStepUp, settings.maximumWalkDropDown) + 0.5
end

local function jumpArcClear(mesh: RNavigationMesh, fromNode: RNavNode, toNode: RNavNode): boolean
	local settings = mesh._settings
	local bodySize = Vector3.new(settings.agentRadius * 1.6, settings.agentHeight - 0.5, settings.agentRadius * 1.6)
	local previous = fromNode.position
	for segment = 1, settings.jumpArcSegments do
		local alpha = segment / settings.jumpArcSegments
		local linear = fromNode.position:Lerp(toNode.position, alpha)
		local arcOffset = settings.jumpArcHeight * 4 * alpha * (1 - alpha)
		local current = linear + Vector3.yAxis * arcOffset
		if Workspace:Blockcast(CFrame.new(previous), bodySize, current - previous, mesh._raycastParams) then
			mesh.stats.rejectedBlocked += 1
			return false
		end
		previous = current
	end
	return true
end

local function addDirectedEdgeInternal(
	mesh: RNavigationMesh,
	fromId: number,
	toId: number,
	cost: number,
	kind: EdgeKind,
	metadata: { [string]: any }?
): boolean
	local fromNode = mesh.nodes[fromId]
	local toNode = mesh.nodes[toId]
	assert(fromNode and toNode, "[NavigationMesh.addDirectedEdge] node id is outside the mesh")
	assert(cost >= 0 and cost < math.huge, "[NavigationMesh.addDirectedEdge] cost must be finite and non-negative")
	for _, edge in fromNode.edges do
		if edge.to == toId and edge.kind == kind then
			if cost < edge.cost then
				edge.cost = cost
				edge.metadata = metadata
			end
			return false
		end
	end
	fromNode.edges[#fromNode.edges + 1] = { to = toId, cost = cost, kind = kind, metadata = metadata }
	mesh.stats.edges += 1
	return true
end

local function tryBuiltInDirection(mesh: RNavigationMesh, fromNode: RNavNode, toNode: RNavNode, walkClear: boolean)
	local settings = mesh._settings
	local delta = toNode.position - fromNode.position
	local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local rise = toNode.floorPosition.Y - fromNode.floorPosition.Y
	local canWalk = flatDistance <= settings.maximumWalkDistance
		and rise <= settings.maximumWalkStepUp
		and rise >= -settings.maximumWalkDropDown
	if canWalk and walkClear then
		addDirectedEdgeInternal(mesh, fromNode.id, toNode.id, delta.Magnitude, "Walk", nil)
		return
	end
	local canJump = flatDistance <= settings.maximumJumpDistance
		and rise <= settings.maximumJumpUp
		and rise >= -settings.maximumJumpDown
	if canJump and jumpArcClear(mesh, fromNode, toNode) then
		addDirectedEdgeInternal(
			mesh,
			fromNode.id,
			toNode.id,
			delta.Magnitude * settings.jumpCostMultiplier,
			"Jump",
			{ arcHeight = settings.jumpArcHeight }
		)
	end
end

local function tryCustomDirection(
	mesh: RNavigationMesh,
	rule: IMovementRule,
	fromNode: RNavNode,
	toNode: RNavNode
)
	local transition = rule.evaluate(fromNode, toNode)
	if not transition then return end
	assert(transition.kind ~= "", "[NavigationMesh] movement rule returned an empty kind")
	addDirectedEdgeInternal(
		mesh,
		fromNode.id,
		toNode.id,
		transition.cost,
		transition.kind,
		transition.metadata
	)
end

local function tryLink(mesh: RNavigationMesh, fromNode: RNavNode, toNode: RNavNode)
	local settings = mesh._settings
	local delta = toNode.position - fromNode.position
	local distance = delta.Magnitude
	local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if distance > settings.maximumCandidateDistance or flatDistance < settings.minimumNodeSpacing * 0.35 then return end
	local rise = toNode.floorPosition.Y - fromNode.floorPosition.Y
	local eitherDirectionWalkable = (rise <= settings.maximumWalkStepUp and rise >= -settings.maximumWalkDropDown)
		or (-rise <= settings.maximumWalkStepUp and -rise >= -settings.maximumWalkDropDown)
	local walkClear = flatDistance <= settings.maximumWalkDistance
		and eitherDirectionWalkable
		and walkCorridorClear(mesh, fromNode, toNode)
	tryBuiltInDirection(mesh, fromNode, toNode, walkClear)
	tryBuiltInDirection(mesh, toNode, fromNode, walkClear)

	for _, rule in settings.movementRules do
		if distance > rule.maximumDistance then continue end
		tryCustomDirection(mesh, rule, fromNode, toNode)
		tryCustomDirection(mesh, rule, toNode, fromNode)
	end
end

local function heapPush(heap: { HeapEntry }, entry: HeapEntry)
	heap[#heap + 1] = entry
	local index = #heap
	while index > 1 do
		local parent = math.floor(index / 2)
		if heap[parent].score <= entry.score then break end
		heap[index] = heap[parent]
		index = parent
	end
	heap[index] = entry
end

local function heapPop(heap: { HeapEntry }): HeapEntry?
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

local function heuristic(mesh: RNavigationMesh, fromId: number, goalId: number): number
	return (mesh.nodes[goalId].position - mesh.nodes[fromId].position).Magnitude
end

local function beginReconstruction(job: RSearchJob, endId: number, reachedGoal: boolean)
	if not reachedGoal and (not job.allowPartial or endId == job.startId) then
		job.done = true
		job.failed = true
		job.phase = "Done"
		return
	end
	job.reachedGoal = reachedGoal
	job.reconstructId = endId
	job.phase = "Reconstruct"
end

local function finishPath(job: RSearchJob)
	job.result = {
		nodeIds = job.nodeIds,
		waypoints = job.waypoints,
		cost = job.cost[job.nodeIds[#job.nodeIds]] or 0,
		reachedGoal = job.reachedGoal,
		expansions = job.expansions,
	}
	job.done = true
	job.phase = "Done"
end

--[=[
    @tag Shared

    createBuildJob
    ==============

    Creates an incremental static-map build. The returned job owns its mesh;
    repeatedly call `stepBuild` from Heartbeat or a task until it returns true.
    No descendants are modified and no Instances are created.

    @error "MissingRoot" -- Raised when the requested map root is unparented.
]=]
function NavigationMesh.createBuildJob(params: BuildParams): RBuildJob
	assert(params.root and params.root.Parent, "[NavigationMesh.createBuildJob] params.root must be parented")
	local step = positive(params.step, DEFAULTS.step, "step")
	local minimumSpacing = positive(params.minimumNodeSpacing, DEFAULTS.minimumNodeSpacing, "minimumNodeSpacing")
	local maximumWalkDistance = positive(params.maximumWalkDistance, step * 1.5, "maximumWalkDistance")
	local maximumJumpDistance = positive(params.maximumJumpDistance, DEFAULTS.maximumJumpDistance, "maximumJumpDistance")
	local maximumWalkStepUp = positive(params.maximumWalkStepUp, DEFAULTS.maximumWalkStepUp, "maximumWalkStepUp")
	local maximumWalkDropDown = positive(
		params.maximumWalkDropDown,
		DEFAULTS.maximumWalkDropDown,
		"maximumWalkDropDown"
	)
	local maximumJumpUp = positive(params.maximumJumpUp, DEFAULTS.maximumJumpUp, "maximumJumpUp")
	local maximumJumpDown = positive(params.maximumJumpDown, DEFAULTS.maximumJumpDown, "maximumJumpDown")
	local movementRules = if params.movementRules then table.clone(params.movementRules) else {}
	local maximumCandidateDistance = math.max(
		Vector2.new(maximumWalkDistance, math.max(maximumWalkStepUp, maximumWalkDropDown)).Magnitude,
		Vector2.new(maximumJumpDistance, math.max(maximumJumpUp, maximumJumpDown)).Magnitude
	)
	for index, rule in movementRules do
		assert(
			rule.maximumDistance > 0 and rule.maximumDistance < math.huge,
			`[NavigationMesh] movementRules[{index}].maximumDistance must be finite and positive`
		)
		maximumCandidateDistance = math.max(maximumCandidateDistance, rule.maximumDistance)
	end
	local settings: BuildSettings = {
		step = step,
		precisionStep = positive(params.precisionStep, DEFAULTS.precisionStep, "precisionStep"),
		precisionTag = params.precisionTag or DEFAULTS.precisionTag,
		maximumNodes = math.floor(positive(params.maximumNodes, DEFAULTS.maximumNodes, "maximumNodes")),
		maximumSamplesPerPart = math.floor(positive(
			params.maximumSamplesPerPart,
			DEFAULTS.maximumSamplesPerPart,
			"maximumSamplesPerPart"
		)),
		minimumNodeSpacing = minimumSpacing,
		bucketSize = math.max(minimumSpacing, step),
		walkableNormalY = params.walkableNormalY or DEFAULTS.walkableNormalY,
		agentHeight = positive(params.agentHeight, DEFAULTS.agentHeight, "agentHeight"),
		agentRadius = positive(params.agentRadius, DEFAULTS.agentRadius, "agentRadius"),
		rootFloorOffset = positive(params.rootFloorOffset, DEFAULTS.rootFloorOffset, "rootFloorOffset"),
		maximumWalkStepUp = maximumWalkStepUp,
		maximumWalkDropDown = maximumWalkDropDown,
		maximumWalkDistance = maximumWalkDistance,
		maximumJumpUp = maximumJumpUp,
		maximumJumpDown = maximumJumpDown,
		maximumJumpDistance = maximumJumpDistance,
		jumpArcHeight = positive(params.jumpArcHeight, DEFAULTS.jumpArcHeight, "jumpArcHeight"),
		jumpArcSegments = math.floor(positive(params.jumpArcSegments, DEFAULTS.jumpArcSegments, "jumpArcSegments")),
		jumpCostMultiplier = positive(params.jumpCostMultiplier, DEFAULTS.jumpCostMultiplier, "jumpCostMultiplier"),
		maximumCandidateDistance = maximumCandidateDistance,
		sampleProbeHeight = positive(params.sampleProbeHeight, DEFAULTS.sampleProbeHeight, "sampleProbeHeight"),
		validateOccupancy = if params.validateOccupancy == nil then DEFAULTS.validateOccupancy else params.validateOccupancy,
		requireAnchored = if params.requireAnchored == nil then DEFAULTS.requireAnchored else params.requireAnchored,
		includePart = params.includePart,
		movementRules = movementRules,
	}
	assert(settings.walkableNormalY >= -1 and settings.walkableNormalY <= 1, "[NavigationMesh] walkableNormalY must be -1..1")
	assert(settings.rootFloorOffset < settings.agentHeight, "[NavigationMesh] rootFloorOffset must be below agentHeight")

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { params.root }
	raycastParams.IgnoreWater = true
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { params.root }
	overlapParams.RespectCanCollide = true
	overlapParams.MaxParts = 16

	local mesh: RNavigationMesh = {
		root = params.root,
		nodes = {},
		ready = false,
		version = 1,
		stats = {
			partsVisited = 0,
			walkableParts = 0,
			samples = 0,
			nodes = 0,
			edges = 0,
			rejectedOccupied = 0,
			rejectedBlocked = 0,
		},
		_settings = settings,
		_buckets = {},
		_raycastParams = raycastParams,
		_overlapParams = overlapParams,
	}
	return {
		mesh = mesh,
		phase = "Collect",
		stack = { params.root },
		parts = {},
		partIndex = 1,
		partInitialized = false,
		xIndex = 0,
		zIndex = 0,
		xCount = 0,
		zCount = 0,
		xStart = 0,
		zStart = 0,
		xSpan = 0,
		zSpan = 0,
		linkNodeIndex = 1,
		linkCandidates = {},
		linkCandidateIndex = 1,
		done = false,
	}
end

--[=[
    @tag Shared

    stepBuild
    =========

    Advances collection, sampling, or edge generation for at most the supplied
    CPU-time budget. A single engine query is the smallest indivisible unit.

    @return boolean -- True once the mesh is ready or cancelled.
]=]
function NavigationMesh.stepBuild(job: RBuildJob, budgetSeconds: number): boolean
	assert(budgetSeconds > 0, "[NavigationMesh.stepBuild] budgetSeconds must be positive")
	if job.done then return true end
	local startedAt = os.clock()
	while os.clock() - startedAt < budgetSeconds do
		if job.phase == "Collect" then
			local instance = table.remove(job.stack)
			if not instance then
				job.phase = "Sample"
				continue
			end
			job.mesh.stats.partsVisited += 1
			if instance:IsA("BasePart") and isWalkablePart(instance, job.mesh.root, job.mesh._settings) then
				job.parts[#job.parts + 1] = instance
				job.mesh.stats.walkableParts += 1
			end
			for _, child in instance:GetChildren() do job.stack[#job.stack + 1] = child end
		elseif job.phase == "Sample" then
			if #job.mesh.nodes >= job.mesh._settings.maximumNodes then
				job.phase = "Link"
				continue
			end
			local part = job.parts[job.partIndex]
			if not part then
				job.phase = "Link"
				continue
			end
			if not part.Parent or samplePart(job, part) then
				job.partIndex += 1
				job.partInitialized = false
			end
		elseif job.phase == "Link" then
			local node = job.mesh.nodes[job.linkNodeIndex]
			if not node then
				job.mesh.ready = #job.mesh.nodes > 0
				job.phase = "Done"
				job.done = true
				return true
			end
			if #job.linkCandidates == 0 then
				job.linkCandidates = collectNearbyNodeIds(job.mesh, node, job.mesh._settings.maximumCandidateDistance)
				job.linkCandidateIndex = 1
			end
			local candidateId = job.linkCandidates[job.linkCandidateIndex]
			if candidateId then
				tryLink(job.mesh, node, job.mesh.nodes[candidateId])
				job.linkCandidateIndex += 1
			else
				table.clear(job.linkCandidates)
				job.linkNodeIndex += 1
			end
		else
			job.done = true
			return true
		end
	end
	return false
end

--[=[
    @tag Shared

    cancelBuild
    ===========

    Permanently stops a build job. Its incomplete mesh remains unavailable for
    search and can be inspected only for diagnostics.
]=]
function NavigationMesh.cancelBuild(job: RBuildJob)
	if job.done then return end
	job.phase = "Cancelled"
	job.done = true
	job.mesh.ready = false
end

--[=[
    @tag Shared
    @yields

    buildAsync
    ==========

    Convenience wrapper around the incremental builder. It yields between
    slices; latency is higher than a blocking build, but frame time remains
    bounded by `budgetSeconds` plus one engine query.
]=]
function NavigationMesh.buildAsync(params: BuildParams, budgetSeconds: number?): RNavigationMesh
	local job = NavigationMesh.createBuildJob(params)
	while not NavigationMesh.stepBuild(job, budgetSeconds or 0.0015) do task.wait() end
	return job.mesh
end

--[=[
    @tag Shared

    findNearestNode
    ===============

    Spatial-hash lookup whose work scales with the requested radius rather
    than total mesh size. Returns nil when no node lies inside the radius.
]=]
function NavigationMesh.findNearestNode(mesh: RNavigationMesh, position: Vector3, radius: number): RNavNode?
	assert(radius > 0, "[NavigationMesh.findNearestNode] radius must be positive")
	local best: RNavNode? = nil
	local bestDistance = radius
	local bucketRadius = math.ceil(radius / mesh._settings.bucketSize)
	local centerX, centerY, centerZ = cell(position, mesh._settings.bucketSize)
	for x = centerX - bucketRadius, centerX + bucketRadius do
		for y = centerY - bucketRadius, centerY + bucketRadius do
			for z = centerZ - bucketRadius, centerZ + bucketRadius do
				local bucket = getBucket(mesh._buckets, x, y, z, false)
				if not bucket then continue end
				for _, nodeId in bucket do
					local node = mesh.nodes[nodeId]
					local distance = (node.position - position).Magnitude
					if distance <= bestDistance then
						best = node
						bestDistance = distance
					end
				end
			end
		end
	end
	return best
end

--[=[
    @tag Shared

    addDirectedEdge
    =================

    Adds an authored directed transition after a build, or replaces its cost
    when an edge with the same destination and kind already costs more.

    @return boolean -- True only when a new edge was inserted.
]=]
function NavigationMesh.addDirectedEdge(
	mesh: RNavigationMesh,
	fromId: number,
	toId: number,
	cost: number,
	kind: EdgeKind?,
	metadata: { [string]: any }?
): boolean
	return addDirectedEdgeInternal(mesh, fromId, toId, cost, kind or "Custom", metadata)
end

--[=[
    @tag Shared

    createSearch
    ============

    Creates a budgeted A* job. `edgeCost` may return nil to reject an edge or
    a non-negative replacement cost to apply runtime policy and obstacle data.
    Set heuristicWeight to zero when custom edges can cost less than distance.
]=]
function NavigationMesh.createSearch(
	mesh: RNavigationMesh,
	startPosition: Vector3,
	goalPosition: Vector3,
	params: SearchParams?
): RSearchJob?
	assert(mesh.ready, "[NavigationMesh.createSearch] mesh is not ready")
	local startRadius = if params and params.startRadius then params.startRadius else mesh._settings.step * 3
	local goalRadius = if params and params.goalRadius then params.goalRadius else mesh._settings.step * 4
	local startNode = NavigationMesh.findNearestNode(mesh, startPosition, startRadius)
	local goalNode = NavigationMesh.findNearestNode(mesh, goalPosition, goalRadius)
	if not startNode or not goalNode then return nil end
	local initial = heuristic(mesh, startNode.id, goalNode.id)
	local job: RSearchJob = {
		mesh = mesh,
		startId = startNode.id,
		goalId = goalNode.id,
		open = {},
		bestOpenScore = { [startNode.id] = initial },
		cameFrom = {},
		cameEdge = {},
		cost = { [startNode.id] = 0 },
		closed = {},
		expansions = 0,
		maximumExpansions = if params and params.maximumExpansions then params.maximumExpansions else 6000,
		heuristicWeight = if params and params.heuristicWeight then params.heuristicWeight else 1,
		allowPartial = params == nil or params.allowPartial ~= false,
		simplifyDirectionDot = if params and params.simplifyDirectionDot then params.simplifyDirectionDot else 0.995,
		edgeCost = if params then params.edgeCost else nil,
		bestId = startNode.id,
		bestDistance = initial,
		activeNodeId = nil,
		activeEdgeIndex = 1,
		phase = "Search",
		reachedGoal = false,
		reconstructId = nil,
		reverseNodeIds = {},
		reverseIndex = 0,
		nodeIds = {},
		compactIndex = 1,
		waypoints = {},
		result = nil,
		done = false,
		failed = false,
	}
	assert(job.maximumExpansions > 0, "[NavigationMesh.createSearch] maximumExpansions must be positive")
	assert(job.heuristicWeight >= 0, "[NavigationMesh.createSearch] heuristicWeight must be non-negative")
	heapPush(job.open, { id = startNode.id, score = initial })
	return job
end

--[=[
    @tag Shared

    stepSearch
    ==========

    Advances A*, reconstruction, and waypoint compaction within one time
    budget. Movement can continue toward the previous waypoint between calls.

    @return boolean -- True when `getPath` is final.
]=]
function NavigationMesh.stepSearch(job: RSearchJob, budgetSeconds: number): boolean
	assert(budgetSeconds > 0, "[NavigationMesh.stepSearch] budgetSeconds must be positive")
	if job.done then return true end
	local startedAt = os.clock()
	while os.clock() - startedAt < budgetSeconds do
		if job.phase == "Search" then
			if job.activeNodeId then
				local source = job.mesh.nodes[job.activeNodeId]
				local edge = source.edges[job.activeEdgeIndex]
				if not edge then
					job.activeNodeId = nil
					job.activeEdgeIndex = 1
					continue
				end
				job.activeEdgeIndex += 1
				if job.closed[edge.to] then continue end
				local destination = job.mesh.nodes[edge.to]
				local edgeCost = if job.edgeCost then job.edgeCost(edge, source, destination) else edge.cost
				if edgeCost == nil then continue end
				assert(edgeCost >= 0 and edgeCost < math.huge, "[NavigationMesh.stepSearch] edgeCost returned invalid cost")
				local nextCost = (job.cost[source.id] or math.huge) + edgeCost
				if nextCost >= (job.cost[destination.id] or math.huge) then continue end
				job.cost[destination.id] = nextCost
				job.cameFrom[destination.id] = source.id
				job.cameEdge[destination.id] = edge
				local score = nextCost + heuristic(job.mesh, destination.id, job.goalId) * job.heuristicWeight
				job.bestOpenScore[destination.id] = score
				heapPush(job.open, { id = destination.id, score = score })
				continue
			end

			if job.expansions >= job.maximumExpansions then
				beginReconstruction(job, job.bestId, false)
				continue
			end
			local entry = heapPop(job.open)
			if not entry then
				beginReconstruction(job, job.bestId, false)
				continue
			end
			if job.closed[entry.id] or entry.score > (job.bestOpenScore[entry.id] or math.huge) + 0.0001 then continue end
			if entry.id == job.goalId then
				beginReconstruction(job, entry.id, true)
				continue
			end
			local remaining = heuristic(job.mesh, entry.id, job.goalId)
			if remaining < job.bestDistance then
				job.bestDistance = remaining
				job.bestId = entry.id
			end
			job.closed[entry.id] = true
			job.expansions += 1
			job.activeNodeId = entry.id
			job.activeEdgeIndex = 1
		elseif job.phase == "Reconstruct" then
			local current = job.reconstructId
			if not current then
				job.failed = true
				job.done = true
				job.phase = "Done"
				return true
			end
			job.reverseNodeIds[#job.reverseNodeIds + 1] = current
			if current == job.startId then
				job.reverseIndex = #job.reverseNodeIds
				job.phase = "Reverse"
			else
				job.reconstructId = job.cameFrom[current]
			end
		elseif job.phase == "Reverse" then
			if job.reverseIndex <= 0 then
				job.compactIndex = 1
				job.phase = "Compact"
				continue
			end
			job.nodeIds[#job.nodeIds + 1] = job.reverseNodeIds[job.reverseIndex]
			job.reverseIndex -= 1
		elseif job.phase == "Compact" then
			local count = #job.nodeIds
			if count == 0 then
				job.failed = true
				job.done = true
				job.phase = "Done"
				return true
			end
			if job.compactIndex > count then
				finishPath(job)
				return true
			end
			local index = job.compactIndex
			local nodeId = job.nodeIds[index]
			local keep = index == 1 or index == count
			if not keep then
				local previousId = job.nodeIds[index - 1]
				local nextId = job.nodeIds[index + 1]
				local incoming = job.cameEdge[nodeId]
				local outgoing = job.cameEdge[nextId]
				local firstDelta = job.mesh.nodes[nodeId].position - job.mesh.nodes[previousId].position
				local secondDelta = job.mesh.nodes[nextId].position - job.mesh.nodes[nodeId].position
				keep = not incoming
					or not outgoing
					or incoming.kind ~= "Walk"
					or outgoing.kind ~= "Walk"
					or firstDelta.Magnitude < 0.01
					or secondDelta.Magnitude < 0.01
					or firstDelta.Unit:Dot(secondDelta.Unit) < job.simplifyDirectionDot
			end
			if keep then
				local incoming = job.cameEdge[nodeId]
				job.waypoints[#job.waypoints + 1] = {
					nodeId = nodeId,
					position = job.mesh.nodes[nodeId].position,
					kind = if incoming then incoming.kind else "Start",
					metadata = if incoming then incoming.metadata else nil,
				}
			end
			job.compactIndex += 1
		else
			return true
		end
	end
	return false
end

--[=[
    @tag Shared

    cancelSearch
    ============

    Permanently stops an A* job without producing a partial result.
]=]
function NavigationMesh.cancelSearch(job: RSearchJob)
	if job.done then return end
	job.phase = "Cancelled"
	job.done = true
	job.failed = true
end

--[=[
    @tag Shared

    getPath
    =======

    Returns the final path after `stepSearch` completes successfully. Returns
    nil while searching, after cancellation, or when no useful route exists.
]=]
function NavigationMesh.getPath(job: RSearchJob): RPath?
	return job.result
end

--[=[
    @tag Shared
    @yields

    findPathAsync
    =============

    Convenience search wrapper that yields between CPU-budgeted A* slices.
    Prefer explicit jobs when callers need cancellation or live progress.
]=]
function NavigationMesh.findPathAsync(
	mesh: RNavigationMesh,
	startPosition: Vector3,
	goalPosition: Vector3,
	params: SearchParams?,
	budgetSeconds: number?
): RPath?
	local job = NavigationMesh.createSearch(mesh, startPosition, goalPosition, params)
	if not job then return nil end
	while not NavigationMesh.stepSearch(job, budgetSeconds or 0.001) do task.wait() end
	return job.result
end

return table.freeze(NavigationMesh)
