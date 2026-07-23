--!strict
--[[
    BotWorld (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Incremental world-space surface sampler. It discovers stacked floors,
    interiors, thin tagged surfaces, walls, barriers, and occupied root space
    without Roblox PathfindingService.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type RNode = Types.RNode
type RWorld = Types.RWorld

export type RBuildJob = {
	world: RWorld,
	parts: { BasePart },
	collectStack: { Instance },
	phase: "Collect" | "Sample" | "Done",
	partIndex: number,
	x: number,
	z: number,
	step: number,
	initialized: boolean,
	raycastParams: RaycastParams,
	overlapParams: OverlapParams,
	samples: number,
	rejected: number,
}

local BotWorld = {}
local DIRECTIONS = table.freeze({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis })

local function bucketKey(position: Vector3): string
	return `{math.floor(position.X / Config.mapBucketSize)}:{math.floor(position.Y / Config.mapBucketSize)}:{math.floor(position.Z / Config.mapBucketSize)}`
end

local function isBarrier(instance: Instance): boolean
	local current: Instance? = instance
	while current do
		if current.Name == "Barriers" then return true end
		current = current.Parent
	end
	return false
end

local function isSurface(part: BasePart): boolean
	return part.CanCollide
		and part.CFrame.UpVector.Y >= Config.walkableNormalY
		and not isBarrier(part)
		and part.Name ~= "SpawnLocation"
end

local function isPrecision(part: BasePart): boolean
	return CollectionService:HasTag(part, Config.mapPrecisionSurfaceTag)
		or math.min(part.Size.X, part.Size.Z) <= 2
end

local function nearbyNode(world: RWorld, position: Vector3): boolean
	local radius = Config.mapMinimumNodeSpacing
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				local probe = position + Vector3.new(x, y, z) * Config.mapBucketSize
				local bucket = world.buckets[bucketKey(probe)]
				if not bucket then continue end
				for _, nodeId in bucket do
					if (world.nodes[nodeId].position - position).Magnitude < radius then return true end
				end
			end
		end
	end
	return false
end

local function addNode(job: RBuildJob, hit: RaycastResult)
	if #job.world.nodes >= Config.mapMaximumNodes then return end
	if hit.Normal.Y < Config.walkableNormalY or not hit.Instance:IsA("BasePart") then
		job.rejected += 1
		return
	end
	local surface = hit.Instance :: BasePart
	if not isSurface(surface) then return end
	local position = hit.Position + Vector3.yAxis * Config.rootFloorOffset
	if nearbyNode(job.world, position) then return end

	local bodyCenter = position - Vector3.yAxis * (Config.rootFloorOffset - Config.bodyHeight * 0.5)
	local overlaps = Workspace:GetPartBoundsInBox(
		CFrame.new(bodyCenter),
		Vector3.new(Config.bodyWidth, Config.bodyHeight - 0.3, Config.bodyWidth),
		job.overlapParams
	)
	for _, part in overlaps do
		if part ~= surface and part.CanCollide then
			job.rejected += 1
			return
		end
	end

	local ceiling = Workspace:Raycast(hit.Position + Vector3.yAxis * 0.1, Vector3.yAxis * 7, job.raycastParams)
	local clearance = if ceiling then ceiling.Position.Y - hit.Position.Y else 7
	if clearance < Config.minimumHeadroom then return end
	local openDirections = 0
	local nearestWall = 12
	local barrierAdjacent = false
	for _, direction in DIRECTIONS do
		local wall = Workspace:Raycast(position + Vector3.yAxis, direction * 12, job.raycastParams)
		if not wall then
			openDirections += 1
		else
			nearestWall = math.min(nearestWall, wall.Distance)
			barrierAdjacent = barrierAdjacent or isBarrier(wall.Instance)
		end
	end

	local node: RNode = {
		id = #job.world.nodes + 1,
		position = position,
		floorPosition = hit.Position,
		surface = surface,
		clearance = clearance,
		openDirections = openDirections,
		nearestWall = nearestWall,
		barrierAdjacent = barrierAdjacent,
		edges = {},
		exitCount = 0,
		hasVerticalExit = false,
	}
	job.world.nodes[node.id] = node
	local key = bucketKey(position)
	local bucket = job.world.buckets[key]
	if not bucket then
		bucket = {}
		job.world.buckets[key] = bucket
	end
	bucket[#bucket + 1] = node.id
end

local function initializePart(job: RBuildJob, part: BasePart)
	job.step = if isPrecision(part) then Config.mapPrecisionStep else Config.mapStep
	job.x = -part.Size.X * 0.5 + math.min(job.step * 0.5, part.Size.X * 0.5)
	job.z = -part.Size.Z * 0.5 + math.min(job.step * 0.5, part.Size.Z * 0.5)
	job.initialized = true
end

local function samplePart(job: RBuildJob, part: BasePart): boolean
	if not job.initialized then initializePart(job, part) end
	local localPoint = Vector3.new(job.x, part.Size.Y * 0.5, job.z)
	local worldPoint = part.CFrame:PointToWorldSpace(localPoint)
	local hit = Workspace:Raycast(worldPoint + Vector3.yAxis * 1.5, -Vector3.yAxis * 3, job.raycastParams)
	job.samples += 1
	if hit then addNode(job, hit) end
	job.x += job.step
	if job.x <= part.Size.X * 0.5 then return false end
	job.x = -part.Size.X * 0.5 + math.min(job.step * 0.5, part.Size.X * 0.5)
	job.z += job.step
	return job.z > part.Size.Z * 0.5
end

function BotWorld.createBuildJob(): RBuildJob
	local map = Workspace:FindFirstChild("Map")
	assert(map, "[BotWorld.createBuildJob] workspace.Map is required")
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { map }
	raycastParams.IgnoreWater = true
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { map }
	overlapParams.RespectCanCollide = true
	local floorAttribute = map:GetAttribute("FloorY")
	local world: RWorld = {
		map = map,
		floorY = if typeof(floorAttribute) == "number" then floorAttribute else 0,
		nodes = {},
			edges = {},
			taughtEdges = {},
		buckets = {},
		ready = false,
		graphReady = false,
		version = 1,
	}
	return {
		world = world,
		parts = {},
		collectStack = { map },
		phase = "Collect",
		partIndex = 1,
		x = 0,
		z = 0,
		step = Config.mapStep,
		initialized = false,
		raycastParams = raycastParams,
		overlapParams = overlapParams,
		samples = 0,
		rejected = 0,
	}
end

function BotWorld.stepBuild(job: RBuildJob, budget: number?): boolean
	local started = os.clock()
	while os.clock() - started < (budget or Config.mapBuildBudget) do
		if job.phase == "Collect" then
			local instance = table.remove(job.collectStack)
			if not instance then
				job.phase = "Sample"
				continue
			end
			if instance:IsA("BasePart") and isSurface(instance) then job.parts[#job.parts + 1] = instance end
			for _, child in instance:GetChildren() do job.collectStack[#job.collectStack + 1] = child end
		elseif job.phase == "Sample" then
			local part = job.parts[job.partIndex]
			if not part then
				job.world.ready = #job.world.nodes > 0
				job.phase = "Done"
				return true
			end
			if not part.Parent or samplePart(job, part) then
				job.partIndex += 1
				job.initialized = false
			end
		else
			return true
		end
	end
	return false
end

function BotWorld.findNearby(world: RWorld, position: Vector3, radius: number): { RNode }
	local nodes = {}
	local bucketRadius = math.ceil(radius / Config.mapBucketSize)
	local centerX = math.floor(position.X / Config.mapBucketSize)
	local centerY = math.floor(position.Y / Config.mapBucketSize)
	local centerZ = math.floor(position.Z / Config.mapBucketSize)
	for x = centerX - bucketRadius, centerX + bucketRadius do
		for y = centerY - bucketRadius, centerY + bucketRadius do
			for z = centerZ - bucketRadius, centerZ + bucketRadius do
				local bucket = world.buckets[`{x}:{y}:{z}`]
				if not bucket then continue end
				for _, id in bucket do
					local node = world.nodes[id]
					if (node.position - position).Magnitude <= radius then nodes[#nodes + 1] = node end
				end
			end
		end
	end
	return nodes
end

function BotWorld.findNearest(world: RWorld, position: Vector3, radius: number?): RNode?
	local best: RNode? = nil
	local bestDistance = math.huge
	local searchRadius = radius or Config.climbNeighborRadius * 2
	local bucketRadius = math.ceil(searchRadius / Config.mapBucketSize)
	local centerX = math.floor(position.X / Config.mapBucketSize)
	local centerY = math.floor(position.Y / Config.mapBucketSize)
	local centerZ = math.floor(position.Z / Config.mapBucketSize)
	for x = centerX - bucketRadius, centerX + bucketRadius do
		for y = centerY - bucketRadius, centerY + bucketRadius do
			for z = centerZ - bucketRadius, centerZ + bucketRadius do
				local bucket = world.buckets[`{x}:{y}:{z}`]
				if not bucket then continue end
				for _, id in bucket do
					local node = world.nodes[id]
					local distance = (node.position - position).Magnitude
					if distance <= searchRadius and distance < bestDistance then
						best = node
						bestDistance = distance
					end
				end
			end
		end
	end
	return best
end

return table.freeze(BotWorld)
