--!strict
--[[
    BotTrainerUI (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Docked editor UI for the local bot trainer. BotTrainer owns training,
    route data, and persistence; this module builds controls, panels,
    and timeline buttons that call BotTrainer callbacks.
]]

type UIContext = {
	state: any,
	localPlayer: Player,
	chaseStartDelaySeconds: number,
	pushLog: (string) -> (),
	refreshControlButtons: () -> (),
	spawnBot: () -> (),
	spawnRunnerBot: () -> (),
	buildGraph: () -> (),
	printGraph: () -> (),
	clearLearning: () -> (),
	saveLearningVersion: (any, boolean) -> boolean,
	getSelectedRoleName: () -> any,
	getSelectedEnabled: () -> boolean,
	setSelectedEnabled: (boolean) -> (),
	getSelectedSpeedMultiplier: () -> number,
	setSelectedSpeedMultiplier: (number) -> (),
	getRoleVersions: (any) -> { any },
	getSelectedVersion: (any) -> any?,
	applyLearningVersion: (any, any) -> (),
	getCurrentRoute: () -> any?,
	setEditorOpen: (boolean) -> (),
	beginRouteRecording: () -> (),
	beginPlayerRouteRecording: () -> (),
	startGuidedTraining: () -> (),
	teachTechHint: (string?) -> (),
	teachClimbableWall: () -> (),
	stopRouteRecording: () -> (),
	addRoutePoint: (string) -> (),
	addRoutePointFromView: (string) -> (),
	selectRoutePointIndex: (number) -> (),
	moveSelectedRoutePointOrder: (number) -> (),
	selectRouteIndex: (number) -> (),
	setSelectedRoutePointAction: (string) -> (),
	nudgeSelectedRoutePoint: (Vector3) -> (),
	setSelectedRoutePointStuds: (number, boolean?) -> (),
	setCurrentRouteName: (string) -> (),
	setCurrentRouteMaxTime: (number) -> (),
	setCurrentRouteCaps: (number, number, number) -> (),
	deleteSelectedRoutePoint: () -> (),
	deleteSelectedRoute: () -> (),
	startSelectedRoute: () -> (),
	selectVersionRemote: RemoteFunction,
	favoriteVersionRemote: RemoteFunction,
	deleteVersionRemote: RemoteFunction,
}

type BotTrainerUI = {
	_context: UIContext,
	_gui: ScreenGui,
	_root: Frame,
	_modalButton: TextButton,
	_guidedArrowLabel: TextLabel,
	_statusLabel: TextLabel,
	_graphLabel: TextLabel,
	_versionLabel: TextLabel,
	_routeLabel: TextLabel,
	_memoryLabel: TextLabel,
	_memoryGraphFrame: Frame,
	_logLabel: TextLabel,
	_editorHelpLabel: TextLabel,
	_propertiesLabel: TextLabel,
	_actionTextBox: TextBox,
	_studsTextBox: TextBox,
	_routeNameTextBox: TextBox,
	_routeTimeTextBox: TextBox,
	_routeVaultsTextBox: TextBox,
	_routeSwingsTextBox: TextBox,
	_routeRollsTextBox: TextBox,
	_taggerRoleTextBox: TextBox,
	_runnerRoleTextBox: TextBox,
	_progressWeightTextBox: TextBox,
	_exploreWeightTextBox: TextBox,
	_runnerDistanceWeightTextBox: TextBox,
	_orbitWeightTextBox: TextBox,
	_verticalRollWeightTextBox: TextBox,
	_routeOptionWeightTextBox: TextBox,
	_backtrackWeightTextBox: TextBox,
	_localVaultWeightTextBox: TextBox,
	_routeListFrame: ScrollingFrame,
	_timelineFrame: Frame,
	_topBar: Frame,
	_leftPanel: Frame,
	_centerPanel: Frame,
	_rightPanel: Frame,
	_watchPanel: Frame,
	_watchStatusLabel: TextLabel,
	_watchCoachLabel: TextLabel,
	_watchLogLabel: TextLabel,
	_trainButton: TextButton,
	_watchTrainButton: TextButton,
	_useGraphButton: TextButton,
	_vaultButton: TextButton,
	_debugButton: TextButton,
	_visualizeButton: TextButton,
	_graphVisualizeButton: TextButton,
	_watchDebugButton: TextButton,
	_watchVisualizeButton: TextButton,
	_watchGraphVisualizeButton: TextButton,
	_watchCoachButton: TextButton,
	_selectedAIButton: TextButton,
	_selectedEnabledButton: TextButton,
	_selectedSpeedButton: TextButton,
	_targetModeButton: TextButton,
	_speedButton: TextButton,
	_versionButton: TextButton,
	_favoriteVersionButton: TextButton,
	_routeRecordButton: TextButton,
	_guidedTrainingButton: TextButton,
	_routeRunButton: TextButton,
	_editorButton: TextButton,
	_compactButton: TextButton,
	_watchCompactButton: TextButton,
	_routesTabButton: TextButton,
	_memoryTabButton: TextButton,
	_routeListSignature: string,
	_timelineSignature: string,
	setLog: (BotTrainerUI, string) -> (),
	setStatus: (BotTrainerUI, string) -> (),
	refreshControlButtons: (BotTrainerUI) -> (),
	updateGui: (BotTrainerUI, BasePart?) -> (),
}

local BotTrainerUI: any = {}

local PANEL = Color3.fromRGB(30, 33, 40)
local PANEL_DARK = Color3.fromRGB(20, 22, 27)
local STROKE = Color3.fromRGB(72, 78, 92)
local TEXT = Color3.fromRGB(232, 237, 247)
local COACH_STEPS = table.freeze({
	"1. Build Graph, then stand where a tech is possible.",
	"2. Press C to pick the tech type. Current action is shown below.",
	"3. Press T to teach this exact spot as a local tech hint.",
	"4. Press B to mark this wall as slide-boost climbable.",
	"5. Press N to add a route node from your camera view when you need a real route.",
	"6. Press R to record/stop your movement. Use Q/E or [/] to move through these tips.",
})

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function stroke(parent: Instance)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = STROKE
	uiStroke.Thickness = 1
	uiStroke.Parent = parent
end

local function pad(parent: Instance, value: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, value)
	padding.PaddingBottom = UDim.new(0, value)
	padding.PaddingLeft = UDim.new(0, value)
	padding.PaddingRight = UDim.new(0, value)
	padding.Parent = parent
end

local function list(parent: Instance, padding: number)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.Parent = parent
end

local function makePanel(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = PANEL
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 6)
	stroke(frame)
	return frame
end

local function makePanelContent(panel: Frame): ScrollingFrame
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 5
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.Parent = panel
	pad(content, 8)
	list(content, 6)
	return content
end

local function makeScrollingPanel(parent: Instance, name: string, size: UDim2): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Size = size
	frame.BackgroundColor3 = PANEL
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.ScrollBarThickness = 5
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = parent
	corner(frame, 6)
	stroke(frame)
	return frame
end

local function makeButton(parent: Instance, text: string, order: number, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = text:gsub("%W+", "")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 30)
	button.BackgroundColor3 = Color3.fromRGB(48, 53, 64)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.Text = text
	button.TextColor3 = TEXT
	button.TextSize = 12
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Parent = parent
	corner(button, 5)
	button.Activated:Connect(callback)
	return button
end

local function makeSmallButton(parent: Instance, text: string, order: number, callback: () -> ()): TextButton
	local button = makeButton(parent, text, order, callback)
	button.Size = UDim2.new(0, 112, 1, -8)
	return button
end

local function makeLabel(parent: Instance, text: string, order: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = TEXT
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function makeTextBox(parent: Instance, labelText: string, order: number, defaultText: string, callback: (string) -> ()): TextBox
	local frame = Instance.new("Frame")
	frame.Name = labelText:gsub("%W+", "")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 46)
	frame.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 5)
	stroke(frame)
	pad(frame, 5)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 14)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(175, 186, 204)
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.Position = UDim2.new(0, 0, 0, 17)
	box.Size = UDim2.new(1, 0, 0, 20)
	box.BackgroundTransparency = 1
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Code
	box.PlaceholderText = defaultText
	box.Text = defaultText
	box.TextColor3 = TEXT
	box.TextSize = 13
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = frame
	box.FocusLost:Connect(function()
		callback(box.Text)
	end)

	return box
