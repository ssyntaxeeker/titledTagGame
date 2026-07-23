--!strict
--[[
    BotMapModel (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Incrementally discovers every walkable part surface in the spawned
    workspace.Map, including stacked floors and interiors. Stored positions are
    world-space root positions, so debug and planning share one coordinate frame.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local MovementRules = require(ReplicatedStorage.Modules.Bot.BotMovementRules)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type RMapModel = Types.RMapModel
type RSurfaceNode = Types.RSurfaceNode
type RSwingAnchor = Types.RSwingAnchor

export type RBuildJob = {
	model: RMapModel,
	phase: "Collect" | "Sample" | "Finalize" | "Done" | "Failed",
	instanceStack: { Instance },
	parts: { BasePart },
	partIndex: number,
	partX: number,
	partZ: number,
	partStep: number,
	partSampleMode: "Grid" | "Perimeter",
	partEdge: number,
	partEdgeSamples: number,
	partInitialized: boolean,
	raycastParams: RaycastParams,
	overlapParams: OverlapParams,
	samples: number,
	rejected: number,
	status: string,
}

local BotMapModel = {}
local CARDINAL_DIRECTIONS = table.freeze({ Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis, -Vector3.zAxis })

local function cellKey(position: Vector3): string
	return `{math.floor(position.X / Config.mapSampleStep + 0.5)}:{math.floor(position.Y / Config.mapVerticalSampleStep + 0.5)}:{math.floor(position.Z / Config.mapSampleStep + 0.5)}`
end

local function edgeCellKey(position: Vector3): string
	return `{math.floor(position.X / Config.mapEdgeSampleCellStep + 0.5)}:{math.floor(position.Y / Config.mapVerticalSampleStep + 0.5)}:{math.floor(position.Z / Config.mapEdgeSampleCellStep + 0.5)}`
end

local function precisionCellKey(position: Vector3): string
	return `{math.floor(position.X / Config.mapPrecisionTestCellStep + 0.5)}:{math.floor(position.Y / Config.mapVerticalSampleStep + 0.5)}:{math.floor(position.Z / Config.mapPrecisionTestCellStep + 0.5)}`
end

local function bucketKey(position: Vector3): string
	return `{math.floor(position.X / Config.mapBucketSize)}:{math.floor(position.Y / Config.mapBucketSize)}:{math.floor(position.Z / Config.mapBucketSize)}`
end

local function spacingBucketKey(position: Vector3): string
	return `{math.floor(position.X / Config.mapMinimumNodeSpacing)}:{math.floor(position.Y / Config.mapMinimumNodeSpacing)}:{math.floor(position.Z / Config.mapMinimumNodeSpacing)}`
end

local function hasNearbyNode(model: RMapModel, position: Vector3, minimumSpacing: number): boolean
	local bucketSize = Config.mapMinimumNodeSpacing
	local bucketRadius = math.max(1, math.ceil(minimumSpacing / bucketSize))
	local centerX = math.floor(position.X / bucketSize)
	local centerY = math.floor(position.Y / bucketSize)
	local centerZ = math.floor(position.Z / bucketSize)
	local minimumDistanceSquared = minimumSpacing * minimumSpacing
	for x = centerX - bucketRadius, centerX + bucketRadius do
		for y = centerY - bucketRadius, centerY + bucketRadius do
			for z = centerZ - bucketRadius, centerZ + bucketRadius do
				local bucket = model.spacingBuckets[`{x}:{y}:{z}`]
				if not bucket then continue end
				for _, nodeId in bucket do
					local delta = model.nodes[nodeId].rootPosition - position
					if delta:Dot(delta) < minimumDistanceSquared then return true end
				end
			end
		end
	end
	return false
end

local function addSwingAnchor(model: RMapModel, bar: BasePart)
	for _, anchor in model.swingAnchors do
		if (anchor.position - bar.Position).Magnitude < Config.swingAnchorMergeDistance then return end
	end
	local anchor: RSwingAnchor = {
		id = #model.swingAnchors + 1,
		position = bar.Position,
		bar = bar,
	}
	model.swingAnchors[anchor.id] = anchor
end

local function isIgnored(instance: Instance): boolean
	return instance.Name == "Spawns"
		or instance.Name == "Bots"
		or instance.Name == "BotDebug"
		or instance:IsA("SpawnLocation")
end

local function isCandidatePart(part: BasePart): boolean
	if MovementRules.isBarrier(part) then return false end
	if isIgnored(part) then return false end
	if part.Transparency >= 1 and not part.CanCollide then return false end
	if not part.CanCollide then return false end
	if part.CFrame.UpVector.Y < Config.walkableNormalY then return false end
	if part.Size.X < Config.mapMinimumSurfaceDimension
		or part.Size.Z < Config.mapMinimumSurfaceDimension
	then
		return false
	end
	return true
end

local function isPrecisionSurface(part: BasePart): boolean
	if not Config.mapPrecisionTestEnabled then return false end
	return CollectionService:HasTag(part, Config.mapPrecisionSurfaceTag)
		or part.Size.X <= Config.mapPrecisionTestSurfaceThreshold
		or part.Size.Z <= Config.mapPrecisionTestSurfaceThreshold
end

local function getSampleStep(part: BasePart): number
	if isPrecisionSurface(part) then
		local area = math.max(Config.mapPrecisionTestStep ^ 2, part.Size.X * part.Size.Z)
		local capStep = math.sqrt(area / Config.mapPrecisionTestMaxSamplesPerPart)
		local longDimensionStep = math.max(part.Size.X, part.Size.Z)
			/ Config.mapPrecisionTestMaxSamplesPerPart
		return math.max(Config.mapPrecisionTestStep, capStep, longDimensionStep)
	end
	if math.min(part.Size.X, part.Size.Z) <= Config.mapVeryThinSurfaceThreshold then
		local longDimension = math.max(part.Size.X, part.Size.Z)
		return math.max(Config.mapSampleStep, longDimension / Config.mapVeryThinSamplesPerPart)
	end
	local area = math.max(1, part.Size.X * part.Size.Z)
	local capStep = math.sqrt(area / Config.mapMaxSamplesPerPart)
	return math.max(Config.mapSampleStep, capStep)
end

local function analyzeWalls(position: Vector3, params: RaycastParams): (number, number, number, boolean)
	local mask = 0
	local openDirections = 0
	local nearestDistance = Config.wallProbeDistance
	local barrierAdjacent = false
	local origin = position + Vector3.yAxis * 1.5

	for directionIndex, direction in CARDINAL_DIRECTIONS do
		local result = Workspace:Raycast(origin, direction * Config.wallProbeDistance, params)
		if not result then
			openDirections += 1
			continue
		end

		local distance = (result.Position - origin).Magnitude
		nearestDistance = math.min(nearestDistance, distance)
		if distance <= Config.wallNearDistance then mask += 2 ^ (directionIndex - 1) end
		if MovementRules.isBarrier(result.Instance) then barrierAdjacent = true end
	end

	return mask, openDirections, nearestDistance, barrierAdjacent
end

-- A floor ray alone can place the root center through an adjacent wall. This
-- volume check rejects nodes the bot cannot physically occupy while ignoring
-- the surface supporting the node.
local function isRootVolumeOccupied(job: RBuildJob, rootPosition: Vector3, surface: BasePart): boolean
	local bodyWidth = if isPrecisionSurface(surface) then Config.mapPrecisionNodeBodyWidth else Config.mapNodeBodyWidth
	local bodySize = Vector3.new(bodyWidth, Config.mapNodeBodyHeight, bodyWidth)
	local bodyCenter = rootPosition + Vector3.yAxis * Config.mapNodeBodyCenterYOffset
	local overlaps = Workspace:GetPartBoundsInBox(CFrame.new(bodyCenter), bodySize, job.overlapParams)
	for _, part in overlaps do
		if part ~= surface and part.CanCollide then return true end
	end
	return false
end

local function addSurfaceNode(job: RBuildJob, hit: RaycastResult, isPerimeterSample: boolean?)
	if #job.model.nodes >= Config.mapMaxNodes then return end
	if hit.Normal.Y < Config.walkableNormalY then
		job.rejected += 1
		return
	end
	if not hit.Instance:IsA("BasePart") or not isCandidatePart(hit.Instance) then
		job.rejected += 1
		return
	end

	local rootPosition = hit.Position + Vector3.yAxis * Config.rootFloorOffset
	local part = hit.Instance :: BasePart
	local precisionSurface = isPrecisionSurface(part)
	local minimumSpacing = if precisionSurface
		then Config.mapPrecisionMinimumNodeSpacing
		else Config.mapMinimumNodeSpacing
	if hasNearbyNode(job.model, rootPosition, minimumSpacing) then return end
	if isRootVolumeOccupied(job, rootPosition, part) then
		job.rejected += 1
		return
	end
	local isSmallSurface = math.min(part.Size.X, part.Size.Z) <= Config.mapSmallSurfaceThreshold
	local key = if isPerimeterSample
		and not precisionSurface
		then `{edgeCellKey(rootPosition)}:E{job.model.partIds[part] or 0}`
		elseif precisionSurface
		then `{precisionCellKey(rootPosition)}:T{job.model.partIds[part] or 0}`
		elseif isSmallSurface
		then `{cellKey(rootPosition)}:P{job.model.partIds[part] or 0}`
		else cellKey(rootPosition)
	if job.model.nodeByCell[key] then return end

	local ceiling = Workspace:Raycast(hit.Position + Vector3.yAxis * 0.15, Vector3.yAxis * Config.bodyClearanceHeight, job.raycastParams)
	local clearance = if ceiling then (ceiling.Position - hit.Position).Magnitude else Config.bodyClearanceHeight
	if clearance < Config.slideClearanceHeight - 0.25 then
		job.rejected += 1
		return
	end

	local wallMask, openDirections, nearestWallDistance, barrierAdjacent = analyzeWalls(rootPosition, job.raycastParams)
	local node: RSurfaceNode = {
		id = #job.model.nodes + 1,
		rootPosition = rootPosition,
		floorPosition = hit.Position,
		floorNormal = hit.Normal,
		surface = hit.Instance,
		layer = math.floor((hit.Position.Y - job.model.floorY) / Config.mapVerticalSampleStep + 0.5),
		clearance = clearance,
		wallMask = wallMask,
		openDirections = openDirections,
		nearestWallDistance = nearestWallDistance,
		isBarrierAdjacent = barrierAdjacent,
		isTrampoline = MovementRules.isTrampoline(hit.Instance),
		edges = {},
	}

	job.model.nodes[node.id] = node
	job.model.nodeByCell[key] = node.id
	local spatialKey = bucketKey(rootPosition)
	local bucket = job.model.buckets[spatialKey]
	if not bucket then
		bucket = {}
		job.model.buckets[spatialKey] = bucket
	end
	bucket[#bucket + 1] = node.id
	local spacingKey = spacingBucketKey(rootPosition)
	local spacingBucket = job.model.spacingBuckets[spacingKey]
	if not spacingBucket then
		spacingBucket = {}
		job.model.spacingBuckets[spacingKey] = spacingBucket
	end
	spacingBucket[#spacingBucket + 1] = node.id
end

local function initializePart(job: RBuildJob, part: BasePart)
	job.partStep = getSampleStep(part)
	job.partX = -part.Size.X * 0.5 + math.min(job.partStep * 0.5, part.Size.X * 0.5)
	job.partZ = -part.Size.Z * 0.5 + math.min(job.partStep * 0.5, part.Size.Z * 0.5)
	job.partSampleMode = "Grid"
	job.partEdge = 1
	job.partEdgeSamples = 0
	job.partInitialized = true
end

local function shouldSamplePerimeter(job: RBuildJob, part: BasePart): boolean
	if isPrecisionSurface(part) then return true end
	if math.min(part.Size.X, part.Size.Z) <= Config.mapVeryThinSurfaceThreshold then return false end
	local topCenter = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y * 0.5, 0))
	return math.min(part.Size.X, part.Size.Z) <= Config.mapSmallSurfaceThreshold * 2
		or topCenter.Y >= job.model.floorY + Config.mapEdgeSampleElevation
end

local function samplePerimeter(job: RBuildJob, part: BasePart): boolean
	local precisionSurface = isPrecisionSurface(part)
	local maxSamples = if precisionSurface
		then Config.mapPrecisionPerimeterMaxSamplesPerPart
		else Config.mapEdgeSampleMaxPerPart
	local requestedStep = if precisionSurface then Config.mapPrecisionPerimeterStep else Config.mapEdgeSampleStep
	local perimeter = 2 * (part.Size.X + part.Size.Z)
	local totalSamples = math.min(maxSamples, math.max(4, math.ceil(perimeter / requestedStep)))
	if job.partEdge > 4 or job.partEdgeSamples >= totalSamples then return true end

	local edgeLength = if job.partEdge <= 2 then part.Size.Z else part.Size.X
	local lengthBeforeEdge = if job.partEdge == 1
		then 0
		elseif job.partEdge == 2
		then part.Size.Z
		elseif job.partEdge == 3
		then part.Size.Z * 2
		else part.Size.Z * 2 + part.Size.X
	local firstSampleIndex = math.floor(totalSamples * lengthBeforeEdge / perimeter)
	local nextEdgeSampleIndex = math.floor(totalSamples * (lengthBeforeEdge + edgeLength) / perimeter)
	local edgeSampleCount = nextEdgeSampleIndex - firstSampleIndex
	if edgeSampleCount <= 0 or job.partEdgeSamples >= nextEdgeSampleIndex then
		job.partEdge += 1
		return job.partEdge > 4
	end

	local halfX = part.Size.X * 0.5
	local halfZ = part.Size.Z * 0.5
	local sampleInset = if precisionSurface then Config.mapPrecisionPerimeterInset else Config.mapEdgeSampleInset
	local insetX = math.min(sampleInset, halfX)
	local insetZ = math.min(sampleInset, halfZ)
	local halfLength = edgeLength * 0.5
	local alongInset = math.min(sampleInset, halfLength)
	local usableLength = math.max(0, edgeLength - alongInset * 2)
	local sampleOnEdge = job.partEdgeSamples - firstSampleIndex
	local edgeAlpha = (sampleOnEdge + 0.5) / edgeSampleCount
	local edgeOffset = -halfLength + alongInset + usableLength * edgeAlpha
	local localPosition = if job.partEdge == 1
		then Vector3.new(-halfX + insetX, part.Size.Y * 0.5, edgeOffset)
		elseif job.partEdge == 2
		then Vector3.new(halfX - insetX, part.Size.Y * 0.5, edgeOffset)
		elseif job.partEdge == 3
		then Vector3.new(edgeOffset, part.Size.Y * 0.5, -halfZ + insetZ)
		else Vector3.new(edgeOffset, part.Size.Y * 0.5, halfZ - insetZ)
	local worldPosition = part.CFrame:PointToWorldSpace(localPosition)
	local result = Workspace:Raycast(worldPosition + Vector3.yAxis * 2, -Vector3.yAxis * 4, job.raycastParams)
	job.samples += 1
	job.partEdgeSamples += 1
	if result then addSurfaceNode(job, result, true) end

	if job.partEdgeSamples >= nextEdgeSampleIndex then job.partEdge += 1 end
	return job.partEdge > 4 or job.partEdgeSamples >= totalSamples
end

local function samplePart(job: RBuildJob): boolean
	local part = job.parts[job.partIndex]
	if not part or not part.Parent then return true end
	if not job.partInitialized then initializePart(job, part) end
	if job.partSampleMode == "Perimeter" then return samplePerimeter(job, part) end

	local halfY = part.Size.Y * 0.5
	local localPosition = Vector3.new(job.partX, halfY, job.partZ)
	local worldPosition = part.CFrame:PointToWorldSpace(localPosition)
	local origin = worldPosition + Vector3.yAxis * 2
	local result = Workspace:Raycast(origin, -Vector3.yAxis * 4, job.raycastParams)
	job.samples += 1
	if result then addSurfaceNode(job, result) end

	job.partX += job.partStep
	if job.partX > part.Size.X * 0.5 then
		job.partX = -part.Size.X * 0.5 + math.min(job.partStep * 0.5, part.Size.X * 0.5)
		job.partZ += job.partStep
	end

	if job.partZ <= part.Size.Z * 0.5 then return false end
	if not shouldSamplePerimeter(job, part) then return true end
	job.partSampleMode = "Perimeter"
	return false
end

local function finalizeModel(model: RMapModel)
	if #model.nodes == 0 then return end
	local minPosition = Vector3.new(math.huge, math.huge, math.huge)
	local maxPosition = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, node in model.nodes do
		minPosition = Vector3.new(
			math.min(minPosition.X, node.rootPosition.X),
			math.min(minPosition.Y, node.rootPosition.Y),
			math.min(minPosition.Z, node.rootPosition.Z)
		)
		maxPosition = Vector3.new(
			math.max(maxPosition.X, node.rootPosition.X),
			math.max(maxPosition.Y, node.rootPosition.Y),
			math.max(maxPosition.Z, node.rootPosition.Z)
		)
	end
	model.boundsCenter = minPosition:Lerp(maxPosition, 0.5)
	model.boundsSize = maxPosition - minPosition
	model.ready = true
	model.buildVersion += 1
end

function BotMapModel.createBuildJob(): RBuildJob
	local mapRoot = Workspace:FindFirstChild("Map")
	assert(mapRoot, "[BotMapModel.createBuildJob] workspace.Map is required")
	local floorYAttribute = mapRoot:GetAttribute("FloorY")
	local floorY = if typeof(floorYAttribute) == "number" then floorYAttribute else 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { mapRoot }
	params.IgnoreWater = true
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { mapRoot }
	overlapParams.RespectCanCollide = true

	local model: RMapModel = {
		mapRoot = mapRoot,
		floorY = floorY,
		nodes = {},
		nodeByCell = {},
		partIds = {},
		buckets = {},
		spacingBuckets = {},
		swingBars = {},
		swingAnchors = {},
		trampolines = {},
		vaultableParts = {},
		trusses = {},
		boundsCenter = Vector3.zero,
		boundsSize = Vector3.zero,
		buildVersion = 0,
		ready = false,
	}

	return {
		model = model,
		phase = "Collect",
		instanceStack = { mapRoot },
		parts = {},
		partIndex = 1,
		partX = 0,
		partZ = 0,
		partStep = Config.mapSampleStep,
		partSampleMode = "Grid",
		partEdge = 1,
		partEdgeSamples = 0,
		partInitialized = false,
		raycastParams = params,
		overlapParams = overlapParams,
		samples = 0,
		rejected = 0,
		status = "Collecting map parts",
	}
end

function BotMapModel.stepBuild(job: RBuildJob, budgetSeconds: number?): boolean
	if job.phase == "Done" or job.phase == "Failed" then return true end
	local startedAt = os.clock()
	local budget = budgetSeconds or Config.mapBuildBudgetSeconds

	while os.clock() - startedAt < budget do
		if job.phase == "Collect" then
			local instance = table.remove(job.instanceStack)
			if not instance then
				job.phase = "Sample"
				job.status = `Sampling {#job.parts} walkable parts`
				continue
			end

			for _, child in instance:GetChildren() do
				if child:IsA("BasePart") then
					if child:IsA("TrussPart") then job.model.trusses[#job.model.trusses + 1] = child end
					if isCandidatePart(child) then
						job.parts[#job.parts + 1] = child
						job.model.partIds[child] = #job.parts
						job.model.vaultableParts[#job.model.vaultableParts + 1] = child
					end
					if MovementRules.isSwingBar(child) then
						job.model.swingBars[#job.model.swingBars + 1] = child
						addSwingAnchor(job.model, child)
					end
					if CollectionService:HasTag(child, "Trampoline") then job.model.trampolines[#job.model.trampolines + 1] = child end
				else
					job.instanceStack[#job.instanceStack + 1] = child
				end
			end
		elseif job.phase == "Sample" then
			if #job.model.nodes >= Config.mapMaxNodes or job.partIndex > #job.parts then
				job.phase = "Finalize"
				continue
			end

			if samplePart(job) then
				job.partIndex += 1
				job.partInitialized = false
			end
			job.status = `Surface {job.partIndex}/{#job.parts} | {#job.model.nodes} nodes | {job.samples} samples`
		elseif job.phase == "Finalize" then
			finalizeModel(job.model)
			job.phase = if job.model.ready then "Done" else "Failed"
			job.status = if job.model.ready
				then `Map ready: {#job.model.nodes} surface nodes + {#job.model.swingAnchors} swing anchors across {#job.parts} parts`
				else `Map failed: no walkable surfaces in {job.model.mapRoot:GetFullName()}`
			return true
		end
	end

	return false
end

function BotMapModel.findNearestNode(model: RMapModel, position: Vector3, radius: number): RSurfaceNode?
	local bestNode: RSurfaceNode? = nil
	local bestDistance = radius
	local bucketRadius = math.ceil(radius / Config.mapBucketSize)
	local centerX = math.floor(position.X / Config.mapBucketSize)
	local centerY = math.floor(position.Y / Config.mapBucketSize)
	local centerZ = math.floor(position.Z / Config.mapBucketSize)

	for x = centerX - bucketRadius, centerX + bucketRadius do
		for y = centerY - bucketRadius, centerY + bucketRadius do
			for z = centerZ - bucketRadius, centerZ + bucketRadius do
				local bucket = model.buckets[`{x}:{y}:{z}`]
				if not bucket then continue end
				for _, nodeId in bucket do
					local node = model.nodes[nodeId]
					local distance = (node.rootPosition - position).Magnitude
					if distance < bestDistance then
						bestDistance = distance
						bestNode = node
					end
				end
			end
		end
	end
	return bestNode
end

--[=[
	@client

	findNearestNodeOnLayer
	======================

	Finds a node near a world-space target without allowing a geometrically
	close floor from another stacked layer to become the navigation goal.
]=]
function BotMapModel.findNearestNodeOnLayer(
	model: RMapModel,
	position: Vector3,
	radius: number,
	verticalTolerance: number
): RSurfaceNode?
	local bestNode: RSurfaceNode? = nil
	local bestHorizontalDistance = radius
	local horizontalBucketRadius = math.ceil(radius / Config.mapBucketSize)
	local verticalBucketRadius = math.ceil(verticalTolerance / Config.mapBucketSize) + 1
	local centerX = math.floor(position.X / Config.mapBucketSize)
	local centerY = math.floor(position.Y / Config.mapBucketSize)
	local centerZ = math.floor(position.Z / Config.mapBucketSize)

	for x = centerX - horizontalBucketRadius, centerX + horizontalBucketRadius do
		for y = centerY - verticalBucketRadius, centerY + verticalBucketRadius do
			for z = centerZ - horizontalBucketRadius, centerZ + horizontalBucketRadius do
				local bucket = model.buckets[`{x}:{y}:{z}`]
				if not bucket then continue end
				for _, nodeId in bucket do
					local node = model.nodes[nodeId]
					local delta = node.rootPosition - position
					if math.abs(delta.Y) > verticalTolerance then continue end
					local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
					if horizontalDistance < bestHorizontalDistance then
						bestHorizontalDistance = horizontalDistance
						bestNode = node
					end
				end
			end
		end
	end
	return bestNode
end

function BotMapModel.findNodesInRadius(
	model: RMapModel,
	position: Vector3,
	radius: number,
	limit: number?
): { RSurfaceNode }
	local result = {}
	local bucketRadius = math.ceil(radius / Config.mapBucketSize)
	local centerX = math.floor(position.X / Config.mapBucketSize)
	local centerY = math.floor(position.Y / Config.mapBucketSize)
	local centerZ = math.floor(position.Z / Config.mapBucketSize)

	for x = centerX - bucketRadius, centerX + bucketRadius do
		for y = centerY - bucketRadius, centerY + bucketRadius do
			for z = centerZ - bucketRadius, centerZ + bucketRadius do
				local bucket = model.buckets[`{x}:{y}:{z}`]
				if not bucket then continue end
				for _, nodeId in bucket do
					local node = model.nodes[nodeId]
					if (node.rootPosition - position).Magnitude <= radius then
						result[#result + 1] = node
						if limit and #result >= limit then return result end
					end
				end
			end
		end
	end
	return result
end

return table.freeze(BotMapModel)
