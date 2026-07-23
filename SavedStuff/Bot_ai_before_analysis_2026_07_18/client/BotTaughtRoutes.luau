--!strict
--[[
    BotTaughtRoutes (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Persists map-specific demonstrated transitions and injects them into the
    live graph. Nearby useful demonstrations bypass broad route discovery.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotKnowledge = require(ReplicatedStorage.Modules.Bot.BotKnowledge)
local BotWorld = require(ReplicatedStorage.Modules.Bot.BotWorld)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type Action = Types.Action
type REdge = Types.REdge
type RMemory = BotKnowledge.RMemory
type RPlan = Types.RPlan
type RWorld = Types.RWorld

local BotTaughtRoutes = {}
local nextPlanId = 1_000_000
local POSITION_STEP = 2
local ACTIONS: { [string]: boolean } = table.freeze({
	Walk = true, Jump = true, Vault = true, HighVault = true,
	TrussClimb = true, Swing = true, Drop = true, RollBoost = true,
	SlideBoost = true, Trampoline = true,
})

local function mapName(world: RWorld?): string
	local attribute = Workspace:GetAttribute("Map")
	local map = if world then world.map else Workspace:FindFirstChild("Map")
	local namedAttribute = if map then map:GetAttribute("MapName") else nil
	local raw = if typeof(attribute) == "string"
		then attribute
		elseif typeof(namedAttribute) == "string"
		then namedAttribute
		elseif map
		then map.Name
		else "Unknown"
	return string.sub((raw :: string):gsub(":", "_"), 1, 24)
end

local function quantized(position: Vector3): string
	return `{math.floor(position.X / POSITION_STEP + 0.5)}:{math.floor(position.Y / POSITION_STEP + 0.5)}:{math.floor(position.Z / POSITION_STEP + 0.5)}`
end

local function parse(key: string): (string?, Action?, Vector3?, Vector3?)
	local name, action, sx, sy, sz, tx, ty, tz = string.match(
		key,
		"^TR3:([^:]+):([^:]+):([%-]?%d+):([%-]?%d+):([%-]?%d+)%>([%-]?%d+):([%-]?%d+):([%-]?%d+)$"
	)
	if not name or not action or not ACTIONS[action] then return nil, nil, nil, nil end
	local start = Vector3.new(tonumber(sx) :: number, tonumber(sy) :: number, tonumber(sz) :: number) * POSITION_STEP
	local target = Vector3.new(tonumber(tx) :: number, tonumber(ty) :: number, tonumber(tz) :: number) * POSITION_STEP
	return name, action :: Action, start, target
end

local function updateTopology(world: RWorld, nodeId: number)
	local node = world.nodes[nodeId]
	local destinations: { [number]: boolean } = {}
	local exits = 0
	local vertical = false
	for _, edgeId in node.edges do
		local edge = world.edges[edgeId]
		if not destinations[edge.to] then
			destinations[edge.to] = true
			exits += 1
		end
		vertical = vertical or math.abs(edge.height) > Config.walkStepHeight
	end
	node.exitCount = exits
	node.hasVerticalExit = vertical
end

function BotTaughtRoutes.recordVault(memory: RMemory, startPosition: Vector3, targetPosition: Vector3): string
	local height = targetPosition.Y - startPosition.Y
	local action = if height > Config.groundVaultHeight then "HighVault" else "Vault"
	local base = `{mapName(nil)}:{action}:{quantized(startPosition)}>{quantized(targetPosition)}`
	local evidenceKey = `TR3:{base}`
	local timingKey = `TT3:{base}`
	memory.playerRoutes[evidenceKey] = math.clamp((memory.playerRoutes[evidenceKey] or 0) + 20, 0, 500)
	memory.playerRoutes[timingKey] = math.clamp((memory.playerRoutes[timingKey] or 0) + 10, 0, 500)
	memory.dirtyPlayerRoutes[evidenceKey] = (memory.dirtyPlayerRoutes[evidenceKey] or 0) + 20
	memory.dirtyPlayerRoutes[timingKey] = (memory.dirtyPlayerRoutes[timingKey] or 0) + 10
	return action
end

function BotTaughtRoutes.apply(world: RWorld, memory: RMemory): number
	local expectedMap = mapName(world)
	local added = 0
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { world.map }
	raycastParams.IgnoreWater = true
	for key, evidence in memory.playerRoutes do
		if string.sub(key, 1, 4) ~= "TR3:" or evidence <= 0 then continue end
		local savedMap, action, startPosition, targetPosition = parse(key)
		if savedMap ~= expectedMap or not action or not startPosition or not targetPosition then continue end
		local fromNode = BotWorld.findNearest(world, startPosition, 8)
		local toNode = BotWorld.findNearest(world, targetPosition, 8)
		if not fromNode or not toNode or fromNode.id == toNode.id then continue end
		local existingEdge: REdge? = nil
		for _, edgeId in fromNode.edges do
			local candidate = world.edges[edgeId]
			if candidate.to == toNode.id and candidate.action == action then
				existingEdge = candidate
				break
			end
		end
		if existingEdge then
			existingEdge.taught = true
			existingEdge.taughtEvidence = math.max(existingEdge.taughtEvidence or 0, evidence)
			local demonstratedFlat = Vector3.new(targetPosition.X - startPosition.X, 0, targetPosition.Z - startPosition.Z)
			if demonstratedFlat.Magnitude >= 0.5 then
				existingEdge.approach = startPosition
				existingEdge.direction = demonstratedFlat.Unit
				existingEdge.target = toNode.position
			end
			if not table.find(world.taughtEdges, existingEdge.id) then world.taughtEdges[#world.taughtEdges + 1] = existingEdge.id end
			continue
		end
		local flat = Vector3.new(targetPosition.X - startPosition.X, 0, targetPosition.Z - startPosition.Z)
		if flat.Magnitude < 0.5 then continue end
		local direction = flat.Unit
		local hit = Workspace:Raycast(startPosition + Vector3.yAxis, direction * math.min(flat.Magnitude + 4, 18), raycastParams)
		local targetPart = if hit and hit.Instance:IsA("BasePart") then hit.Instance else toNode.surface
		local durationKey = `TT3:{string.sub(key, 5)}`
		local duration = math.clamp((memory.playerRoutes[durationKey] or evidence * 0.5) / evidence, 0.15, 5)
		local edge: REdge = {
			id = #world.edges + 1,
			from = fromNode.id,
			to = toNode.id,
			action = action,
			time = duration,
			risk = math.clamp(0.12 - evidence * 0.002, 0.02, 0.12),
			approach = startPosition,
			direction = direction,
			target = toNode.position,
			targetPart = targetPart,
			height = toNode.floorPosition.Y - fromNode.floorPosition.Y,
			taught = true,
			taughtEvidence = evidence,
		}
		world.edges[edge.id] = edge
		fromNode.edges[#fromNode.edges + 1] = edge.id
		world.taughtEdges[#world.taughtEdges + 1] = edge.id
		updateTopology(world, fromNode.id)
		added += 1
	end
	return added
end

function BotTaughtRoutes.findUsefulEdge(
	world: RWorld,
	position: Vector3,
	goal: Vector3,
	blockedEdges: { [number]: number }
): REdge?
	local best: REdge? = nil
	local bestScore = -math.huge
	local currentDistance = (goal - position).Magnitude
	local currentFlatDistance = (Vector3.new(goal.X, position.Y, goal.Z) - position).Magnitude
	for _, edgeId in world.taughtEdges do
		if (blockedEdges[edgeId] or 0) > os.clock() then continue end
		local edge = world.edges[edgeId]
		local approachDistance = (edge.approach - position).Magnitude
		if approachDistance > Config.taughtRouteActivationRadius then continue end
		local targetDistance = (goal - edge.target).Magnitude
		local targetFlatDistance = (Vector3.new(goal.X, edge.target.Y, goal.Z) - edge.target).Magnitude
		local progress = currentDistance - targetDistance
		local verticalUseful = goal.Y - position.Y > Config.plannerGoalLayerTolerance
			and edge.target.Y > position.Y + Config.walkStepHeight
			and targetFlatDistance <= currentFlatDistance + Config.taughtRouteProgressTolerance
		if progress < -Config.taughtRouteProgressTolerance and not verticalUseful then continue end
		local score = progress * 2 - approachDistance * 1.25 + math.min(edge.taughtEvidence or 0, 100) * 0.08
		if verticalUseful then score += (edge.target.Y - position.Y) * 1.5 end
		if score > bestScore then
			best = edge
			bestScore = score
		end
	end
	return best
end

function BotTaughtRoutes.plan(edge: REdge, goal: Vector3): RPlan
	nextPlanId += 1
	return {
		id = nextPlanId,
		goal = goal,
		nodes = { edge.from, edge.to },
		edges = { edge.id },
		cost = math.max(0.02, edge.time - 0.1),
		time = edge.time,
		success = 1 - edge.risk,
		createdAt = os.clock(),
	}
end

return table.freeze(BotTaughtRoutes)