end

local function setButtonState(button: TextButton, active: boolean, text: string)
	button.Text = text
	button.BackgroundColor3 = if active then Color3.fromRGB(48, 118, 90) else Color3.fromRGB(48, 53, 64)
end

local function countDictionary(dictionary: any): number
	if typeof(dictionary) ~= "table" then return 0 end

	local count = 0
	for _ in dictionary do
		count += 1
	end
	return count
end

local function bestScoreText(dictionary: any): string
	if typeof(dictionary) ~= "table" then return "--" end

	local bestKey = nil
	local bestScore = -math.huge
	for key, info in dictionary do
		if typeof(info) ~= "table" then continue end
		local score = tonumber(info.score) or 0
		if score > bestScore then
			bestScore = score
			bestKey = key
		end
	end

	return if bestKey then `{bestKey}: {math.floor(bestScore * 10) / 10}` else "--"
end

local function addGraphPoint(parent: Frame, x: number, y: number, color: Color3, labelText: string?)
	local point = Instance.new("Frame")
	point.Name = "Point"
	point.AnchorPoint = Vector2.new(0.5, 0.5)
	point.Position = UDim2.fromScale(x, y)
	point.Size = UDim2.fromOffset(7, 7)
	point.BackgroundColor3 = color
	point.BorderSizePixel = 0
	point.Parent = parent
	corner(point, 4)

	if labelText then
		local label = Instance.new("TextLabel")
		label.Name = "PointLabel"
		label.Position = UDim2.new(0, 5, 0, -13)
		label.Size = UDim2.fromOffset(80, 16)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.Text = labelText
		label.TextColor3 = Color3.fromRGB(185, 195, 210)
		label.TextSize = 9
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = point
	end
end

local function addGraphLine(parent: Frame, fromX: number, fromY: number, toX: number, toY: number, color: Color3)
	local deltaX = toX - fromX
	local deltaY = toY - fromY
	local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.fromScale(fromX, fromY)
	line.Size = UDim2.new(length, 0, 0, 2)
	line.BackgroundColor3 = color
	line.BorderSizePixel = 0
	line.Rotation = math.deg(math.atan2(deltaY, deltaX))
	line.Parent = parent
end

local function collectGraphValues(dictionary: any, limit: number): { { key: string, score: number, visits: number } }
	local values = {}
	if typeof(dictionary) ~= "table" then return values end

	for key, info in dictionary do
		if typeof(info) ~= "table" then continue end
		table.insert(values, {
			key = tostring(key),
			score = tonumber(info.score) or 0,
			visits = tonumber(info.visits) or 0,
		})
	end
	table.sort(values, function(a, b)
		return math.abs(a.score) + a.visits * 0.05 > math.abs(b.score) + b.visits * 0.05
	end)
	while #values > limit do
		table.remove(values)
	end
	return values
end

local function drawMemoryGraph(parent: Frame, title: string, dictionary: any, order: number, color: Color3)
	local graph = Instance.new("Frame")
	graph.Name = title:gsub("%W+", "")
	graph.LayoutOrder = order
	graph.Size = UDim2.new(1, 0, 0, 92)
	graph.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
	graph.BorderSizePixel = 0
	graph.ClipsDescendants = true
	graph.Parent = parent
	corner(graph, 5)
	stroke(graph)

	local titleLabel = makeLabel(graph, title, 0, 18)
	titleLabel.Position = UDim2.fromOffset(8, 5)
	titleLabel.Size = UDim2.new(1, -16, 0, 16)
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.TextColor3 = Color3.fromRGB(215, 224, 238)

	local values = collectGraphValues(dictionary, 12)
	if #values == 0 then
		addGraphPoint(graph, 0.08, 0.68, Color3.fromRGB(80, 87, 102), "empty")
		return
	end

	local maxMagnitude = 1
	for _, info in values do
		maxMagnitude = math.max(maxMagnitude, math.abs(info.score), info.visits * 0.2)
	end

	local previousX: number? = nil
	local previousY: number? = nil
	for index, info in values do
		local x = if #values == 1 then 0.5 else 0.08 + ((index - 1) / (#values - 1)) * 0.84
		local normalized = math.clamp(info.score / maxMagnitude, -1, 1)
		local y = math.clamp(0.56 - normalized * 0.34, 0.22, 0.88)
		if previousX and previousY then addGraphLine(graph, previousX, previousY, x, y, color) end
		addGraphPoint(graph, x, y, color, `{info.key}:{math.floor(info.score * 10) / 10}`)
		previousX = x
		previousY = y
	end
end

local function getRouteListSignature(state: any): string
	local parts = {
		`selected={state.editorSelectedRouteIndex}`,
		`count={#state.routes}`,
	}

	for index, routeInfo in state.routes do
		table.insert(parts, `{index}:{routeInfo.id}:{routeInfo.name}:{#routeInfo.points}:{routeInfo.successes or 0}:{routeInfo.failures or 0}`)
	end

	return table.concat(parts, "|")
end

