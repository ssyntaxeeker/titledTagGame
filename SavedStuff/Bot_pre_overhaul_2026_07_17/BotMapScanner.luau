--!strict
--[[
    BotMapScanner (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Incrementally samples the static map into an affordance graph.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotAffordanceGraph = require(ReplicatedStorage.Modules.Bot.BotAffordanceGraph)
local BotMapKnowledge = require(ReplicatedStorage.Modules.Bot.BotMapKnowledge)

type RGraph = any

type ScanJob = {
	graph: RGraph,
	mapRoot: Instance?,
	mapRootName: string,
	floorY: number?,
	walkablePartCount: number,
	missingMap: boolean,
	raycastParams: RaycastParams,
	x: number,
	z: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	topY: number,
	done: boolean,
	finalized: boolean,
	nodesCreated: number,
	samples: number,
	hits: number,
	rejectedSlope: number,
	rejectedBarrier: number,
	columnHits: number,
	sampledColumnCells: { [string]: boolean },
	sampledColumnCount: number,
	fallbackParts: { BasePart }?,
	fallbackPartIndex: number,
	fallbackX: number,
	fallbackZ: number,
	fallbackStep: number,
	fallbackPartInitialized: boolean,
	fallbackActive: boolean,
}

local BotMapScanner = {}

local function findMapRoot(): Instance?
	local instance = Workspace:FindFirstChild("Map")
	if instance and (instance:IsA("Model") or instance:IsA("Folder")) then return instance end

	return nil
end

local function isIgnoredWorkspaceContainer(instance: Instance): boolean
	return instance.Name == "Bots"
		or instance.Name == "BotDebug"
		or instance.Name == "Debug"
		or instance:IsA("Camera")
end

local function isWalkablePart(part: BasePart): boolean
	if BotAffordanceGraph.isBarrierPart(part) then return false end
	if part.Transparency >= 1 and not part.CanCollide then return false end
	if part.Size.X < Config.graphStep * 0.5 or part.Size.Z < Config.graphStep * 0.5 then return false end
	if part.CFrame.UpVector.Y < Config.walkableNormalY then return false end

	local current: Instance? = part
	while current do
		if isIgnoredWorkspaceContainer(current) then return false end
		current = current.Parent
	end

	return true
end

local function collectWalkableParts(root: Instance?): { BasePart }
	local parts = {}
	local searchRoot: Instance = root or Workspace

	for _, descendant in searchRoot:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		if not isWalkablePart(descendant) then continue end

		parts[#parts + 1] = descendant
	end

	return parts
end

local function getPartTopY(part: BasePart): number
	local halfSize = part.Size * 0.5
	local topCenter = part.CFrame:PointToWorldSpace(Vector3.new(0, halfSize.Y, 0))
	return topCenter.Y
end

local function getPartSampleStep(part: BasePart): number
	local surfaceArea = math.max(Config.graphStep * Config.graphStep, part.Size.X * part.Size.Z)
	local adaptiveStep = math.sqrt(surfaceArea / Config.maxSurfaceSamplesPerPart)
	return math.max(Config.graphStep, adaptiveStep)
end

local function collectFloorSeedParts(parts: { BasePart }, floorY: number?): { BasePart }
	if not floorY then return parts end

	local seedParts = {}
	for _, part in parts do
		local topY = getPartTopY(part)
		local isFloorBand = math.abs(topY - floorY) <= Config.floorHeightTolerance
		local isUsefulSurface = part.Size.X >= Config.graphStep * 2 or part.Size.Z >= Config.graphStep * 2
		if not isFloorBand and not isUsefulSurface then continue end
		seedParts[#seedParts + 1] = part
	end

	return if #seedParts > 0 then seedParts else parts
end

local function getBoundsFromParts(parts: { BasePart }, fallbackRoot: Instance?): (CFrame, Vector3)
	if #parts <= 0 then
		if fallbackRoot and fallbackRoot:IsA("Model") then return fallbackRoot:GetBoundingBox() end
		return CFrame.new(Vector3.zero), Vector3.new(512, 180, 512)
	end

	local minX = math.huge
	local minY = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxY = -math.huge
	local maxZ = -math.huge

	for _, part in parts do
		local halfSize = part.Size * 0.5
		for _, xSign in { -1, 1 } do
			for _, ySign in { -1, 1 } do
				for _, zSign in { -1, 1 } do
					local corner = part.CFrame:PointToWorldSpace(Vector3.new(halfSize.X * xSign, halfSize.Y * ySign, halfSize.Z * zSign))
					minX = math.min(minX, corner.X)
					minY = math.min(minY, corner.Y)
					minZ = math.min(minZ, corner.Z)
					maxX = math.max(maxX, corner.X)
					maxY = math.max(maxY, corner.Y)
					maxZ = math.max(maxZ, corner.Z)
				end
			end
		end
	end

	local minPosition = Vector3.new(minX, minY, minZ)
	local maxPosition = Vector3.new(maxX, maxY, maxZ)
	local size = maxPosition - minPosition
	return CFrame.new(minPosition:Lerp(maxPosition, 0.5)), size
end

local function makeRaycastParams(mapRoot: Instance?): RaycastParams
	local raycastParams = RaycastParams.new()
	raycastParams.IgnoreWater = true

	if mapRoot then
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { mapRoot }
	else
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local exclude = {}
		for _, child in Workspace:GetChildren() do
			if isIgnoredWorkspaceContainer(child) then exclude[#exclude + 1] = child end
		end
		raycastParams.FilterDescendantsInstances = exclude
	end

	return raycastParams
end

local function getMapFloorY(mapRoot: Instance?): number?
	if not mapRoot then return nil end

	local floorY = mapRoot:GetAttribute("FloorY")
	if typeof(floorY) == "number" then return floorY end

	return nil
end

local function getWallPenalty(position: Vector3, raycastParams: RaycastParams): number
	local penalty = 0
	for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local result = Workspace:Raycast(position + Vector3.yAxis * 2.5, direction * 3.5, raycastParams)
		if result and result.Instance:IsA("BasePart") then penalty += 2 end
	end

	return penalty
end

local function sampleColumn(job: ScanJob, origin: Vector3)
	local remainingDepth = Config.raycastDepth
	local rayOrigin = origin
	local floorsAdded = 0
	local lastFloorY: number? = nil
	local floorY = job.floorY or (job.graph.boundsCenter.Y - job.graph.boundsSize.Y / 2)

	for _ = 1, Config.maxColumnFloorHits * 2 do
		local result = Workspace:Raycast(rayOrigin, Vector3.yAxis * -remainingDepth, job.raycastParams)
		if not result then return end

		job.hits += 1
		job.columnHits += 1

		if not result.Instance:IsA("BasePart") then return end

		if BotAffordanceGraph.isBarrierPart(result.Instance) then
			job.rejectedBarrier += 1
		elseif not isWalkablePart(result.Instance) then
			job.rejectedSlope += 1
		elseif result.Normal.Y < Config.walkableNormalY and result.Position.Y > floorY + Config.floorHeightTolerance then
			job.rejectedSlope += 1
		else
			if not lastFloorY or math.abs(result.Position.Y - lastFloorY) >= Config.minColumnFloorGap then
				local position = result.Position + Vector3.yAxis * 2.75
				local wallPenalty = getWallPenalty(position, job.raycastParams)
				local verticalScore = math.max(0, result.Position.Y - floorY)
				local knowledge = BotMapKnowledge.analyze(position, job.raycastParams)
				knowledge.isTrampoline = CollectionService:HasTag(result.Instance, "Trampoline")
				if BotAffordanceGraph.addNode(job.graph, position, wallPenalty, verticalScore, knowledge) then
					job.nodesCreated += 1
					floorsAdded += 1
					lastFloorY = result.Position.Y
				end
			end
		end

		local traveled = (origin.Y - result.Position.Y) + 0.35
		remainingDepth = Config.raycastDepth - traveled
		if remainingDepth <= 0 then return end
		if floorsAdded >= Config.maxColumnFloorHits then return end

		rayOrigin = result.Position - Vector3.yAxis * 0.35
	end
end

local function startFallbackSampling(job: ScanJob)
	job.fallbackParts = collectFloorSeedParts(collectWalkableParts(job.mapRoot), job.floorY)
	job.fallbackPartIndex = 1
	job.fallbackX = 0
	job.fallbackZ = 0
	job.fallbackStep = Config.graphStep
	job.fallbackPartInitialized = false
	job.fallbackActive = true
end

local function sampleFallbackPart(job: ScanJob): boolean
	local parts = job.fallbackParts
	if not parts then return true end

	while job.fallbackPartIndex <= #parts do
		local part = parts[job.fallbackPartIndex]
		if not part.Parent then
			job.fallbackPartIndex += 1
			job.fallbackX = 0
			job.fallbackZ = 0
			job.fallbackPartInitialized = false
			continue
		end

		local halfSize = part.Size * 0.5
		if not job.fallbackPartInitialized then
			job.fallbackStep = getPartSampleStep(part)
			job.fallbackX = -halfSize.X + job.fallbackStep * 0.5
			job.fallbackZ = -halfSize.Z + job.fallbackStep * 0.5
			job.fallbackPartInitialized = true
		end

		local localPosition = Vector3.new(job.fallbackX, halfSize.Y, job.fallbackZ)
		local worldPosition = part.CFrame:PointToWorldSpace(localPosition)
		local columnKey = `{math.floor(worldPosition.X / Config.graphStep)}:{math.floor(worldPosition.Z / Config.graphStep)}`
		if not job.sampledColumnCells[columnKey] then
			job.sampledColumnCells[columnKey] = true
			job.sampledColumnCount += 1
			sampleColumn(job, Vector3.new(worldPosition.X, job.topY, worldPosition.Z))
		end

		job.samples += 1
		job.fallbackX += job.fallbackStep
		if job.fallbackX > halfSize.X - job.fallbackStep * 0.5 then
			job.fallbackX = -halfSize.X + job.fallbackStep * 0.5
			job.fallbackZ += job.fallbackStep
		end

		if job.fallbackZ > halfSize.Z - job.fallbackStep * 0.5 then
			job.fallbackPartIndex += 1
			job.fallbackX = 0
			job.fallbackZ = 0
			job.fallbackPartInitialized = false
		end

		if job.nodesCreated >= Config.maxGraphNodes then return true end
		return false
	end

	return true
end

function BotMapScanner.createJob(): ScanJob
	local mapRoot = findMapRoot()
	local walkableParts = collectWalkableParts(mapRoot)
	local boundsCFrame, boundsSize = getBoundsFromParts(walkableParts, mapRoot)
	local center = boundsCFrame.Position
	local inset = Config.mapInset
	local graph = BotAffordanceGraph.createEmpty(center, boundsSize)
	local floorY = getMapFloorY(mapRoot)
	local fallbackParts = collectFloorSeedParts(walkableParts, floorY)

	return {
		graph = graph,
		mapRoot = mapRoot,
		mapRootName = if mapRoot then mapRoot:GetFullName() else "workspace surface scan",
		floorY = floorY,
		walkablePartCount = #walkableParts,
		missingMap = mapRoot == nil,
		raycastParams = makeRaycastParams(mapRoot),
		x = center.X - boundsSize.X / 2 + inset,
		z = center.Z - boundsSize.Z / 2 + inset,
		minX = center.X - boundsSize.X / 2 + inset,
		maxX = center.X + boundsSize.X / 2 - inset,
		minZ = center.Z - boundsSize.Z / 2 + inset,
		maxZ = center.Z + boundsSize.Z / 2 - inset,
		topY = center.Y + boundsSize.Y / 2 + Config.raycastStartHeight,
		done = false,
		finalized = false,
		nodesCreated = 0,
		samples = 0,
		hits = 0,
		rejectedSlope = 0,
		rejectedBarrier = 0,
		columnHits = 0,
		sampledColumnCells = {},
		sampledColumnCount = 0,
		fallbackParts = fallbackParts,
		fallbackPartIndex = 1,
		fallbackX = 0,
		fallbackZ = 0,
		fallbackStep = Config.graphStep,
		fallbackPartInitialized = false,
		fallbackActive = true,
	}
end

function BotMapScanner.step(job: ScanJob, budgetSeconds: number): boolean
	if job.done then return true end
	if job.missingMap or job.walkablePartCount <= 0 then
		job.done = true
		job.finalized = true
		return true
	end

	local startTime = os.clock()
	while os.clock() - startTime < budgetSeconds do
		if job.fallbackActive then
			if sampleFallbackPart(job) then
				job.fallbackActive = false
				job.done = true
				break
			end
			continue
		end

		local origin = Vector3.new(job.x, job.topY, job.z)
		job.samples += 1
		sampleColumn(job, origin)

		job.x += Config.graphStep
		if job.x > job.maxX then
			job.x = job.minX
			job.z += Config.graphStep
		end

		if job.nodesCreated >= Config.maxGraphNodes then
			job.done = true
			break
		end

		if job.z > job.maxZ then
			if job.nodesCreated <= 0 and not job.missingMap then
				startFallbackSampling(job)
			else
				job.done = true
			end
			break
		end
	end

	if job.done and not job.finalized then
		BotAffordanceGraph.rebuildEdges(job.graph)
		job.finalized = true
	end

	return job.done
end

return BotMapScanner
