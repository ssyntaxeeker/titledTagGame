--!strict
--[[
    BotPathfinder (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Lightweight graph path search for training bots. Uses a binary min-heap
    and cheap movement costs so route planning does not stall the render loop.
]]

export type GraphNode = {
	id: number,
	position: Vector3,
	links: { number },
	linkTechs: { [number]: string },
	score: number,
	barrierPenalty: number,
	deadEndPenalty: number,
	wallPenalty: number,
	openDirections: number,
}

export type FindParams = {
	graph: { GraphNode },
	startId: number,
	goalIds: { number },
	desiredDirection: Vector3,
	maxExpansions: number,
	yieldEvery: number?,
}

local BotPathfinder = {}

local function heapPush(heap: { { id: number, score: number } }, id: number, score: number)
	local index = #heap + 1
	heap[index] = { id = id, score = score }

	while index > 1 do
		local parentIndex = math.floor(index / 2)
		if heap[parentIndex].score <= score then break end

		heap[index] = heap[parentIndex]
		index = parentIndex
	end

	heap[index] = { id = id, score = score }
end

local function heapPop(heap: { { id: number, score: number } }): number?
	local count = #heap
	if count == 0 then return nil end

	local root = heap[1]
	local last = heap[count]
	heap[count] = nil
	count -= 1

	local index = 1
	while true do
		local leftIndex = index * 2
		if leftIndex > count then break end

		local rightIndex = leftIndex + 1
		local childIndex = if rightIndex <= count and heap[rightIndex].score < heap[leftIndex].score then rightIndex else leftIndex
		if last.score <= heap[childIndex].score then break end

		heap[index] = heap[childIndex]
		index = childIndex
	end

	if count > 0 then heap[index] = last end
	return root.id
end

local function estimateCost(fromNode: GraphNode, toNode: GraphNode, desiredDirection: Vector3): number
	local delta = toNode.position - fromNode.position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	local verticalDelta = delta.Y
	local directionAlignment = if desiredDirection.Magnitude > 0.05 and flatDelta.Magnitude > 0.05
		then flatDelta.Unit:Dot(desiredDirection.Unit)
		else 0

	local cost = delta.Magnitude / 32
	if verticalDelta > 2.5 then
		cost += verticalDelta / 13
	elseif verticalDelta < -7 and directionAlignment > 0.35 then
		cost -= math.clamp(math.abs(verticalDelta) / 42, 0.08, 0.42)
	end

	cost += if directionAlignment >= 0 then -directionAlignment * 0.12 else math.abs(directionAlignment) * 0.2

	local linkTech = fromNode.linkTechs[toNode.id]
	if linkTech == "Vault" then
		cost -= 0.16
	elseif linkTech == "Swing" then
		cost -= 0.24
	elseif linkTech == "Drop" then
		cost += if directionAlignment > 0.25 then 0.05 else 0.38
	elseif linkTech == "HighVault" then
		cost += 0.16
	end

	cost += toNode.barrierPenalty * 1.8
	cost += toNode.deadEndPenalty * 2.2
	cost += toNode.wallPenalty * 2.1
	if toNode.openDirections <= 2 then cost += 0.6 end
	cost -= math.clamp(toNode.score, -4, 10) * 0.03
	return math.max(0.05, cost)
end

function BotPathfinder.findRoutePath(params: FindParams): { number }
	local graph = params.graph
	local startNode = graph[params.startId]
	if not startNode or #params.goalIds == 0 then return {} end

	local goalLookup: { [number]: boolean } = {}
	local goalPositions = {}
	for _, goalId in params.goalIds do
		local goalNode = graph[goalId]
		if not goalNode then continue end
		goalLookup[goalId] = true
		table.insert(goalPositions, goalNode.position)
	end
	if #goalPositions == 0 then return {} end

	local function heuristic(node: GraphNode): number
		local bestDistance = math.huge
		for _, goalPosition in goalPositions do
			bestDistance = math.min(bestDistance, (node.position - goalPosition).Magnitude)
		end
		return bestDistance / 36
	end

	local open = {}
	local cameFrom: { [number]: number } = {}
	local costSoFar: { [number]: number } = {
		[params.startId] = 0,
	}
	local closed: { [number]: boolean } = {}

	heapPush(open, params.startId, heuristic(startNode))

	local expansions = 0
	while #open > 0 do
		expansions += 1
		if expansions > params.maxExpansions then break end
		if params.yieldEvery and expansions % params.yieldEvery == 0 then task.wait() end

		local currentId = heapPop(open)
		if not currentId then break end
		if closed[currentId] then continue end
		closed[currentId] = true

		if goalLookup[currentId] then
			local path = { currentId }
			local previousId = currentId
			while cameFrom[previousId] do
				previousId = cameFrom[previousId]
				table.insert(path, 1, previousId)
			end
			return path
		end

		local currentNode = graph[currentId]
		if not currentNode then continue end

		for _, linkId in currentNode.links do
			local linkNode = graph[linkId]
			if not linkNode then continue end

			local newCost = (costSoFar[currentId] or 0) + estimateCost(currentNode, linkNode, params.desiredDirection)
			if costSoFar[linkId] and newCost >= costSoFar[linkId] then continue end

			costSoFar[linkId] = newCost
			cameFrom[linkId] = currentId
			heapPush(open, linkId, newCost + heuristic(linkNode))
		end
	end

	return {}
end

return table.freeze(BotPathfinder)