local function getTimelineSignature(state: any, route: any?): string
	if not route then return `none:{state.editorSelectedPointIndex}` end

	local parts = {
		`route={route.id}`,
		`selected={state.editorSelectedPointIndex}`,
		`points={#route.points}`,
	}

	for index, point in route.points do
		table.insert(
			parts,
			`{index}:{point.action}:{math.floor(point.position.X * 10)}:{math.floor(point.position.Y * 10)}:{math.floor(point.position.Z * 10)}`
		)
	end

	return table.concat(parts, "|")
end

function BotTrainerUI:setLog(text: string)
	self._logLabel.Text = text
	self._watchLogLabel.Text = text
end

function BotTrainerUI:setStatus(text: string)
	self._statusLabel.Text = text
	self._watchStatusLabel.Text = text
end

function BotTrainerUI:refreshControlButtons()
	local context = self._context
	local state = context.state

	local compact = state.editorCompact == true
	local fullEditorOpen = state.editorOpen == true and not compact
	self._modalButton.Visible = fullEditorOpen
	self._modalButton.Modal = fullEditorOpen
	self._topBar.Visible = not compact
	self._leftPanel.Visible = not compact
	self._centerPanel.Visible = not compact
	self._rightPanel.Visible = not compact
	self._timelineFrame.Visible = not compact
	self._watchPanel.Visible = compact

	setButtonState(self._editorButton, state.editorOpen, if state.editorOpen then "Editor: ON" else "Editor: OFF")
	setButtonState(self._compactButton, compact, if compact then "Watch: ON" else "Watch Mode")
	setButtonState(self._useGraphButton, state.useGraph, if state.useGraph then "Graph Nav: ON" else "Graph Nav: OFF")
	setButtonState(self._vaultButton, state.autoVault, if state.autoVault then "Parkour: ON" else "Parkour: OFF")
	setButtonState(self._debugButton, state.debug, if state.debug then "Debug: ON" else "Debug: OFF")
	setButtonState(self._watchDebugButton, state.debug, if state.debug then "Logs: ON" else "Logs: OFF")
	setButtonState(self._visualizeButton, state.visualizeDebug, if state.visualizeDebug then "Visual: ON" else "Visual: OFF")
	setButtonState(self._graphVisualizeButton, state.visualizeGraphDebug, if state.visualizeGraphDebug then "Graph Visual: ON" else "Graph Visual")
	setButtonState(self._watchVisualizeButton, state.visualizeDebug, if state.visualizeDebug then "Visual: ON" else "Visual: OFF")
	setButtonState(
		self._watchGraphVisualizeButton,
		state.visualizeGraphDebug,
		if state.visualizeGraphDebug then "Graph Visual: ON" else "Graph Visual"
	)
	setButtonState(self._watchCoachButton, state.teachCoachEnabled, if state.teachCoachEnabled then "Coach: ON" else "Coach: OFF")
	setButtonState(
		self._routeRecordButton,
		state.recordingRoute,
		if state.playerRouteRecording then "Stop Player Rec" elseif state.recordingRoute then "Stop Recording" else "Record Route"
	)
	setButtonState(
		self._guidedTrainingButton,
		state.guidedTraining,
		if state.guidedTraining then `Guided: ON ({state.guidedCompletions})` else "Guided Beginner"
	)
	setButtonState(self._routeRunButton, state.activeRoute ~= nil, if state.activeRoute then "Stop Route" else "Run Route")
	setButtonState(self._routesTabButton, state.editorTab ~= "Memory", "Routes")
	setButtonState(self._memoryTabButton, state.editorTab == "Memory", "Memory")
	setButtonState(
		self._selectedEnabledButton,
		context.getSelectedEnabled(),
		`{state.selectedAI}: {if context.getSelectedEnabled() then "ON" else "OFF"}`
	)

	self._selectedAIButton.Text = `AI: {state.selectedAI}`
	self._selectedSpeedButton.Text = `AI Speed: {context.getSelectedSpeedMultiplier()}x`
	self._targetModeButton.Text = `Target: {if state.targetMode == "Player" then "Player" else "Other AI"}`
	self._speedButton.Text = `Train Speed: {state.trainingSpeedMultiplier}x`
	self._trainButton.Text = if state.training then "Stop Training" else "Start Training"
	self._trainButton.BackgroundColor3 = if state.training then Color3.fromRGB(48, 118, 90) else Color3.fromRGB(48, 53, 64)
	self._watchTrainButton.Text = if state.training then "Stop Training" else "Start Training"
	self._watchTrainButton.BackgroundColor3 = self._trainButton.BackgroundColor3

	local role = context.getSelectedRoleName()
	local version = context.getSelectedVersion(role)
	self._versionButton.Text = if version then `Version {state.selectedVersionIndexes[role]}/{#context.getRoleVersions(role)}` else "Version: none"
	self._favoriteVersionButton.Text = if version and version.favorite then "Favorite: ON" else "Favorite: OFF"
end

