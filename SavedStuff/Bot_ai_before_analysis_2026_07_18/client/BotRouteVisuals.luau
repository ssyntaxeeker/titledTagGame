--!strict
--[[
    BotRouteVisuals (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Incrementally renders compact, action-colored route paths and labels for
    live bot plans without placing large panels over the world.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BotAgent = require(ReplicatedStorage.Modules.Bot.BotAgent)
local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type Action = Types.Action
type RAgent = BotAgent.RAgent
type REdge = Types.REdge
type RWorld = Types.RWorld

local BotRouteVisuals = {}
local ACTION_COLORS: { [Action]: Color3 } = table.freeze({
	Walk = Color3.fromRGB(245, 245, 245),
	Jump = Color3.fromRGB(0, 225, 255),
	Vault = Color3.fromRGB(35, 235, 80),
	HighVault = Color3.fromRGB(255, 220, 0),
	TrussClimb = Color3.fromRGB(150, 255, 40),
	Swing = Color3.fromRGB(255, 60, 210),
	Drop = Color3.fromRGB(105, 80, 255),
	RollBoost = Color3.fromRGB(255, 135, 20),
	SlideBoost = Color3.fromRGB(255, 40, 40),
	Trampoline = Color3.fromRGB(30, 255, 185),
})

local function marker(folder: Folder, name: string, position: Vector3, color: Color3, size: number): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = folder
	return part
end

local function pathSegment(
	folder: Folder,
	fromPart: BasePart,
	toPart: BasePart,
	color: Color3,
	current: boolean,
	transparency: number?
)
	local fromAttachment = Instance.new("Attachment")
	fromAttachment.Parent = fromPart
	local toAttachment = Instance.new("Attachment")
	toAttachment.Parent = toPart
	local beam = Instance.new("Beam")
	beam.Name = if current then "CurrentTransition" else "PlannedTransition"
	beam.Attachment0 = fromAttachment
	beam.Attachment1 = toAttachment
	beam.Color = ColorSequence.new(color)
	beam.Width0 = if current then 0.28 else 0.14
	beam.Width1 = beam.Width0
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(transparency or 0)
	beam.Parent = folder
end

local function label(parent: BasePart, text: string, color: Color3, offset: Vector3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RouteLabel"
	billboard.Adornee = parent
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 180
	billboard.Size = UDim2.fromOffset(210, 30)
	billboard.StudsOffsetWorldSpace = offset
	billboard.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.Code
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextSize = 12
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	textLabel.TextStrokeTransparency = 0.15
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.Parent = billboard
end

local function actionText(edge: REdge, index: number, current: boolean, phase: string): string
	local confidence = math.floor((1 - edge.risk) * 100 + 0.5)
	local prefix = if current then `NOW {phase}` else `NEXT {index}`
	return `{prefix}: {string.upper(edge.action)} | {string.format("%.2f", edge.time)}s | {confidence}%`
end

local function renderAgent(folder: Folder, world: RWorld, agent: RAgent, agentIndex: number)
	local roleColor = if agent.role == "Tagger" then Color3.fromRGB(255, 65, 65) else Color3.fromRGB(65, 155, 255)
	local start = marker(folder, `Bot{agentIndex}Start`, agent.root.Position, roleColor, 0.9)
	local activeAction = if agent.motion.edge then agent.motion.edge.action else "Direct"
	label(
		start,
		`{string.upper(agent.role)} | {agent.decision} | {activeAction}/{agent.motion.phase}`,
		roleColor,
		Vector3.new(0, 2.2, 0)
	)
	if agent.goal then
		local goal = marker(folder, `Bot{agentIndex}Goal`, agent.goal, roleColor, 1.15)
		label(goal, `{string.upper(agent.role)} GOAL`, roleColor, Vector3.new(0, 1.8, 0))
	end
	local plan = agent.plan
	if not plan then return end
	local previous = start
	local renderedPoints = 1
	local renderedLabels = 0
	for edgeIndex = agent.planCursor, #plan.edges do
		if renderedPoints >= Config.debugMaximumRoutePoints or not folder.Parent then return end
		local edge = world.edges[plan.edges[edgeIndex]]
		if not edge then continue end
		local current = edgeIndex == agent.planCursor
		local color = ACTION_COLORS[edge.action]
		if edge.action ~= "Walk" and (edge.approach - previous.Position).Magnitude > 1.25 then
			local approach = marker(folder, "TechSetup", edge.approach, color, if current then 0.85 else 0.58)
			pathSegment(folder, previous, approach, color, current)
			previous = approach
			renderedPoints += 1
		end
		local destination = marker(folder, edge.action, edge.target, color, if current then 0.9 else 0.62)
		pathSegment(folder, previous, destination, color, current)
		if renderedLabels < Config.debugMaximumRouteLabels then
			label(destination, actionText(edge, edgeIndex, current, agent.motion.phase), color, Vector3.new(0, 1.35, 0))
			renderedLabels += 1
		end
		previous = destination
		renderedPoints += 1
		if renderedPoints % Config.debugInstancesPerFrame == 0 then RunService.Heartbeat:Wait() end
	end
end

function BotRouteVisuals.render(world: RWorld, agents: { RAgent? }): Folder
	local folder = Instance.new("Folder")
	folder.Name = "BotDebug"
	folder.Parent = workspace
	task.spawn(function()
		for agentIndex, agent in agents do
			if not folder.Parent then return end
			if agent then renderAgent(folder, world, agent, agentIndex) end
			RunService.Heartbeat:Wait()
		end
	end)
	return folder
end

function BotRouteVisuals.renderAlternatives(
	world: RWorld,
	start: BasePart,
	goal: BasePart,
	plans: { Types.RPlan },
	selectedIndex: number
): Folder
	local folder = Instance.new("Folder")
	folder.Name = "BotRouteLabDebug"
	folder.Parent = workspace
	task.spawn(function()
		local routeColors = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(30, 210, 255),
			Color3.fromRGB(255, 75, 210),
			Color3.fromRGB(255, 180, 25),
		}
		for routeIndex, plan in plans do
			if not folder.Parent then return end
			local selected = routeIndex == selectedIndex
			local previous = marker(folder, `Route{routeIndex}Start`, start.Position, routeColors[routeIndex], if selected then 0.8 else 0.35)
			for edgeIndex, edgeId in plan.edges do
				local edge = world.edges[edgeId]
				if not edge then continue end
				local color = if selected then ACTION_COLORS[edge.action] else routeColors[routeIndex]
				local destination = marker(
					folder,
					`Route{routeIndex}{edge.action}`,
					edge.target + Vector3.yAxis * ((routeIndex - 1) * 0.12),
					color,
					if selected then 0.72 else 0.32
				)
				pathSegment(folder, previous, destination, color, selected, if selected then 0 else 0.48)
				if selected and edgeIndex <= Config.debugMaximumRouteLabels then
					label(destination, actionText(edge, edgeIndex, edgeIndex == 1, "ROUTE"), color, Vector3.new(0, 1.25, 0))
				end
				previous = destination
				if edgeIndex % 20 == 0 then RunService.Heartbeat:Wait() end
			end
		end
		if not folder.Parent then return end
		local selectedPlan = plans[selectedIndex]
		if selectedPlan then
			local summary = marker(folder, "SelectedRouteGoal", goal.Position, Color3.fromRGB(255, 255, 255), 0.9)
			label(
				summary,
				`ROUTE {selectedIndex}/{#plans} | {string.format("%.2f", selectedPlan.time)}s | {math.floor(selectedPlan.success * 100)}%`,
				Color3.fromRGB(255, 255, 255),
				Vector3.new(0, 2.4, 0)
			)
		end
	end)
	return folder
end

return table.freeze(BotRouteVisuals)
