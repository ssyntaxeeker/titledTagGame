--!strict
--[[
    BotPlanner (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Frame-budgeted graph search. No Roblox PathfindingService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotAffordanceGraph = require(ReplicatedStorage.Modules.Bot.BotAffordanceGraph)
local BotLearning = require(ReplicatedStorage.Modules.Bot.BotLearning)
local BotPolicy = require(ReplicatedStorage.Modules.Bot.BotPolicy)

type RGraph = any
type RGraphNode = any
type RPlannerJob = {
	startNodeId: number,
	goalNodeId: number,
	open: { number },
	openSet: { [number]: boolean },
	cameFrom: { [number]: number },
	costSoFar: { [number]: number },
	closed: { [number]: boolean },
	expansions: number,
	bestNodeId: number,
	bestHeuristic: number,
	partial: boolean,
	done: boolean,
	failed: boolean,
	path: { number },
	role: string,
}

local BotPlanner = {}

local function heuristic(a: RGraphNode, b: RGraphNode): number
	return (a.position - b.position).Magnitude
end

local function getTraversalCost(
	memory: BotLearning.RLearningMemory,
	roleName: string,
	currentId: number,
	currentNode: RGraphNode,
	nextNode: RGraphNode,
	edge: any,
	goalNode: RGraphNode
): number
	local learnedMultiplier = BotLearning.getEdgeMultiplier(memory, currentId, edge.to)
	local learnedTechScore = BotLearning.getTechScore(memory, currentNode.position, edge.action)
	local deadEndPenalty = BotLearning.getDeadEndPenalty(memory, nextNode.position)
	local areaScore = BotLearning.getAreaScore(memory, nextNode.position)
	local policyScore = BotPolicy.scoreEdge(roleName, currentNode, nextNode, edge, goalNode, deadEndPenalty, areaScore, nil)
	local currentGoalDistance = (currentNode.position - goalNode.position).Magnitude
	local nextGoalDistance = (nextNode.position - goalNode.position).Magnitude
	local progress = currentGoalDistance - nextGoalDistance
	local cost = edge.cost * learnedMultiplier + deadEndPenalty

	if progress > 0 then cost -= math.min(6, progress * 0.18) end
	if areaScore ~= 0 then cost -= math.clamp(areaScore, -8, 8) * 0.35 end
	if nextNode.verticalScore > currentNode.verticalScore and progress > -18 then cost -= math.min(4, (nextNode.verticalScore - currentNode.verticalScore) * 0.04) end
	cost -= math.clamp((nextNode.openness or 0) * 2.2, 0, 2.2)
	cost -= math.clamp((nextNode.escapeScore or 0) * 0.08, -1.5, 2)
	cost += math.max(0, 3 - (nextNode.openDirections or 0)) * 2.2
	cost += math.max(0, Config.wallProbeDistance - (nextNode.nearestWallDistance or Config.knowledgeWallProbeDistance)) * 0.45

	if edge.action == "Roll" then
		cost -= 5 + math.clamp(nextNode.rollSetupScore or 0, 0, 4)
	elseif edge.action == "Swing" then
		cost -= if progress > -18 then 4 else 0
	elseif edge.action == "Drop" then
		cost -= 2
	elseif edge.action == "Vault" or edge.action == "HighVault" then
		cost -= if progress > -10 then 2 + math.clamp(currentNode.climbScore or 0, 0, 2) else 0
	elseif edge.action == "SlideBoost" then
		cost -= if progress > -12 then 1 + math.clamp(currentNode.climbScore or 0, 0, 3) else -5
	elseif edge.action == "Trampoline" then
		cost -= if progress > -18 then 6 else 2
	elseif edge.action == "Jump" then
		cost -= if progress > 0 then 1.5 else -1
	end
	if learnedTechScore ~= 0 then cost -= math.clamp(learnedTechScore, -8, 8) end
	if policyScore ~= 0 then cost -= policyScore * Config.policyScoreWeight end

	return math.max(0.5, cost)
end

local function popBestOpen(job: RPlannerJob, graph: RGraph): number?
	local bestOpenIndex = 0
	local bestScore = math.huge
	local goalNode = graph.nodes[job.goalNodeId]

	for openIndex, nodeId in job.open do
		local node = graph.nodes[nodeId]
		local score = (job.costSoFar[nodeId] or math.huge) + heuristic(node, goalNode)
		if score < bestScore then
			bestOpenIndex = openIndex
			bestScore = score
		end
	end

	if bestOpenIndex == 0 then return nil end

	local nodeId = job.open[bestOpenIndex]
	job.open[bestOpenIndex] = job.open[#job.open]
	job.open[#job.open] = nil
	job.openSet[nodeId] = nil
	return nodeId
end

local function rebuildPath(job: RPlannerJob)
	table.clear(job.path)

	local current = job.goalNodeId
	while current ~= job.startNodeId do
		table.insert(job.path, 1, current)
		local previous = job.cameFrom[current]
		if not previous then
			table.clear(job.path)
			job.failed = true
			return
		end
		current = previous
	end

	table.insert(job.path, 1, job.startNodeId)
end

local function rebuildPathTo(job: RPlannerJob, endNodeId: number)
	table.clear(job.path)

	local current = endNodeId
	while current ~= job.startNodeId do
		table.insert(job.path, 1, current)
		local previous = job.cameFrom[current]
		if not previous then
			table.clear(job.path)
			return
		end
		current = previous
	end

	table.insert(job.path, 1, job.startNodeId)
end

function BotPlanner.createJob(graph: RGraph, startPosition: Vector3, goalPosition: Vector3, roleName: string?): RPlannerJob?
	local startNode = BotAffordanceGraph.findNearestNode(graph, startPosition, 80)
	local goalNode = BotAffordanceGraph.findNearestNode(graph, goalPosition, 100)
	if not startNode or not goalNode then return nil end

	return {
		startNodeId = startNode.id,
		goalNodeId = goalNode.id,
		open = { startNode.id },
		openSet = { [startNode.id] = true },
		cameFrom = {},
		costSoFar = { [startNode.id] = 0 },
		closed = {},
		expansions = 0,
		bestNodeId = startNode.id,
		bestHeuristic = heuristic(startNode, goalNode),
		partial = false,
		done = false,
		failed = false,
		path = {},
		role = roleName or "Tagger",
	}
end

function BotPlanner.step(job: RPlannerJob, graph: RGraph, memory: BotLearning.RLearningMemory, budgetSeconds: number): boolean
	if job.done then return true end

	local startTime = os.clock()
	local stepExpansions = 0

	while os.clock() - startTime < budgetSeconds and stepExpansions < Config.maxPlannerExpansionsPerStep do
		local currentId = popBestOpen(job, graph)
		if not currentId then
			job.done = true
			job.failed = true
			return true
		end

		if currentId == job.goalNodeId then
			job.done = true
			job.partial = false
			rebuildPath(job)
			return true
		end

		job.closed[currentId] = true
		local currentNode = graph.nodes[currentId]
		local goalNode = graph.nodes[job.goalNodeId]
		local currentHeuristic = heuristic(currentNode, goalNode)
		if currentHeuristic < job.bestHeuristic then
			job.bestHeuristic = currentHeuristic
			job.bestNodeId = currentId
		end

		for _, edge in currentNode.edges do
			if job.closed[edge.to] then continue end

			local nextNode = graph.nodes[edge.to]
			local newCost = (job.costSoFar[currentId] or 0)
				+ getTraversalCost(memory, job.role, currentId, currentNode, nextNode, edge, goalNode)
			local oldCost = job.costSoFar[edge.to]

			if not oldCost or newCost < oldCost then
				job.costSoFar[edge.to] = newCost
				job.cameFrom[edge.to] = currentId
				if not job.openSet[edge.to] then
					job.open[#job.open + 1] = edge.to
					job.openSet[edge.to] = true
				end
			end
		end

		job.expansions += 1
		stepExpansions += 1

		if job.expansions >= Config.maxPlannerTotalExpansions then
			job.done = true
			job.partial = true
			rebuildPathTo(job, job.bestNodeId)
			job.failed = #job.path <= 1
			return true
		end
	end

	return false
end

function BotPlanner.getNextPathPosition(graph: RGraph, path: { number }, cursor: number): (Vector3?, number)
	while path[cursor] do
		local node = graph.nodes[path[cursor]]
		if node then return node.position, cursor end
		cursor += 1
	end

	return nil, cursor
end

function BotPlanner.getPathAction(graph: RGraph, path: { number }, cursor: number): string
	local fromId = path[math.max(1, cursor - 1)]
	local toId = path[cursor]
	if not fromId or not toId then return "Walk" end

	local fromNode = graph.nodes[fromId]
	if not fromNode then return "Walk" end

	for _, edge in fromNode.edges do
		if edge.to == toId then return edge.action end
	end

	return "Walk"
end

function BotPlanner.getPathEdge(graph: RGraph, path: { number }, cursor: number): any?
	local fromId = path[math.max(1, cursor - 1)]
	local toId = path[cursor]
	if not fromId or not toId then return nil end

	local fromNode = graph.nodes[fromId]
	if not fromNode then return nil end

	for _, edge in fromNode.edges do
		if edge.to == toId then return edge end
	end

	return nil
end

function BotPlanner.estimatePathCost(graph: RGraph, path: { number }, cursor: number): (number, number)
	local totalCost = 0
	local totalDistance = 0

	for pathIndex = math.max(2, cursor), #path do
		local fromNode = graph.nodes[path[pathIndex - 1]]
		local toNode = graph.nodes[path[pathIndex]]
		if not fromNode or not toNode then continue end

		local edge = BotPlanner.getPathEdge(graph, path, pathIndex)
		totalDistance += (toNode.position - fromNode.position).Magnitude
		totalCost += if edge then edge.cost else (toNode.position - fromNode.position).Magnitude
	end

	return totalCost, totalDistance
end

return BotPlanner
