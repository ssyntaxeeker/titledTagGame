--!strict
--[[
    BotAffordanceGraph (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Builds and queries a static movement graph with UTG-style affordance edges.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotTypes = require(ReplicatedStorage.Modules.Bot.BotTypes)

type ActionKind = BotTypes.ActionKind
type RGraph = BotTypes.RGraph
type RGraphNode = BotTypes.RGraphNode
type RGraphEdge = BotTypes.RGraphEdge
type RNodeKnowledge = {
	wallMask: number,
	openDirections: number,
	openness: number,
	nearestWallDistance: number,
	headClearance: number,
	dropHeight: number,
	escapeScore: number,
	climbScore: number,
	rollSetupScore: number,
	isTrampoline: boolean?,
}

local BotAffordanceGraph = {}

local function cellKey(position: Vector3, cellSize: number): string
	return `{math.floor(position.X / cellSize)}:{math.floor(position.Y / cellSize)}:{math.floor(position.Z / cellSize)}`
end

local function nodeCellKey(position: Vector3, cellSize: number): string
	return `{math.floor(position.X / cellSize)}:{math.floor(position.Y / cellSize)}:{math.floor(position.Z / cellSize)}`
end

local function sectorKey(position: Vector3): string
	return `{math.floor(position.X / 64)}:{math.floor(position.Y / 64)}:{math.floor(position.Z / 64)}`
end

local function isBarrierPart(part: BasePart): boolean
	local current: Instance? = part
	while current do
		if current.Name == "Barriers" then return true end
		current = current.Parent
	end

	return false
end

local function edgeAction(heightDelta: number, distance: number): ActionKind?
	if heightDelta <= -Config.minRollDropHeight and distance <= Config.dropEdgeMaxDistance then return "Roll" end
	if heightDelta < -Config.maxWalkHeight and distance <= Config.dropEdgeMaxDistance then return "Drop" end
	if math.abs(heightDelta) <= Config.maxWalkHeight and distance <= Config.neighborRadius then return "Walk" end
	if heightDelta <= Config.maxJumpHeight and distance <= Config.jumpEdgeMaxDistance then return "Jump" end
	if heightDelta <= Config.maxVaultHeight and distance <= Config.vaultEdgeMaxDistance then
		return if heightDelta >= Config.highVaultMinHeight then "HighVault" else "Vault"
	end
	if heightDelta <= Config.maxSlideBoostHeight and distance <= Config.slideBoostEdgeMaxDistance then return "SlideBoost" end

	return nil
end

local function edgeCost(action: ActionKind, flatDistance: number, heightDelta: number, wallPenalty: number): number
	local actionCost = BotTypes.ActionCost[action] or 1
	local cost = flatDistance * actionCost + math.max(0, wallPenalty)

	if action == "Roll" then
		cost -= math.min(10, math.abs(heightDelta) * 0.45)
	elseif action == "Drop" then
		cost -= math.min(4, math.abs(heightDelta) * 0.2)
	elseif action == "Vault" or action == "HighVault" then
		cost += math.max(0, heightDelta - 5.5) * 0.2
	elseif action == "SlideBoost" then
		cost += 3
	end

	return math.max(1, cost)
end

local function makeEdgeRaycastParams(): RaycastParams
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local exclude = {}
	local bots = Workspace:FindFirstChild("Bots")
	local debugFolder = Workspace:FindFirstChild("BotDebug")
	local camera = Workspace.CurrentCamera
	if bots then exclude[#exclude + 1] = bots end
	if debugFolder then exclude[#exclude + 1] = debugFolder end
	if camera then exclude[#exclude + 1] = camera end
	raycastParams.FilterDescendantsInstances = exclude

	return raycastParams
end

local function getHorizontalHit(fromPosition: Vector3, toPosition: Vector3, raycastParams: RaycastParams): RaycastResult?
	local flatDelta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	if flatDelta.Magnitude <= 0.1 then return nil end

	local origin = fromPosition + Vector3.yAxis * 0.35
	return Workspace:Raycast(origin, flatDelta, raycastParams)
end

local function hasBodyClearance(fromPosition: Vector3, toPosition: Vector3, height: number, raycastParams: RaycastParams): boolean
	local flatDelta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	if flatDelta.Magnitude <= 0.1 then return true end

	local result = Workspace:Raycast(fromPosition + Vector3.yAxis * height, flatDelta, raycastParams)
	return result == nil
end

local function isSwingBar(instance: Instance): boolean
	return instance:GetAttribute("SwingBar") == true or (instance.Parent and instance.Parent:GetAttribute("SwingBar") == true)
end

local function isTrampoline(instance: Instance): boolean
	return CollectionService:HasTag(instance, "Trampoline")
end

local function edgeIsAllowed(fromNode: RGraphNode, toNode: RGraphNode, action: ActionKind, raycastParams: RaycastParams): (boolean, number, ActionKind?, Vector3?)
	local hit = getHorizontalHit(fromNode.position, toNode.position, raycastParams)
	local flatDistance = Vector3.new(
		toNode.position.X - fromNode.position.X,
		0,
		toNode.position.Z - fromNode.position.Z
	).Magnitude

	if action == "Walk" or action == "Jump" or action == "Trampoline" then
		if hit and (hit.Position - fromNode.position).Magnitude < flatDistance - 0.6 then
			if isSwingBar(hit.Instance) then return true, (hit.Position - fromNode.position).Magnitude, "Swing", hit.Position end
			if isTrampoline(hit.Instance) then return true, (hit.Position - fromNode.position).Magnitude, "Trampoline", hit.Position end
			if toNode.position.Y > fromNode.position.Y and hasBodyClearance(fromNode.position, toNode.position, Config.stairHeadClearanceHeight, raycastParams) then
				return true, (hit.Position - fromNode.position).Magnitude, nil, hit.Position
			end
			return false, 0, nil, nil
		end
		return true, flatDistance, nil, nil
	end

	if action == "Drop" or action == "Roll" then
		if hit and (hit.Position - fromNode.position).Magnitude < flatDistance - 0.6 then return false, 0, nil, nil end
		return true, flatDistance, nil, nil
	end

	if action == "Vault" or action == "HighVault" then
		if not hit then return false, math.huge, nil, nil end
		local hitDistance = (hit.Position - fromNode.position).Magnitude
		if hitDistance > Config.vaultEdgeMaxDistance then return false, hitDistance, nil, nil end
		if isSwingBar(hit.Instance) then return true, hitDistance, "Swing", hit.Position end
		return true, hitDistance, nil, hit.Position
	end

	if action == "SlideBoost" then
		if not hit then return false, math.huge, nil, nil end
		local hitDistance = (hit.Position - fromNode.position).Magnitude
		if hitDistance < Config.slideBoostMinWallClearance or hitDistance > Config.slideBoostMaxWallClearance then
			return false, hitDistance, nil, nil
		end
		return true, hitDistance, nil, hit.Position
	end

	return true, flatDistance, nil, nil
end

function BotAffordanceGraph.createEmpty(center: Vector3?, size: Vector3?): RGraph
	return {
		nodes = {},
		nodeByCell = {},
		sectors = {},
		spatialBuckets = {},
		boundsCenter = center or Vector3.zero,
		boundsSize = size or Vector3.zero,
		version = 0,
	}
end

function BotAffordanceGraph.addNode(graph: RGraph, position: Vector3, wallPenalty: number, verticalScore: number, knowledge: RNodeKnowledge?): RGraphNode?
	if #graph.nodes >= Config.maxGraphNodes then return nil end

	local key = nodeCellKey(position, Config.graphStep)
	if graph.nodeByCell[key] then return nil end

	local node: RGraphNode = {
		id = #graph.nodes + 1,
		position = position,
		sectorKey = sectorKey(position),
		wallPenalty = wallPenalty,
		verticalScore = verticalScore,
		wallMask = if knowledge then knowledge.wallMask else 0,
		openDirections = if knowledge then knowledge.openDirections else math.max(0, 8 - math.floor(wallPenalty / 2)),
		openness = if knowledge then knowledge.openness else 0.5,
		nearestWallDistance = if knowledge then knowledge.nearestWallDistance else Config.knowledgeWallProbeDistance,
		headClearance = if knowledge then knowledge.headClearance else Config.knowledgeHeadProbeHeight,
		dropHeight = if knowledge then knowledge.dropHeight else 0,
		escapeScore = if knowledge then knowledge.escapeScore else 0,
		climbScore = if knowledge then knowledge.climbScore else 0,
		rollSetupScore = if knowledge then knowledge.rollSetupScore else 0,
		isTrampoline = if knowledge and knowledge.isTrampoline == true then true else false,
		edges = {},
	}

	graph.nodes[node.id] = node
	graph.nodeByCell[key] = node.id

	local sector = graph.sectors[node.sectorKey]
	if not sector then
		sector = {}
		graph.sectors[node.sectorKey] = sector
	end
	sector[#sector + 1] = node.id

	return node
end

function BotAffordanceGraph.rebuildEdges(graph: RGraph)
	local buckets: { [string]: { number } } = {}
	local bucketSize = Config.maxTechNeighborRadius
	local edgeRaycastParams = makeEdgeRaycastParams()
	table.clear(graph.spatialBuckets)

	for _, node in graph.nodes do
		table.clear(node.edges)
		local key = cellKey(node.position, bucketSize)
		local bucket = buckets[key]
		if not bucket then
			bucket = {}
			buckets[key] = bucket
		end
		bucket[#bucket + 1] = node.id
		graph.spatialBuckets[key] = bucket
	end

	for _, node in graph.nodes do
		local xCell = math.floor(node.position.X / bucketSize)
		local yCell = math.floor(node.position.Y / bucketSize)
		local zCell = math.floor(node.position.Z / bucketSize)

		for xOffset = -1, 1 do
			for yOffset = -1, 1 do
				for zOffset = -1, 1 do
					local bucket = buckets[`{xCell + xOffset}:{yCell + yOffset}:{zCell + zOffset}`]
					if not bucket then continue end

					for _, otherId in bucket do
						if otherId == node.id then continue end

						local other = graph.nodes[otherId]
						local delta = other.position - node.position
						local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
						if flatDistance <= 0.1 or flatDistance > Config.maxTechNeighborRadius then continue end

						local action = if node.isTrampoline and delta.Y <= Config.trampolineMaxHeight and flatDistance <= Config.trampolineEdgeMaxDistance
							then "Trampoline" :: ActionKind
							else edgeAction(delta.Y, flatDistance)
						if not action then continue end
						local allowed, clearance, actionOverride, contactPosition = edgeIsAllowed(node, other, action, edgeRaycastParams)
						if not allowed then continue end
						local finalAction = actionOverride or action

						local edge: RGraphEdge = {
							to = otherId,
							cost = edgeCost(finalAction, flatDistance, delta.Y, other.wallPenalty),
							action = finalAction,
							heightDelta = delta.Y,
							clearance = clearance,
							contactPosition = contactPosition,
						}
						node.edges[#node.edges + 1] = edge
					end
				end
			end
		end
	end

	graph.version += 1
end

function BotAffordanceGraph.findNearestNode(graph: RGraph, position: Vector3, maxDistance: number?): RGraphNode?
	local bestNode: RGraphNode? = nil
	local bestDistance = maxDistance or math.huge
	local sectorSize = 64
	local xCell = math.floor(position.X / sectorSize)
	local yCell = math.floor(position.Y / sectorSize)
	local zCell = math.floor(position.Z / sectorSize)

	for xOffset = -2, 2 do
		for yOffset = -2, 2 do
			for zOffset = -2, 2 do
				local sector = graph.sectors[`{xCell + xOffset}:{yCell + yOffset}:{zCell + zOffset}`]
				if not sector then continue end

				for _, nodeId in sector do
					local node = graph.nodes[nodeId]
					local distance = (node.position - position).Magnitude
					if distance < bestDistance then
						bestNode = node
						bestDistance = distance
					end
				end
			end
		end
	end

	if bestNode then return bestNode end

	for _, node in graph.nodes do
		local distance = (node.position - position).Magnitude
		if distance < bestDistance then
			bestNode = node
			bestDistance = distance
		end
	end

	return bestNode
end

function BotAffordanceGraph.isBarrierPart(part: BasePart): boolean
	return isBarrierPart(part)
end

return BotAffordanceGraph
