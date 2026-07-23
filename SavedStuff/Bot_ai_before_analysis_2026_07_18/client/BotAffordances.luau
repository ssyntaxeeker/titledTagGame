--!strict
--[[
    BotAffordances (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Incrementally converts sampled root positions into executable movement
    transitions. Every non-walk edge owns concrete approach and contact data.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotWorld = require(ReplicatedStorage.Modules.Bot.BotWorld)
local ParkourMovementModel = require(ReplicatedStorage.Modules.Character.Parkour.ParkourMovementModel)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type Action = Types.Action
type REdge = Types.REdge
type RNode = Types.RNode
type RWorld = Types.RWorld

export type RBuildJob = {
	world: RWorld,
	phase: "Primary" | "RollBoost" | "Topology",
	nodeIndex: number,
	candidates: { RNode },
	candidateIndex: number,
	raycastParams: RaycastParams,
	done: boolean,
	dropLandings: { [number]: boolean },
}

local BotAffordances = {}

local function horizontal(fromPosition: Vector3, toPosition: Vector3): (Vector3, number)
	local delta = toPosition - fromPosition
	local flat = Vector3.new(delta.X, 0, delta.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero, flat.Magnitude
end

local function corridorClear(fromPosition: Vector3, toPosition: Vector3, params: RaycastParams): boolean
	local delta = toPosition - fromPosition
	return Workspace:Raycast(fromPosition + Vector3.yAxis * 0.4, delta, params) == nil
		and Workspace:Raycast(fromPosition + Vector3.yAxis * 2.3, delta, params) == nil
end

local function supported(fromNode: RNode, toNode: RNode, params: RaycastParams): boolean
	for index = 1, 3 do
		local alpha = index / 4
		local point = fromNode.position:Lerp(toNode.position, alpha)
		local hit = Workspace:Raycast(point + Vector3.yAxis, -Vector3.yAxis * 5, params)
		if not hit then return false end
	end
	return true
end

local function addEdge(
	job: RBuildJob,
	fromNode: RNode,
	toNode: RNode,
	action: Action,
	time: number,
	risk: number,
	approach: Vector3,
	direction: Vector3,
	target: Vector3,
	targetPart: BasePart?,
	height: number
)
	for _, edgeId in fromNode.edges do
		local existing = job.world.edges[edgeId]
		if existing.to == toNode.id and existing.action == action then return end
	end
	local edge: REdge = {
		id = #job.world.edges + 1,
		from = fromNode.id,
		to = toNode.id,
		action = action,
		time = time,
		risk = risk,
		approach = approach,
		direction = direction,
		target = target,
		targetPart = targetPart,
		height = height,
	}
	job.world.edges[edge.id] = edge
	fromNode.edges[#fromNode.edges + 1] = edge.id
end

local function buildCandidate(job: RBuildJob, fromNode: RNode, toNode: RNode)
	if fromNode.id == toNode.id then return end
	local direction, flatDistance = horizontal(fromNode.position, toNode.position)
	if flatDistance < 1 or direction.Magnitude == 0 then return end
	local height = toNode.floorPosition.Y - fromNode.floorPosition.Y
	local clear = corridorClear(fromNode.position, toNode.position, job.raycastParams)
	if CollectionService:HasTag(fromNode.surface, "Trampoline") and height > 0 and height <= 70 then
		addEdge(job, fromNode, toNode, "Trampoline", flatDistance / 42 + 0.45, 0.08, fromNode.position, direction, toNode.position, fromNode.surface, height)
	end

	if math.abs(height) <= Config.walkStepHeight
		and flatDistance <= Config.neighborRadius
		and clear
		and supported(fromNode, toNode, job.raycastParams)
	then
		addEdge(job, fromNode, toNode, "Walk", flatDistance / Config.walkSpeed, 0.02, fromNode.position, direction, toNode.position, nil, height)
		return
	end

	if height > Config.walkStepHeight
		and height <= Config.jumpHeight
		and flatDistance <= 7
		and clear
	then
		addEdge(job, fromNode, toNode, "Jump", flatDistance / Config.walkSpeed + 0.2, 0.12, fromNode.position, direction, toNode.position, toNode.surface, height)
		return
	end

	if height < -Config.walkStepHeight
		and math.abs(height) <= Config.maximumDrop
		and flatDistance <= Config.neighborRadius
		and clear
	then
		addEdge(job, fromNode, toNode, "Drop", flatDistance / Config.walkSpeed + math.sqrt(2 * math.abs(height) / Workspace.Gravity), 0.12, fromNode.position, direction, toNode.position, toNode.surface, height)
		if math.abs(height) >= 8 then job.dropLandings[toNode.id] = true end
		return
	end

	local swingProbe = ParkourMovementModel.probeSwing(fromNode.position, direction, {}, job.raycastParams)
	local bar = if swingProbe and swingProbe.result.Instance:IsA("BasePart")
		then swingProbe.result.Instance
		else nil
	if swingProbe and bar and height >= -3 and flatDistance <= Config.climbNeighborRadius then
		addEdge(job, fromNode, toNode, "Swing", flatDistance / 42 + 0.42, 0.2, fromNode.position, direction, toNode.position, bar, height)
		return
	end

	if height < 5 or height > Config.slideBoostMaximumHeight or flatDistance > Config.climbNeighborRadius then return end
	local wall = Workspace:Raycast(fromNode.position + Vector3.yAxis, direction * math.min(flatDistance, 12), job.raycastParams)
	if not wall or math.abs(wall.Normal.Y) > 0.3 or wall.Normal:Dot(direction) > -0.45 then return end
	if wall.Instance:GetAttribute("NoClimb") == true then return end
	if wall.Instance:IsA("TrussPart") then
		addEdge(job, fromNode, toNode, "TrussClimb", flatDistance / 18 + math.max(0, height) / 18, 0.08, fromNode.position, direction, toNode.position, wall.Instance, height)
		return
	end

	local action: Action
	local risk: number
	local runup: number
	if height <= Config.groundVaultHeight then
		action = "Vault"
		risk = 0.1
		runup = 2.5
	elseif height <= Config.highVaultHeight then
		action = "HighVault"
		risk = 0.2
		runup = 5
	else
		action = "SlideBoost"
		risk = 0.38
		runup = 14
	end
	local approach = Vector3.new(wall.Position.X, fromNode.position.Y, wall.Position.Z) - direction * runup
	if action == "SlideBoost" then
		if (fromNode.position - approach).Magnitude > Config.mapStep * 1.75 then return end
		for index = 0, 4 do
			local point = approach + direction * (runup * index / 4)
			local ground = Workspace:Raycast(point + Vector3.yAxis, -Vector3.yAxis * 4, job.raycastParams)
			if not ground or math.abs(ground.Position.Y - fromNode.floorPosition.Y) > 0.35 then return end
		end
	end
	addEdge(job, fromNode, toNode, action, flatDistance / Config.walkSpeed + (if action == "SlideBoost" then 0.55 else 0.2), risk, approach, direction, toNode.position, wall.Instance :: BasePart, height)

end

local function buildRollBoost(job: RBuildJob, fromNode: RNode, toNode: RNode)
	if not job.dropLandings[fromNode.id] or fromNode.id == toNode.id then return end
	local direction, flatDistance = horizontal(fromNode.position, toNode.position)
	local height = toNode.floorPosition.Y - fromNode.floorPosition.Y
	if height <= Config.walkStepHeight or height > 16 or flatDistance > 12 then return end
	if not corridorClear(fromNode.position, toNode.position, job.raycastParams) then return end
	addEdge(job, fromNode, toNode, "RollBoost", flatDistance / (Config.walkSpeed * 1.3) + Config.rollBoostDelay, 0.24, fromNode.position, direction, toNode.position, toNode.surface, height)
end

local function buildTopology(job: RBuildJob, node: RNode)
	local destinations: { [number]: boolean } = {}
	local exits = 0
	local vertical = false
	for _, edgeId in node.edges do
		local edge = job.world.edges[edgeId]
		if not destinations[edge.to] then
			destinations[edge.to] = true
			exits += 1
		end
		vertical = vertical or math.abs(edge.height) > Config.walkStepHeight
	end
	node.exitCount = exits
	node.hasVerticalExit = vertical
end

function BotAffordances.createBuildJob(world: RWorld): RBuildJob
	assert(world.ready, "[BotAffordances.createBuildJob] world must be ready")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world.map }
	params.IgnoreWater = true
	table.clear(world.edges)
	for _, node in world.nodes do table.clear(node.edges) end
	return {
		world = world,
		phase = "Primary",
		nodeIndex = 1,
		candidates = {},
		candidateIndex = 1,
		raycastParams = params,
		done = false,
		dropLandings = {},
	}
end

function BotAffordances.stepBuild(job: RBuildJob, budget: number?): boolean
	local started = os.clock()
	while os.clock() - started < (budget or Config.graphBuildBudget) do
		local fromNode = job.world.nodes[job.nodeIndex]
		if not fromNode then
			if job.phase == "Primary" then
				job.phase = "RollBoost"
				job.nodeIndex = 1
				table.clear(job.candidates)
				continue
			elseif job.phase == "RollBoost" then
				job.phase = "Topology"
				job.nodeIndex = 1
				table.clear(job.candidates)
				continue
			else
				job.world.graphReady = true
				job.done = true
				return true
			end
		end
		if job.phase == "Topology" then
			buildTopology(job, fromNode)
			job.nodeIndex += 1
			continue
		end
		if #job.candidates == 0 then
			job.candidates = BotWorld.findNearby(job.world, fromNode.position, Config.climbNeighborRadius)
			job.candidateIndex = 1
		end
		local toNode = job.candidates[job.candidateIndex]
		if toNode then
			if job.phase == "Primary" then buildCandidate(job, fromNode, toNode) else buildRollBoost(job, fromNode, toNode) end
			job.candidateIndex += 1
		else
			table.clear(job.candidates)
			job.nodeIndex += 1
		end
	end
	return false
end

return table.freeze(BotAffordances)
