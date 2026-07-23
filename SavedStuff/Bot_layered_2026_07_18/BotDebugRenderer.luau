--!strict
--[[
    BotDebugRenderer (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Incremental world-space visualization. Requests only enqueue descriptors;
    update() creates and clears a bounded number of Instances per frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type RAffordanceGraph = Types.RAffordanceGraph
type RAffordanceEdge = Types.RAffordanceEdge
type RPlan = Types.RPlan

type Descriptor = {
	kind: "Node" | "Line",
	layer: "Static" | "Dynamic",
	position: Vector3,
	toPosition: Vector3?,
	color: Color3,
	size: number,
	text: string?,
}

export type RRenderer = {
	folder: Folder,
	staticFolder: Folder,
	dynamicFolder: Folder,
	clearQueue: { Instance },
	clearCursor: number,
	clearTail: number,
	generation: number,
	visible: boolean,
	showAllNodes: boolean,
	showEdges: boolean,
	showWalkEdges: boolean,
	showVerticalEdges: boolean,
	showAdvancedEdges: boolean,
	sourceGraph: RAffordanceGraph?,
	sourcePlan: RPlan?,
	secondaryPlan: RPlan?,
	additionalPlans: { RPlan },
	nodeCursor: number,
	swingAnchorCursor: number,
	edgeCursor: number,
	planCursor: number,
	secondaryPlanCursor: number,
	additionalPlanIndex: number,
	additionalPlanCursors: { number },
	staticSignature: string,
	dynamicSignature: string,
}

local BotDebugRenderer = {}

local ACTION_COLORS = table.freeze({
	Walk = Color3.fromRGB(145, 145, 145),
	Jump = Color3.fromRGB(255, 225, 0),
	Vault = Color3.fromRGB(255, 120, 0),
	HighVault = Color3.fromRGB(230, 25, 45),
	TrussClimb = Color3.fromRGB(120, 255, 40),
	Swing = Color3.fromRGB(0, 190, 85),
	Drop = Color3.fromRGB(0, 75, 220),
	Roll = Color3.fromRGB(245, 245, 245),
	RollBoost = Color3.fromRGB(105, 40, 190),
	SlideBoost = Color3.fromRGB(255, 35, 150),
	Trampoline = Color3.fromRGB(0, 225, 235),
})
local PASSAGE_SLIDE_COLOR = Color3.fromRGB(0, 140, 160)
local PLAN_START_COLOR = Color3.fromRGB(70, 255, 120)
local PLAN_GOAL_COLOR = Color3.fromRGB(255, 255, 255)

local function planNodeText(plan: RPlan, index: number, action: string, isGoal: boolean): string?
	local prefix = if isGoal then "GOAL" elseif action ~= "Walk" then action else ""
	local advantage = plan.edgeAdvantages[index]
	local clearance = plan.edgeClearances[index]
	local margin = plan.edgeInterceptionMargins[index]
	if not advantage or not clearance or not margin or clearance == math.huge then
		return if prefix ~= "" then prefix else nil
	end
	local sign = if advantage >= 0 then "+" else ""
	local marginSign = if margin >= 0 then "+" else ""
	local metrics = `A {sign}{math.floor(advantage * 10) / 10}  C {math.floor(clearance * 10) / 10}  M {marginSign}{math.floor(margin * 10) / 10}s`
	return if prefix ~= "" then `{prefix}  {metrics}` else metrics
end

local function edgeColor(edge: RAffordanceEdge): Color3
	if edge.setup.requiresSlide then return PASSAGE_SLIDE_COLOR end
	return ACTION_COLORS[edge.action] or Color3.new(1, 1, 1)
end

function BotDebugRenderer.create(): RRenderer
	local old = Workspace:FindFirstChild("BotDebug")
	if old then
		old.Name = "BotDebugRetired"
		task.spawn(function()
			old:Destroy()
		end)
	end
	local folder = Instance.new("Folder")
	folder.Name = "BotDebug"
	folder.Parent = Workspace
	local staticFolder = Instance.new("Folder")
	staticFolder.Name = "Static"
	staticFolder.Parent = folder
	local dynamicFolder = Instance.new("Folder")
	dynamicFolder.Name = "Dynamic"
	dynamicFolder.Parent = folder
	return {
		folder = folder,
		staticFolder = staticFolder,
		dynamicFolder = dynamicFolder,
		clearQueue = {},
		clearCursor = 1,
		clearTail = 0,
		generation = 0,
		visible = false,
		showAllNodes = false,
		showEdges = false,
		showWalkEdges = false,
		showVerticalEdges = false,
		showAdvancedEdges = false,
		sourceGraph = nil,
		sourcePlan = nil,
		secondaryPlan = nil,
		additionalPlans = {},
		nodeCursor = 1,
		swingAnchorCursor = 1,
		edgeCursor = 1,
		planCursor = 1,
		secondaryPlanCursor = 1,
		additionalPlanIndex = 1,
		additionalPlanCursors = {},
		staticSignature = "",
		dynamicSignature = "",
	}
end

function BotDebugRenderer.request(
	renderer: RRenderer,
	graph: RAffordanceGraph?,
	plan: RPlan?,
	secondaryPlan: RPlan?,
	additionalPlans: { RPlan }?
)
	renderer.generation += 1
	local graphVersion = if graph then graph.buildVersion else 0
	local staticSignature = `{graphVersion}:{renderer.visible}:{renderer.showAllNodes}:{renderer.showEdges}:{renderer.showWalkEdges}:{renderer.showVerticalEdges}:{renderer.showAdvancedEdges}`
	if staticSignature ~= renderer.staticSignature then
		renderer.staticSignature = staticSignature
		for _, child in renderer.staticFolder:GetChildren() do
			renderer.clearTail += 1
			renderer.clearQueue[renderer.clearTail] = child
		end
		renderer.nodeCursor = 1
		renderer.swingAnchorCursor = 1
		renderer.edgeCursor = 1
	end
	local primaryPlanId = if renderer.visible and plan then plan.id else 0
	local secondaryPlanId = if renderer.visible and secondaryPlan then secondaryPlan.id else 0
	local visibleAdditionalPlans: { RPlan } = additionalPlans or {}
	local additionalPlanIds: { string } = {}
	for index, additionalPlan in visibleAdditionalPlans do additionalPlanIds[index] = tostring(additionalPlan.id) end
	local dynamicSignature = `{graphVersion}:{primaryPlanId}:{secondaryPlanId}:{table.concat(additionalPlanIds, ",")}:{renderer.visible}`
	if dynamicSignature ~= renderer.dynamicSignature then
		renderer.dynamicSignature = dynamicSignature
		for _, child in renderer.dynamicFolder:GetChildren() do
			renderer.clearTail += 1
			renderer.clearQueue[renderer.clearTail] = child
		end
		renderer.planCursor = 1
		renderer.secondaryPlanCursor = 1
		renderer.additionalPlanIndex = 1
		table.clear(renderer.additionalPlanCursors)
		for index = 1, #visibleAdditionalPlans do renderer.additionalPlanCursors[index] = 1 end
	end
	renderer.sourceGraph = if renderer.visible then graph else nil
	renderer.sourcePlan = if renderer.visible then plan else nil
	renderer.secondaryPlan = if renderer.visible then secondaryPlan else nil
	renderer.additionalPlans = if renderer.visible then visibleAdditionalPlans else {}
end

local function createDescriptor(renderer: RRenderer, info: Descriptor)
	local parent = if info.layer == "Static" then renderer.staticFolder else renderer.dynamicFolder
	if info.kind == "Node" then
		local part = Instance.new("Part")
		part.Name = "GraphNode"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * info.size
		part.Position = info.position
		part.Color = info.color
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = parent
		if info.text then
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "PlanLabel"
			billboard.Size = UDim2.fromOffset(148, 14)
			billboard.StudsOffsetWorldSpace = Vector3.new(0, info.size * 0.5 + 0.35, 0)
			billboard.AlwaysOnTop = false
			billboard.MaxDistance = 120
			billboard.LightInfluence = 0
			billboard.Parent = part
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.BorderSizePixel = 0
			label.Font = Enum.Font.Code
			label.Text = info.text
			label.TextColor3 = info.color
			label.TextSize = 9
			label.TextStrokeColor3 = Color3.new(0, 0, 0)
			label.TextStrokeTransparency = 0.3
			label.Parent = billboard
		end
		return
	end

	if info.kind == "Line" and info.toPosition then
		local delta = info.toPosition - info.position
		if delta.Magnitude <= 0.01 then return end
		local part = Instance.new("Part")
		part.Name = "GraphEdge"
		part.Size = Vector3.new(info.size, info.size, delta.Magnitude)
		part.CFrame = CFrame.lookAt(info.position:Lerp(info.toPosition, 0.5), info.toPosition)
		part.Color = info.color
		part.Material = Enum.Material.Neon
		part.Transparency = if info.size <= 0.035 then 0.68 elseif info.size <= 0.07 then 0.35 else 0.16
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = parent
	end
end

local function edgeVisible(renderer: RRenderer, action: string): boolean
	if action == "Walk" then return renderer.showWalkEdges end
	if action == "Jump" or action == "Vault" or action == "HighVault" or action == "TrussClimb" then
		return renderer.showVerticalEdges
	end
	return renderer.showAdvancedEdges
end

local function edgeWidth(action: string): number
	if action == "Walk" then return 0.025 end
	if action == "Jump" then return 0.06 end
	if action == "Vault" or action == "HighVault" or action == "TrussClimb" then return 0.085 end
	return 0.11
end

function BotDebugRenderer.update(renderer: RRenderer)
	local startedAt = os.clock()
	local count = 0
	while count < Config.debugMaxInstancesPerStep and os.clock() - startedAt < Config.debugBudgetSeconds do
		local old = renderer.clearQueue[renderer.clearCursor]
		if old then
			old:Destroy()
			renderer.clearQueue[renderer.clearCursor] = nil
			renderer.clearCursor += 1
			count += 1
			continue
		end
		if renderer.clearCursor > renderer.clearTail and renderer.clearTail > 0 then
			table.clear(renderer.clearQueue)
			renderer.clearCursor = 1
			renderer.clearTail = 0
		end
		local graph = renderer.sourceGraph
		local priorityPlan = renderer.sourcePlan
		if graph and priorityPlan and renderer.planCursor <= #priorityPlan.edgeIds then
			local index = renderer.planCursor
			local edge = graph.edges[priorityPlan.edgeIds[index]]
			renderer.planCursor += 1
			local from = graph.mapModel.nodes[edge.from]
			local to = graph.mapModel.nodes[edge.to]
			local color = edgeColor(edge)
			createDescriptor(renderer, {
				kind = "Line",
				layer = "Dynamic",
				position = from.rootPosition,
				toPosition = to.rootPosition,
				color = color,
				size = 0.07,
				text = nil,
			})
			if index == 1 then
				createDescriptor(renderer, {
					kind = "Node",
					layer = "Dynamic",
					position = from.rootPosition,
					toPosition = nil,
					color = PLAN_START_COLOR,
					size = 0.48,
					text = "START",
				})
			end
			local isGoal = index == #priorityPlan.edgeIds
			local nodeText = planNodeText(priorityPlan, index, edge.action, isGoal)
			createDescriptor(renderer, {
				kind = "Node",
				layer = "Dynamic",
				position = to.rootPosition,
				toPosition = nil,
				color = if isGoal then PLAN_GOAL_COLOR else color,
				size = if isGoal then 0.52 else 0.3,
				text = nodeText,
			})
			count += if index == 1 then 3 else 2
			continue
		end
		local secondaryPlan = renderer.secondaryPlan
		if graph and secondaryPlan and renderer.secondaryPlanCursor <= #secondaryPlan.edgeIds then
			local index = renderer.secondaryPlanCursor
			local edge = graph.edges[secondaryPlan.edgeIds[index]]
			renderer.secondaryPlanCursor += 1
			local from = graph.mapModel.nodes[edge.from]
			local to = graph.mapModel.nodes[edge.to]
			local color = edgeColor(edge)
			createDescriptor(renderer, {
				kind = "Line",
				layer = "Dynamic",
				position = from.rootPosition + Vector3.yAxis * 0.22,
				toPosition = to.rootPosition + Vector3.yAxis * 0.22,
				color = color,
				size = 0.09,
				text = nil,
			})
			if index == 1 then
				createDescriptor(renderer, {
					kind = "Node",
					layer = "Dynamic",
					position = from.rootPosition + Vector3.yAxis * 0.22,
					toPosition = nil,
					color = PLAN_START_COLOR,
					size = 0.48,
					text = "START",
				})
			end
			local isGoal = index == #secondaryPlan.edgeIds
			local nodeText = planNodeText(secondaryPlan, index, edge.action, isGoal)
			createDescriptor(renderer, {
				kind = "Node",
				layer = "Dynamic",
				position = to.rootPosition + Vector3.yAxis * 0.22,
				toPosition = nil,
				color = if isGoal then PLAN_GOAL_COLOR else color,
				size = if isGoal then 0.52 else 0.3,
				text = nodeText,
			})
			count += if index == 1 then 3 else 2
			continue
		end
		local additionalPlan = renderer.additionalPlans[renderer.additionalPlanIndex]
		if graph and additionalPlan then
			local planIndex = renderer.additionalPlanIndex
			local cursor = renderer.additionalPlanCursors[planIndex] or 1
			local edgeId = additionalPlan.edgeIds[cursor]
			if not edgeId then
				renderer.additionalPlanIndex += 1
				continue
			end
			renderer.additionalPlanCursors[planIndex] = cursor + 1
			local edge = graph.edges[edgeId]
			local from = graph.mapModel.nodes[edge.from]
			local to = graph.mapModel.nodes[edge.to]
			local heightOffset = Vector3.yAxis * (0.3 + (planIndex % 5) * 0.06)
			createDescriptor(renderer, {
				kind = "Line",
				layer = "Dynamic",
				position = from.rootPosition + heightOffset,
				toPosition = to.rootPosition + heightOffset,
				color = edgeColor(edge),
				size = 0.055,
				text = nil,
			})
			if cursor == 1 then
				createDescriptor(renderer, {
					kind = "Node",
					layer = "Dynamic",
					position = from.rootPosition + heightOffset,
					toPosition = nil,
					color = PLAN_START_COLOR,
					size = 0.32,
					text = nil,
				})
			end
			local isGoal = cursor == #additionalPlan.edgeIds
			createDescriptor(renderer, {
				kind = "Node",
				layer = "Dynamic",
				position = to.rootPosition + heightOffset,
				toPosition = nil,
				color = if isGoal then PLAN_GOAL_COLOR else edgeColor(edge),
				size = if isGoal then 0.36 else 0.22,
				text = nil,
			})
			count += if cursor == 1 then 3 else 2
			continue
		end
		if graph and renderer.showAllNodes and renderer.nodeCursor <= #graph.mapModel.nodes then
			local node = graph.mapModel.nodes[renderer.nodeCursor]
			renderer.nodeCursor += 1
			createDescriptor(renderer, {
				kind = "Node",
				layer = "Static",
				position = node.rootPosition,
				toPosition = nil,
				color = if node.isBarrierAdjacent then Color3.fromRGB(255, 70, 70) elseif node.isTrampoline then ACTION_COLORS.Trampoline else Color3.fromRGB(100, 170, 255),
				size = 0.32,
				text = nil,
			})
			count += 1
			continue
		end
		if graph and renderer.showAllNodes and renderer.swingAnchorCursor <= #graph.mapModel.swingAnchors then
			local anchor = graph.mapModel.swingAnchors[renderer.swingAnchorCursor]
			renderer.swingAnchorCursor += 1
			createDescriptor(renderer, {
				kind = "Node",
				layer = "Static",
				position = anchor.position,
				toPosition = nil,
				color = ACTION_COLORS.Swing,
				size = 0.42,
				text = nil,
			})
			count += 1
			continue
		end
		if graph and renderer.showEdges and renderer.edgeCursor <= #graph.edges then
			local edge = graph.edges[renderer.edgeCursor]
			renderer.edgeCursor += 1
			if not edgeVisible(renderer, edge.action) then continue end
			local from = graph.mapModel.nodes[edge.from]
			local to = graph.mapModel.nodes[edge.to]
			local swingTarget = if edge.action == "Swing" then edge.setup.lookTarget else nil
			if swingTarget then
				createDescriptor(renderer, {
					kind = "Line",
					layer = "Static",
					position = from.rootPosition,
					toPosition = swingTarget,
					color = edgeColor(edge),
					size = edgeWidth(edge.action),
					text = nil,
				})
				createDescriptor(renderer, {
					kind = "Line",
					layer = "Static",
					position = swingTarget,
					toPosition = to.rootPosition,
					color = edgeColor(edge),
					size = edgeWidth(edge.action),
					text = nil,
				})
				count += 2
			else
				createDescriptor(renderer, {
					kind = "Line",
					layer = "Static",
					position = from.rootPosition,
					toPosition = to.rootPosition,
					color = edgeColor(edge),
					size = edgeWidth(edge.action),
					text = nil,
				})
				count += 1
			end
			continue
		end
		return
	end
end

return table.freeze(BotDebugRenderer)