function BotTrainerUI:updateGui(targetRoot: BasePart?)
	local context = self._context
	local state = context.state
	local route = context.getCurrentRoute()
	local camera = workspace.CurrentCamera

	if state.guidedTraining and state.guidedDestination and camera then
		local viewport = camera.ViewportSize
		local screenPoint, onScreen = camera:WorldToViewportPoint(state.guidedDestination)
		local center = viewport * 0.5
		local screenPosition = Vector2.new(screenPoint.X, screenPoint.Y)
		local direction = screenPosition - center
		if screenPoint.Z < 0 then direction = -direction end
		if direction.Magnitude < 1 then direction = Vector2.new(0, -1) end

		local clampedPosition = if onScreen and screenPoint.Z > 0
			then screenPosition
			else center + direction.Unit * math.min(center.X - 70, center.Y - 54)
		clampedPosition = Vector2.new(
			math.clamp(clampedPosition.X, 62, viewport.X - 62),
			math.clamp(clampedPosition.Y, 62, viewport.Y - 62)
		)

		local rootScale = self._root:FindFirstChildOfClass("UIScale")
		local scale = if rootScale then rootScale.Scale else 1
		self._guidedArrowLabel.Position = UDim2.fromOffset(clampedPosition.X / scale, clampedPosition.Y / scale)
		self._guidedArrowLabel.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
		self._guidedArrowLabel.Text = if onScreen and screenPoint.Z > 0 then "◆" else "▲"
		self._guidedArrowLabel.Visible = true
	else
		self._guidedArrowLabel.Visible = false
	end

	self._graphLabel.Text = `Graph {#state.graph} nodes | Step {state.graphStep} | Cap {state.nodeCap} | Graph target {if state.graphMoveTarget
		then "active"
		else "direct"}`

	local routeText = "No active route"
	if route then
		routeText =
			`Route {route.name}\nNodes {#route.points} | Selected {state.editorSelectedPointIndex} | Action {state.editorSelectedAction}\nMax {route.maxTime}s | V/S/R {route.maxVaults}/{route.maxSwings}/{route.maxRolls} | Best {if route.bestTime
				then math.floor(route.bestTime * 10) / 10
				else "--"} | S/F {route.successes or 0}/{route.failures or 0}`
	end
	self._routeLabel.Text = routeText

	self._memoryLabel.Visible = state.editorTab == "Memory"
	self._memoryGraphFrame.Visible = state.editorTab == "Memory"
	if self._memoryLabel.Visible then
		local graphTargetText = "--"
		if state.graphMoveTarget then
			graphTargetText = `{math.floor(state.graphMoveTarget.X)}, {math.floor(state.graphMoveTarget.Y)}, {math.floor(state.graphMoveTarget.Z)}`
		end

		self._memoryLabel.Text = table.concat({
			`Graph nodes: {#state.graph}`,
			`Direction buckets: {countDictionary(state.directionScores)} | best {bestScoreText(state.directionScores)}`,
			`Tech scores: {countDictionary(state.techScores)} | best {bestScoreText(state.techScores)}`,
			`Route tech notes: {countDictionary(state.routeTechNotes)} | best {bestScoreText(state.routeTechNotes)}`,
			`Geometry notes: {countDictionary(state.geometryScores)} | best {bestScoreText(state.geometryScores)}`,
			`Self route candidates: {countDictionary(state.selfTaughtRouteCandidates)}`,
			`Cutoff buckets: {countDictionary(state.cutoffScores)} | best {bestScoreText(state.cutoffScores)}`,
			`Policy weights: {countDictionary(state.policyWeights)} | player models {countDictionary(state.playerModelScores)}`,
			`Slide timings: {countDictionary(state.slideBoostScores)} | best {bestScoreText(state.slideBoostScores)}`,
			`Graph target: {graphTargetText}`,
		}, "\n")

		for _, child in self._memoryGraphFrame:GetChildren() do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		drawMemoryGraph(self._memoryGraphFrame, "Direction score memory", state.directionScores, 1, Color3.fromRGB(100, 180, 255))
		drawMemoryGraph(self._memoryGraphFrame, "Tech score memory", state.techScores, 2, Color3.fromRGB(120, 255, 155))
		drawMemoryGraph(self._memoryGraphFrame, "Runner escape memory", state.runnerDirectionScores, 3, Color3.fromRGB(255, 190, 105))
	end

	local pointText = "No node selected"
	if route and route.points[state.editorSelectedPointIndex] then
		local point = route.points[state.editorSelectedPointIndex]
		pointText =
			`Node {state.editorSelectedPointIndex}\nAction: {point.action}\nPos: {math.floor(point.position.X)}, {math.floor(point.position.Y)}, {math.floor(
				point.position.Z
			)}\nPart: {point.partName or "--"}\nStuds: {point.studs or "--"}`

		if not self._actionTextBox:IsFocused() then self._actionTextBox.Text = point.action end
		if not self._studsTextBox:IsFocused() then self._studsTextBox.Text = tostring(point.studs or 0) end
	end
	self._propertiesLabel.Text = pointText

	local coachStep = math.clamp(state.teachCoachStep or 1, 1, #COACH_STEPS)
	self._watchCoachLabel.Visible = state.teachCoachEnabled == true
	self._watchCoachLabel.Text = table.concat({
		"Teach Coach",
		COACH_STEPS[coachStep],
		`Action: {state.editorSelectedAction}`,
		"Keys: C action | T teach | B wall | N node | R record | Q/E tips",
	}, "\n")

	if route then
		if not self._routeNameTextBox:IsFocused() then self._routeNameTextBox.Text = tostring(route.name) end
		if not self._routeTimeTextBox:IsFocused() then self._routeTimeTextBox.Text = tostring(route.maxTime) end
		if not self._routeVaultsTextBox:IsFocused() then self._routeVaultsTextBox.Text = tostring(route.maxVaults) end
		if not self._routeSwingsTextBox:IsFocused() then self._routeSwingsTextBox.Text = tostring(route.maxSwings) end
		if not self._routeRollsTextBox:IsFocused() then self._routeRollsTextBox.Text = tostring(route.maxRolls) end
	end
	if not self._taggerRoleTextBox:IsFocused() then self._taggerRoleTextBox.Text = tostring(state.taggerBotRoleName) end
	if not self._runnerRoleTextBox:IsFocused() then self._runnerRoleTextBox.Text = tostring(state.runnerBotRoleName) end
	if not self._progressWeightTextBox:IsFocused() then self._progressWeightTextBox.Text = tostring(state.learnParams.progressWeight) end
	if not self._exploreWeightTextBox:IsFocused() then self._exploreWeightTextBox.Text = tostring(state.learnParams.exploreWeight) end
	if not self._runnerDistanceWeightTextBox:IsFocused() then
		self._runnerDistanceWeightTextBox.Text = tostring(state.learnParams.runnerDistanceWeight)
	end
	if not self._orbitWeightTextBox:IsFocused() then self._orbitWeightTextBox.Text = tostring(state.learnParams.orbitWeight) end
	if not self._verticalRollWeightTextBox:IsFocused() then self._verticalRollWeightTextBox.Text = tostring(state.learnParams.verticalRollWeight) end
	if not self._routeOptionWeightTextBox:IsFocused() then self._routeOptionWeightTextBox.Text = tostring(state.learnParams.routeOptionWeight) end
	if not self._backtrackWeightTextBox:IsFocused() then self._backtrackWeightTextBox.Text = tostring(state.learnParams.backtrackWeight) end
	if not self._localVaultWeightTextBox:IsFocused() then self._localVaultWeightTextBox.Text = tostring(state.learnParams.localVaultWeight) end

	local lines = {}
	for _, roleName in { "tagger", "runner" } do
		local versions = context.getRoleVersions(roleName)
		table.insert(lines, `{roleName}: {#versions}`)
		for index = 1, math.min(5, #versions) do
			local version = versions[index]
			if typeof(version) ~= "table" then continue end

			local summary = if typeof(version.summary) == "table" then version.summary else {}
			local marker = if version.favorite then "*" else "-"
			local active = if state.currentVersionIds[roleName] == version.id then " active" else ""
			table.insert(
				lines,
				`{marker} {index}. {version.name or version.id}{active} | routes {summary.routes or 0}, tech {summary.techNotes or 0}, cuts {summary.cutoffs or 0}`
			)
		end
	end
	self._versionLabel.Text = table.concat(lines, "\n")

	local routeListSignature = getRouteListSignature(state)
	if routeListSignature ~= self._routeListSignature then
		self._routeListSignature = routeListSignature
		for _, child in self._routeListFrame:GetChildren() do
			if child:IsA("GuiButton") then child:Destroy() end
		end
		for index, routeInfo in state.routes do
			local routeButton = makeButton(
				self._routeListFrame,
				`{index}. {routeInfo.name} | {#routeInfo.points} nodes | S/F {routeInfo.successes or 0}/{routeInfo.failures or 0}`,
				index,
				function()
					context.selectRouteIndex(index)
				end
			)
			routeButton.ZIndex = self._routeListFrame.ZIndex + 2
			routeButton.Active = true
			routeButton.BackgroundColor3 = if index == state.editorSelectedRouteIndex
				then Color3.fromRGB(78, 126, 176)
				else Color3.fromRGB(48, 53, 64)
		end
	end

	local timelineSignature = getTimelineSignature(state, route)
	if timelineSignature ~= self._timelineSignature then
		self._timelineSignature = timelineSignature
		for _, child in self._timelineFrame:GetChildren() do
			if child:IsA("GuiButton") then child:Destroy() end
		end
		if route then
			for index, point in route.points do
				local nodeButton = Instance.new("TextButton")
				nodeButton.Name = `Node{index}`
				nodeButton.LayoutOrder = index
				nodeButton.Size = UDim2.new(0, 86, 1, -10)
				nodeButton.BackgroundColor3 = if index == state.editorSelectedPointIndex
					then Color3.fromRGB(78, 126, 176)
					else Color3.fromRGB(48, 53, 64)
				nodeButton.BorderSizePixel = 0
				nodeButton.Font = Enum.Font.GothamMedium
				nodeButton.Text = `{index}\n{point.action}`
				nodeButton.TextColor3 = TEXT
				nodeButton.TextSize = 11
				nodeButton.ZIndex = self._timelineFrame.ZIndex + 2
				nodeButton.Active = true
				nodeButton.Parent = self._timelineFrame
				corner(nodeButton, 5)
				nodeButton.Activated:Connect(function()
					context.selectRoutePointIndex(index)
				end)
			end
		end
	end

	if not state.training then
		local rootPart = state.rootPart
		local distance = if rootPart and targetRoot then math.floor((targetRoot.Position - rootPart.Position).Magnitude * 10) / 10 else "--"
		local statusText = `Training OFF | Target {state.targetMode} | Distance {distance} | Success {state.successes}/{state.attempts}`
		self._statusLabel.Text = statusText
		self._watchStatusLabel.Text = statusText
	end
end

function BotTrainerUI.create(context: UIContext): BotTrainerUI
	local gui = Instance.new("ScreenGui")
	gui.Name = "BotTrainerGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = context.localPlayer:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui

	local modalButton = Instance.new("TextButton")
	modalButton.Name = "EditorModal"
	modalButton.Size = UDim2.fromScale(1, 1)
	modalButton.BackgroundTransparency = 1
	modalButton.BorderSizePixel = 0
	modalButton.Text = ""
	modalButton.AutoButtonColor = false
	modalButton.Active = true
	modalButton.Modal = false
	modalButton.Visible = false
	modalButton.ZIndex = 0
	modalButton.Parent = root

	local guidedArrowLabel = Instance.new("TextLabel")
	guidedArrowLabel.Name = "GuidedArrow"
	guidedArrowLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	guidedArrowLabel.Size = UDim2.fromOffset(110, 44)
	guidedArrowLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	guidedArrowLabel.BackgroundTransparency = 0.18
	guidedArrowLabel.BorderSizePixel = 0
	guidedArrowLabel.Font = Enum.Font.GothamBold
	guidedArrowLabel.TextColor3 = Color3.fromRGB(255, 232, 120)
	guidedArrowLabel.TextStrokeTransparency = 0.5
	guidedArrowLabel.TextSize = 22
	guidedArrowLabel.Visible = false
	guidedArrowLabel.ZIndex = 50
	guidedArrowLabel.Parent = root
	corner(guidedArrowLabel, 8)

	local rootScale = Instance.new("UIScale")
	rootScale.Parent = root

	local function updateRootScale()
		local camera = workspace.CurrentCamera
		if not camera then return end

		local viewport = camera.ViewportSize
		rootScale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.72, 1)
	end

	updateRootScale()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateRootScale) end

	local topBar = makePanel(root, "TopBar", UDim2.new(0, 10, 0, 10), UDim2.new(1, -20, 0, 44))
	topBar.BackgroundColor3 = PANEL_DARK
	pad(topBar, 4)
	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.Padding = UDim.new(0, 6)
	topLayout.Parent = topBar

	local leftPanel = makePanel(root, "Tools", UDim2.new(0, 10, 0, 64), UDim2.new(0, 280, 1, -154))
	local centerPanel = makePanel(root, "ViewportOverlay", UDim2.new(0, 300, 0, 64), UDim2.new(0, 420, 0, 430))
	local rightPanel = makePanel(root, "Properties", UDim2.new(1, -310, 0, 64), UDim2.new(0, 300, 1, -154))
	local timeline = makePanel(root, "Timeline", UDim2.new(0, 10, 1, -80), UDim2.new(1, -20, 0, 70))
	local watchPanel = makePanel(root, "WatchPanel", UDim2.new(1, -330, 0, 64), UDim2.new(0, 320, 0, 360))

	pad(timeline, 6)
	local leftContent = makePanelContent(leftPanel)
	local centerContent = makePanelContent(centerPanel)
	local rightContent = makePanelContent(rightPanel)
	local watchContent = makePanelContent(watchPanel)

	local timelineLayout = Instance.new("UIListLayout")
	timelineLayout.FillDirection = Enum.FillDirection.Horizontal
	timelineLayout.SortOrder = Enum.SortOrder.LayoutOrder
	timelineLayout.Padding = UDim.new(0, 6)
	timelineLayout.Parent = timeline

	local self = setmetatable({
		_context = context,
		_gui = gui,
		_root = root,
		_modalButton = modalButton,
		_guidedArrowLabel = guidedArrowLabel,
		_statusLabel = makeLabel(centerContent, "Training: OFF", 1, 36),
		_graphLabel = makeLabel(centerContent, "Graph: --", 2, 34),
		_routeLabel = makeLabel(centerContent, "Route: none", 3, 72),
		_editorHelpLabel = makeLabel(
			centerContent,
			"Grab route balls to move them, or use Record My Movement to capture your jumps, vaults, swings, rolls, and end point as a taught route.",
			4,
			48
		),
		_memoryLabel = makeLabel(centerContent, "", 9, 220),
		_propertiesLabel = makeLabel(rightContent, "No point selected", 1, 104),
		_versionLabel = makeLabel(rightContent, "Versions: loading...", 2, 132),
		_logLabel = makeLabel(rightContent, "", 3, 140),
		_routeListFrame = makeScrollingPanel(rightContent, "RouteList", UDim2.new(1, 0, 0, 190)),
		_timelineFrame = timeline,
		_topBar = topBar,
		_leftPanel = leftPanel,
		_centerPanel = centerPanel,
		_rightPanel = rightPanel,
		_watchPanel = watchPanel,
		_watchStatusLabel = makeLabel(watchContent, "Training: OFF", 1, 42),
		_watchCoachLabel = makeLabel(watchContent, "", 8, 96),
		_watchLogLabel = makeLabel(watchContent, "", 9, 190),
		_routeListSignature = "",
		_timelineSignature = "",
	}, { __index = BotTrainerUI }) :: any

	watchPanel.Visible = false
	self._editorHelpLabel.TextColor3 = Color3.fromRGB(190, 200, 214)
	self._memoryLabel.Visible = false
	self._routeListFrame.LayoutOrder = 22
	self._routeListFrame.BackgroundColor3 = Color3.fromRGB(24, 27, 33)
	pad(self._routeListFrame, 6)
	list(self._routeListFrame, 5)

	self._logLabel.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
	self._logLabel.BackgroundTransparency = 0
	self._logLabel.TextColor3 = Color3.fromRGB(190, 200, 214)
	self._logLabel.TextSize = 11
	corner(self._logLabel, 5)
	pad(self._logLabel, 6)

	self._watchLogLabel.BackgroundColor3 = Color3.fromRGB(18, 20, 25)
	self._watchLogLabel.BackgroundTransparency = 0
	self._watchLogLabel.TextColor3 = Color3.fromRGB(190, 200, 214)
	self._watchLogLabel.TextSize = 11
	corner(self._watchLogLabel, 5)
	pad(self._watchLogLabel, 6)

	self._watchCoachLabel.BackgroundColor3 = Color3.fromRGB(22, 30, 42)
	self._watchCoachLabel.BackgroundTransparency = 0
	self._watchCoachLabel.TextColor3 = Color3.fromRGB(226, 238, 255)
	self._watchCoachLabel.TextSize = 11
	self._watchCoachLabel.Visible = false
	corner(self._watchCoachLabel, 5)
	pad(self._watchCoachLabel, 6)

	local memoryGraphFrame = Instance.new("Frame")
	memoryGraphFrame.Name = "MemoryGraphs"
	memoryGraphFrame.LayoutOrder = 10
	memoryGraphFrame.Size = UDim2.new(1, 0, 0, 318)
	memoryGraphFrame.BackgroundTransparency = 1
	memoryGraphFrame.Visible = false
	memoryGraphFrame.Parent = centerContent
	list(memoryGraphFrame, 8)
	self._memoryGraphFrame = memoryGraphFrame

	self._routeNameTextBox = makeTextBox(centerContent, "Route name", 5, "Route", function(text)
		context.setCurrentRouteName(text)
	end)
	self._routeTimeTextBox = makeTextBox(centerContent, "Route max time", 6, "20", function(text)
		local value = tonumber(text)
		if value then context.setCurrentRouteMaxTime(value) end
	end)
	self._routeVaultsTextBox = makeTextBox(centerContent, "Max vaults", 7, "99", function(text)
		local route = context.getCurrentRoute()
		if not route then return end
		context.setCurrentRouteCaps(tonumber(text) or route.maxVaults, route.maxSwings, route.maxRolls)
	end)
	self._routeSwingsTextBox = makeTextBox(centerContent, "Max swings", 8, "99", function(text)
		local route = context.getCurrentRoute()
		if not route then return end
		context.setCurrentRouteCaps(route.maxVaults, tonumber(text) or route.maxSwings, route.maxRolls)
	end)
	self._routeRollsTextBox = makeTextBox(centerContent, "Max rolls", 9, "99", function(text)
		local route = context.getCurrentRoute()
		if not route then return end
		context.setCurrentRouteCaps(route.maxVaults, route.maxSwings, tonumber(text) or route.maxRolls)
	end)
	self._actionTextBox = makeTextBox(rightContent, "Selected node action", 4, "Move", function(text)
		local action = text:gsub("^%s+", ""):gsub("%s+$", "")
		if action == "" then return end
		context.state.editorSelectedAction = action
		context.setSelectedRoutePointAction(action)
	end)
	self._studsTextBox = makeTextBox(rightContent, "Vault studs", 5, "0", function(text)
		local value = tonumber(text)
		if value then context.setSelectedRoutePointStuds(value, true) end
	end)
	makeButton(rightContent, "Teach Tech Here", 6, function()
		context.teachTechHint(context.state.editorSelectedAction)
	end)
	makeButton(rightContent, "Teach SlideBoost Wall", 7, function()
		context.teachClimbableWall()
	end)
	makeButton(rightContent, "Node Order: Earlier", 8, function()
		context.moveSelectedRoutePointOrder(-1)
	end)
	makeButton(rightContent, "Node Order: Later", 9, function()
		context.moveSelectedRoutePointOrder(1)
	end)
	makeButton(rightContent, "Move Node +X", 10, function()
		context.nudgeSelectedRoutePoint(Vector3.new(1, 0, 0))
	end)
	makeButton(rightContent, "Move Node -X", 11, function()
		context.nudgeSelectedRoutePoint(Vector3.new(-1, 0, 0))
	end)
	makeButton(rightContent, "Move Node +Y", 12, function()
		context.nudgeSelectedRoutePoint(Vector3.new(0, 1, 0))
	end)
	makeButton(rightContent, "Move Node -Y", 13, function()
		context.nudgeSelectedRoutePoint(Vector3.new(0, -1, 0))
	end)
	makeButton(rightContent, "Move Node +Z", 14, function()
		context.nudgeSelectedRoutePoint(Vector3.new(0, 0, 1))
	end)
	makeButton(rightContent, "Move Node -Z", 15, function()
		context.nudgeSelectedRoutePoint(Vector3.new(0, 0, -1))
	end)
	makeButton(rightContent, "Delete Node", 16, context.deleteSelectedRoutePoint)
	makeButton(rightContent, "Delete Route", 17, context.deleteSelectedRoute)

	local function toggleTraining()
		local state = context.state
		state.training = not state.training
		if state.training and not state.bot then context.spawnBot() end
		if state.training and state.runnerEnabled and not state.runnerBot then context.spawnRunnerBot() end
		if state.training then
			state.chaseStartTime = os.clock() + context.chaseStartDelaySeconds
			state.lastDistance = nil
			state.lastChaseProgressDistance = nil
			state.lastRewardTime = 0
			state.lastChaseProgressCheckTime = 0
			state.lastChaseReplanTime = 0
			state.reactionTargetPosition = nil
			state.reactionTargetVelocity = Vector3.zero
			state.lastReactionSampleTime = 0
			state.lastCutoffKey = nil
		end
		context.refreshControlButtons()
		context.pushLog(if state.training then "Training started." else "Training stopped.")
	end

	self._trainButton = makeSmallButton(topBar, "Start Training", 1, toggleTraining)

	self._editorButton = makeSmallButton(topBar, "Editor: OFF", 2, function()
		context.setEditorOpen(not context.state.editorOpen)
		context.refreshControlButtons()
	end)

	self._compactButton = makeSmallButton(topBar, "Watch Mode", 3, function()
		context.state.editorCompact = not context.state.editorCompact
		context.refreshControlButtons()
	end)

	self._routesTabButton = makeSmallButton(topBar, "Routes", 4, function()
		context.state.editorTab = "Routes"
		context.refreshControlButtons()
	end)

	self._memoryTabButton = makeSmallButton(topBar, "Memory", 5, function()
		context.state.editorTab = "Memory"
		context.refreshControlButtons()
	end)

	makeSmallButton(topBar, "Spawn Bots", 6, function()
		context.spawnBot()
		if context.state.runnerEnabled then context.spawnRunnerBot() end
	end)

	self._selectedAIButton = makeSmallButton(topBar, "AI: Tagger", 7, function()
		local state = context.state
		state.selectedAI = if state.selectedAI == "Tagger" then "Runner" else "Tagger"
		context.refreshControlButtons()
	end)

	self._targetModeButton = makeSmallButton(topBar, "Target: Player", 8, function()
		local state = context.state
		state.targetMode = if state.targetMode == "Player" then "AI" else "Player"
		if state.targetMode == "AI" and not state.runnerBot then
			state.runnerEnabled = true
			context.spawnRunnerBot()
		end
		context.refreshControlButtons()
	end)

	self._watchCompactButton = makeButton(watchContent, "Full Editor", 2, function()
		context.state.editorCompact = false
		context.refreshControlButtons()
	end)
	self._watchTrainButton = makeButton(watchContent, "Start Training", 3, toggleTraining)
	self._watchDebugButton = makeButton(watchContent, "Logs: OFF", 4, function()
		context.state.debug = not context.state.debug
		context.refreshControlButtons()
	end)
	self._watchVisualizeButton = makeButton(watchContent, "Visual: OFF", 5, function()
		context.state.visualizeDebug = not context.state.visualizeDebug
		context.refreshControlButtons()
	end)
	self._watchGraphVisualizeButton = makeButton(watchContent, "Graph Visual", 6, function()
		context.state.visualizeGraphDebug = not context.state.visualizeGraphDebug
		context.refreshControlButtons()
	end)
	self._watchCoachButton = makeButton(watchContent, "Coach: OFF", 7, function()
		context.state.teachCoachEnabled = not context.state.teachCoachEnabled
		context.state.editorOpen = true
		context.state.editorCompact = true
		context.refreshControlButtons()
	end)
	makeButton(watchContent, "Spawn Bots", 10, function()
		context.spawnBot()
		if context.state.runnerEnabled then context.spawnRunnerBot() end
	end)

	self._selectedEnabledButton = makeButton(leftContent, "Tagger: ON", 1, function()
		context.setSelectedEnabled(not context.getSelectedEnabled())
		context.refreshControlButtons()
	end)

	self._selectedSpeedButton = makeButton(leftContent, "AI Speed: 1x", 2, function()
		local speedMultiplier = context.getSelectedSpeedMultiplier()
		if speedMultiplier == 1 then
			speedMultiplier = 1.5
		elseif speedMultiplier == 1.5 then
			speedMultiplier = 2
		elseif speedMultiplier == 2 then
			speedMultiplier = 3
		else
			speedMultiplier = 1
		end
		context.setSelectedSpeedMultiplier(speedMultiplier)
		context.refreshControlButtons()
	end)

	self._taggerRoleTextBox = makeTextBox(leftContent, "Bot 1 start role", 3, "Tagger", function(text)
		local roleName = text:gsub("^%s+", ""):gsub("%s+$", "")
		if roleName == "" then return end
		context.state.taggerBotRoleName = roleName
		context.pushLog(`Bot 1 will spawn as {roleName}.`)
	end)

	self._runnerRoleTextBox = makeTextBox(leftContent, "Bot 2 start role", 4, "Runner", function(text)
		local roleName = text:gsub("^%s+", ""):gsub("%s+$", "")
		if roleName == "" then return end
		context.state.runnerBotRoleName = roleName
		context.pushLog(`Bot 2 will spawn as {roleName}.`)
	end)

	self._speedButton = makeButton(leftContent, "Train Speed: 1x", 5, function()
		local state = context.state
		if state.trainingSpeedMultiplier == 1 then
			state.trainingSpeedMultiplier = 1.5
		elseif state.trainingSpeedMultiplier == 1.5 then
			state.trainingSpeedMultiplier = 2
		elseif state.trainingSpeedMultiplier == 2 then
			state.trainingSpeedMultiplier = 3
		else
			state.trainingSpeedMultiplier = 1
		end
		context.refreshControlButtons()
	end)

	self._useGraphButton = makeButton(leftContent, "Graph Nav: ON", 6, function()
		context.state.useGraph = not context.state.useGraph
		context.refreshControlButtons()
	end)

	self._vaultButton = makeButton(leftContent, "Parkour: ON", 7, function()
		context.state.autoVault = not context.state.autoVault
		context.refreshControlButtons()
	end)

	self._debugButton = makeButton(leftContent, "Debug: OFF", 8, function()
		context.state.debug = not context.state.debug
		context.refreshControlButtons()
	end)
	self._visualizeButton = makeButton(leftContent, "Visual: OFF", 9, function()
		context.state.visualizeDebug = not context.state.visualizeDebug
		context.refreshControlButtons()
	end)

	makeButton(leftContent, "Build Graph", 10, function()
		task.spawn(context.buildGraph)
	end)
	self._graphVisualizeButton = makeButton(leftContent, "Graph Visual", 11, function()
		context.state.visualizeGraphDebug = not context.state.visualizeGraphDebug
		context.refreshControlButtons()
	end)
	makeButton(leftContent, "Graph Step 4 / 6 / 8", 12, function()
		local state = context.state
		if state.graphStep == 4 then
			state.graphStep = 6
			state.nodeCap = 10000
		elseif state.graphStep == 6 then
			state.graphStep = 8
			state.nodeCap = 6000
		else
			state.graphStep = 4
			state.nodeCap = 13000
		end
		context.pushLog(`Graph sampling set to {state.graphStep} studs, cap {state.nodeCap}.`)
	end)
	makeButton(leftContent, "Print Graph", 13, context.printGraph)
	makeButton(leftContent, "Clear Learning", 14, context.clearLearning)

	local function setLearnParam(key: string, text: string)
		local value = tonumber(text)
		if not value then return end
		context.state.learnParams[key] = math.clamp(value, 0, 4)
		context.pushLog(`Learn param {key} = {context.state.learnParams[key]}.`)
	end

	self._progressWeightTextBox = makeTextBox(leftContent, "Learn: close/gain dist", 15, "1", function(text)
		setLearnParam("progressWeight", text)
	end)
	self._exploreWeightTextBox = makeTextBox(leftContent, "Learn: explore routes", 16, "1", function(text)
		setLearnParam("exploreWeight", text)
	end)
	self._runnerDistanceWeightTextBox = makeTextBox(leftContent, "Learn: runner distance", 17, "1", function(text)
		setLearnParam("runnerDistanceWeight", text)
	end)
	self._orbitWeightTextBox = makeTextBox(leftContent, "Learn: orbit map", 18, "1", function(text)
		setLearnParam("orbitWeight", text)
	end)
	self._verticalRollWeightTextBox = makeTextBox(leftContent, "Learn: climb/roll setup", 19, "1", function(text)
		setLearnParam("verticalRollWeight", text)
	end)
	self._routeOptionWeightTextBox = makeTextBox(leftContent, "Learn: route exits", 20, "1", function(text)
		setLearnParam("routeOptionWeight", text)
	end)
	self._backtrackWeightTextBox = makeTextBox(leftContent, "Learn: backtrack", 21, "1", function(text)
		setLearnParam("backtrackWeight", text)
	end)
	self._localVaultWeightTextBox = makeTextBox(leftContent, "Learn: local vaults", 22, "1", function(text)
		setLearnParam("localVaultWeight", text)
	end)
	makeButton(leftContent, "Reset Learn Params", 23, function()
		context.state.learnParams.progressWeight = 1
		context.state.learnParams.exploreWeight = 1
		context.state.learnParams.runnerDistanceWeight = 1
		context.state.learnParams.orbitWeight = 1
		context.state.learnParams.verticalRollWeight = 1
		context.state.learnParams.routeOptionWeight = 1
		context.state.learnParams.backtrackWeight = 1
		context.state.learnParams.localVaultWeight = 1
		context.refreshControlButtons()
	end)

	self._routeRecordButton = makeButton(leftContent, "Record Route", 24, function()
		if context.state.recordingRoute then
			context.stopRouteRecording()
		else
			context.beginRouteRecording()
		end
		context.refreshControlButtons()
	end)
	self._guidedTrainingButton = makeButton(leftContent, "Guided Beginner", 25, function()
		context.startGuidedTraining()
		context.refreshControlButtons()
	end)
	makeButton(leftContent, "Record My Movement", 26, function()
		if context.state.recordingRoute then
			context.stopRouteRecording()
		else
			context.beginPlayerRouteRecording()
		end
		context.refreshControlButtons()
	end)
	makeButton(leftContent, "Add Node From View", 27, function()
		context.addRoutePointFromView(context.state.editorSelectedAction)
	end)
	makeButton(leftContent, "Start / Move / End", 28, function()
		local action = context.state.editorSelectedAction
		if action == "Move" then
			action = "End"
		elseif action == "End" then
			action = "Start"
		else
			action = "Move"
		end
		context.state.editorSelectedAction = action
		context.setSelectedRoutePointAction(action)
	end)
	makeButton(leftContent, "Tech Node", 29, function()
		local action = context.state.editorSelectedAction
		if action == "Vault" then
			action = "Swing"
		elseif action == "Swing" then
			action = "Roll"
		elseif action == "Roll" then
			action = "Slide"
		elseif action == "Slide" then
			action = "SlideCancel"
		else
			action = "Vault"
		end
		context.state.editorSelectedAction = action
		context.setSelectedRoutePointAction(action)
	end)
	self._routeRunButton = makeButton(leftContent, "Run Route", 30, function()
		if context.state.activeRoute then
			context.state.activeRoute = nil
			context.state.activeRoutePractice = false
			context.state.activeRouteCursor = 1
			context.state.activeTechAttempt = nil
			context.pushLog("Route run stopped.")
		else
			context.startSelectedRoute()
		end
		context.refreshControlButtons()
	end)

	self._versionButton = makeButton(rightContent, "Version: none", 18, function()
		local role = context.getSelectedRoleName()
		local versions = context.getRoleVersions(role)
		if #versions == 0 then return end
		context.state.selectedVersionIndexes[role] += 1
		if context.state.selectedVersionIndexes[role] > #versions then context.state.selectedVersionIndexes[role] = 1 end
		context.refreshControlButtons()
	end)
	makeButton(rightContent, "Load Version", 19, function()
		local role = context.getSelectedRoleName()
		local version = context.getSelectedVersion(role)
		if not version then return end
		local success, result = pcall(function()
			return context.selectVersionRemote:InvokeServer(role, version.id)
		end)
		if success and typeof(result) == "table" then context.state.trainingData = result end
		context.applyLearningVersion(role, version)
	end)
	makeButton(rightContent, "Save Version", 20, function()
		context.saveLearningVersion(context.getSelectedRoleName(), false)
		context.refreshControlButtons()
	end)
	makeButton(rightContent, "New Version", 21, function()
		context.saveLearningVersion(context.getSelectedRoleName(), true)
		context.refreshControlButtons()
	end)
	self._favoriteVersionButton = makeButton(rightContent, "Favorite: OFF", 22, function()
		local role = context.getSelectedRoleName()
		local version = context.getSelectedVersion(role)
		if not version then return end
		local success, result = pcall(function()
			return context.favoriteVersionRemote:InvokeServer(role, version.id, not version.favorite)
		end)
		if success and typeof(result) == "table" then context.state.trainingData = result end
	end)
	makeButton(rightContent, "Delete Version", 23, function()
		local role = context.getSelectedRoleName()
		local version = context.getSelectedVersion(role)
		if not version then return end
		local success, result = pcall(function()
			return context.deleteVersionRemote:InvokeServer(role, version.id)
		end)
		if success and typeof(result) == "table" then
			context.state.trainingData = result
			context.state.selectedVersionIndexes[role] = 1
		end
	end)

	self:refreshControlButtons()
	return self
end

return BotTrainerUI
