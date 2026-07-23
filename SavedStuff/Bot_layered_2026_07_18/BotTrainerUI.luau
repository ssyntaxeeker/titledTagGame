--!strict
--[[
    BotTrainerUI (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Docked technical controls and live planner diagnostics for the rebuilt bot.
    UI updates are throttled and use one log label to avoid instance churn.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BotTelemetryDashboard = require(ReplicatedStorage.Modules.Bot.BotTelemetryDashboard)

local BotTrainerUI = {}

local function makeLabel(parent: Instance, text: string, height: number, order: number, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -12, 0, height)
	label.BackgroundColor3 = Color3.fromRGB(27, 30, 35)
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(216, 223, 234)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.TextSize = 11
	label.Font = font
	label.Text = text
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, text: string, order: number, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = text:gsub("%W", "")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, -12, 0, 28)
	button.BackgroundColor3 = Color3.fromRGB(43, 48, 56)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.TextColor3 = Color3.fromRGB(240, 243, 248)
	button.TextSize = 12
	button.Font = Enum.Font.GothamMedium
	button.Text = text
	button.Activated:Connect(callback)
	button.Parent = parent
	return button
end

local function makeSection(parent: Instance, title: string, order: number): TextLabel
	local label = makeLabel(parent, title, 20, order, Enum.Font.GothamBold)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(118, 190, 255)
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextSize = 12
	return label
end

function BotTrainerUI.create(runtime: any): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("BotTrainingWorkbench")
	if old then old:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BotTrainingWorkbench"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Dock"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -10, 0, 8)
	panel.Size = UDim2.new(0, 390, 0.82, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 38)
	header.BackgroundColor3 = Color3.fromRGB(31, 35, 41)
	header.BorderSizePixel = 0
	header.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -44, 1, 0)
	title.Position = UDim2.fromOffset(12, 0)
	title.BackgroundTransparency = 1
	title.Text = "BOT TRAINING WORKBENCH"
	title.TextColor3 = Color3.fromRGB(239, 242, 247)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.Parent = header

	local collapse = Instance.new("TextButton")
	collapse.Size = UDim2.fromOffset(32, 28)
	collapse.Position = UDim2.new(1, -36, 0, 5)
	collapse.BackgroundColor3 = Color3.fromRGB(48, 53, 62)
	collapse.BorderSizePixel = 0
	collapse.Text = "-"
	collapse.TextColor3 = Color3.new(1, 1, 1)
	collapse.TextSize = 18
	collapse.Parent = header

	local content = Instance.new("ScrollingFrame")
	content.Name = "Controls"
	content.Position = UDim2.fromOffset(0, 38)
	content.Size = UDim2.new(1, 0, 1, -38)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.ClipsDescendants = true
	content.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
	local actionFeedback: TextLabel? = nil
	local function actionButton(parent: Instance, text: string, order: number, callback: any): TextButton
		local button: TextButton
		button = makeButton(parent, text, order, function()
			runtime.logUiClick(text)
			local success, handled, detail = pcall(callback)
			if success and handled ~= false then
				local resultDetail = if typeof(detail) == "string" then detail else "request handled"
				runtime.recordUiAction(text, true, resultDetail)
				if actionFeedback then
					actionFeedback.Text = `LAST ACTION: {text}\nOK: {resultDetail}`
					actionFeedback.TextColor3 = Color3.fromRGB(105, 225, 155)
				end
				button.BackgroundColor3 = Color3.fromRGB(35, 98, 68)
			else
				local reason = if success then detail else handled
				local resultDetail = tostring(reason or "operation rejected")
				runtime.recordUiAction(text, false, resultDetail)
				if actionFeedback then
					actionFeedback.Text = `LAST ACTION: {text}\nERROR: {resultDetail}`
					actionFeedback.TextColor3 = Color3.fromRGB(255, 120, 130)
				end
				button.BackgroundColor3 = Color3.fromRGB(132, 49, 58)
			end
			task.delay(0.35, function()
				if button.Parent then button.BackgroundColor3 = Color3.fromRGB(43, 48, 56) end
			end)
		end)
		return button
	end

	local status = makeLabel(content, "Idle", 60, 10, Enum.Font.Code)
	local feedbackLabel = makeLabel(content, "LAST ACTION: none", 42, 11, Enum.Font.Code)
	feedbackLabel.TextColor3 = Color3.fromRGB(155, 166, 182)
	actionFeedback = feedbackLabel
	makeSection(content, "MAP + NAVIGATION", 20)
	actionButton(content, "Build Map Model + Affordances", 21, runtime.buildGraph)
	actionButton(content, "Show / Hide Bot Routes", 22, runtime.toggleVisuals)
	actionButton(content, "Toggle Every Map Node", 23, runtime.toggleAllGraphNodes)
	actionButton(content, "Toggle Every Affordance Edge", 24, runtime.toggleGraphEdges)
	actionButton(content, "Toggle Walk + Passage Navigation (Gray / Teal)", 25, runtime.toggleWalkEdges)
	actionButton(content, "Toggle Jump + Vault + Truss (Yellow / Orange / Red / Lime)", 26, runtime.toggleVerticalEdges)
	actionButton(content, "Toggle Advanced Tech (Bright Colors)", 27, runtime.toggleAdvancedEdges)
	local legend = makeLabel(
		content,
		'<font color="#919191">WALK</font>  <font color="#008CA0">PASSAGE SLIDE</font>  <font color="#FFE100">JUMP</font>  <font color="#FF7800">VAULT</font>  <font color="#E6192D">HIGH</font>  <font color="#78FF28">TRUSS</font>\n<font color="#00BE55">SWING</font>  <font color="#004BDC">DROP</font>  <font color="#F5F5F5">ROLL</font>  <font color="#6928BE">ROLLBOOST</font>  <font color="#FF2396">SLIDEBOOST</font>  <font color="#00E1EB">TRAMP</font>\n<font color="#64AAFF">MAP NODE</font>  <font color="#FF4646">BARRIER NODE</font>',
		54,
		28,
		Enum.Font.Code
	)
	legend.RichText = true
	legend.TextSize = 10

	makeSection(content, "AGENTS", 30)
	actionButton(content, "Spawn / Reset Main Bot", 31, runtime.spawnBot)
	actionButton(content, "Start / Pause Agents  [F9]", 32, runtime.toggleEnabled)
	actionButton(content, "Toggle Main Role", 33, runtime.toggleRole)
	actionButton(content, "Toggle Bot vs Player / Bot vs Bot", 34, runtime.toggleDuelMode)
	local swarmCount = Instance.new("TextBox")
	swarmCount.Name = "ExplorationBotCount"
	swarmCount.LayoutOrder = 35
	swarmCount.Size = UDim2.new(1, -12, 0, 28)
	swarmCount.BackgroundColor3 = Color3.fromRGB(35, 39, 46)
	swarmCount.BorderSizePixel = 0
	swarmCount.ClearTextOnFocus = false
	swarmCount.PlaceholderText = "Exploration bot count (1-24)"
	swarmCount.Text = "8"
	swarmCount.TextColor3 = Color3.fromRGB(240, 243, 248)
	swarmCount.PlaceholderColor3 = Color3.fromRGB(135, 143, 156)
	swarmCount.TextSize = 12
	swarmCount.Font = Enum.Font.Code
	swarmCount.Parent = content
	actionButton(content, "Spawn X Independent Route Explorers", 36, function()
		return runtime.spawnExplorationBots(tonumber(swarmCount.Text) or 8)
	end)
	actionButton(content, "Remove Route Explorers", 37, runtime.clearExplorationBots)

	makeSection(content, "LEARNING", 40)
	actionButton(content, "Toggle Learning + Tech Exploration", 41, runtime.toggleLearningMode)
	actionButton(content, "Start / Finish Teaching Route", 42, runtime.toggleRouteTeaching)
	actionButton(content, "Export Weighted Offline Samples", 43, runtime.exportPolicySamples)
	actionButton(content, "Clear Session Samples", 44, runtime.clearPolicySamples)
	actionButton(content, "Calibrate Runtime Policy + Save", 45, runtime.trainRuntimePolicy)

	makeSection(content, "START / GOAL TEST", 50)
	actionButton(content, "Set Start at Bot", 51, runtime.setStartAtBot)
	actionButton(content, "Set Start at Player", 52, runtime.setStartAtPlayer)
	actionButton(content, "Set Goal at Player", 53, runtime.setGoalAtPlayer)
	actionButton(content, "Start Progressive Time Trial", 54, runtime.startManualRun)
	local focusedTech = Instance.new("TextBox")
	focusedTech.Name = "FocusedTech"
	focusedTech.LayoutOrder = 55
	focusedTech.Size = UDim2.new(1, -12, 0, 28)
	focusedTech.BackgroundColor3 = Color3.fromRGB(35, 39, 46)
	focusedTech.BorderSizePixel = 0
	focusedTech.ClearTextOnFocus = false
	focusedTech.PlaceholderText = "Tech: SlideBoost, Vault, Swing, Roll..."
	focusedTech.Text = "SlideBoost"
	focusedTech.TextColor3 = Color3.fromRGB(240, 243, 248)
	focusedTech.PlaceholderColor3 = Color3.fromRGB(135, 143, 156)
	focusedTech.TextSize = 12
	focusedTech.Font = Enum.Font.Code
	focusedTech.Parent = content
	actionButton(content, "Start Focused Tech Drill", 56, function()
		return runtime.startTechDrill(focusedTech.Text)
	end)
	actionButton(content, "Start RAPID Tech Learning", 57, function()
		return runtime.startRapidTechDrill(focusedTech.Text)
	end)
	actionButton(content, "Stop Focused Tech Drill", 58, runtime.stopTechDrill)
	actionButton(content, "Remove Test Positions", 59, runtime.clearManualPositions)

	makeSection(content, "LIVE DECISION", 60)
	local thoughtPane = Instance.new("ScrollingFrame")
	thoughtPane.Name = "LiveDecision"
	thoughtPane.LayoutOrder = 61
	thoughtPane.Size = UDim2.new(1, -12, 0, 170)
	thoughtPane.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	thoughtPane.BorderSizePixel = 0
	thoughtPane.CanvasSize = UDim2.new()
	thoughtPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	thoughtPane.ScrollingDirection = Enum.ScrollingDirection.Y
	thoughtPane.ScrollBarThickness = 5
	thoughtPane.ScrollingEnabled = true
	thoughtPane.Active = true
	thoughtPane.ClipsDescendants = true
	thoughtPane.Parent = content
	local thought = makeLabel(thoughtPane, "No bot spawned", 0, 1, Enum.Font.Code)
	thought.Size = UDim2.new(1, -12, 0, 0)
	thought.Position = UDim2.fromOffset(4, 4)
	thought.AutomaticSize = Enum.AutomaticSize.Y
	thought.BackgroundTransparency = 1
	makeSection(content, "EVENT LOG", 70)
	local logPane = Instance.new("ScrollingFrame")
	logPane.Name = "EventLog"
	logPane.LayoutOrder = 71
	logPane.Size = UDim2.new(1, -12, 0, 230)
	logPane.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	logPane.BorderSizePixel = 0
	logPane.CanvasSize = UDim2.new()
	logPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logPane.ScrollingDirection = Enum.ScrollingDirection.Y
	logPane.ScrollBarThickness = 5
	logPane.ScrollingEnabled = true
	logPane.Active = true
	logPane.ClipsDescendants = true
	logPane.Parent = content
	local logs = makeLabel(logPane, "", 0, 1, Enum.Font.Code)
	logs.Size = UDim2.new(1, -8, 0, 0)
	logs.Position = UDim2.fromOffset(4, 4)
	logs.AutomaticSize = Enum.AutomaticSize.Y
	logs.BackgroundTransparency = 1
	makeSection(content, "OBJECTIVE TELEMETRY", 80)
	actionButton(content, "Reset Session Telemetry", 81, runtime.resetTelemetry)
	local telemetry = BotTelemetryDashboard.create(content, 82)

	local compact = false
	collapse.Activated:Connect(function()
		runtime.logUiClick("Collapse / Expand Workbench")
		compact = not compact
		content.Visible = not compact
		panel.Size = if compact then UDim2.fromOffset(390, 38) else UDim2.new(0, 390, 0.82, 0)
		collapse.Text = if compact then "+" else "-"
		runtime.recordUiAction("Collapse / Expand Workbench", true, if compact then "collapsed" else "expanded")
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.F8 then
			panel.Visible = not panel.Visible
			runtime.logUiClick("Toggle Workbench [F8]")
			runtime.recordUiAction("Toggle Workbench [F8]", true, if panel.Visible then "visible" else "hidden")
		end
		if input.KeyCode == Enum.KeyCode.F9 then
			runtime.logUiClick("Start / Pause Agents [F9]")
			local success, handled, detail = pcall(runtime.toggleEnabled)
			local handledSuccessfully = success and handled ~= false
			local resultDetail = if handledSuccessfully then detail else if success then detail else handled
			runtime.recordUiAction("Start / Pause Agents [F9]", handledSuccessfully, tostring(resultDetail or "request handled"))
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then return end
		accumulator = 0
		if not panel.Visible then return end
		local camera = Workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			scale.Scale = math.clamp(math.min(1, (viewport.X - 20) / 390, (viewport.Y - 20) / 720), 0.62, 1)
		end
		local nodeCount, pathCount, enabled, role, reward = runtime.getStats()
		status.Text = `{runtime.getStatus()}\n{role} | running {enabled} | nodes {nodeCount} | plan {pathCount} | reward {math.floor(reward * 10) / 10}`
		thought.Text = runtime.getThoughtInfo()
		local logText = table.concat(runtime.getLogs(), "\n")
		if logs.Text ~= logText then
			local wasAtBottom = logPane.CanvasPosition.Y + logPane.AbsoluteWindowSize.Y
				>= logPane.AbsoluteCanvasSize.Y - 12
			logs.Text = logText
			if wasAtBottom then
				task.defer(function()
					if not logPane.Parent then return end
					logPane.CanvasPosition = Vector2.new(0, math.max(0, logPane.AbsoluteCanvasSize.Y - logPane.AbsoluteWindowSize.Y))
				end)
			end
		end
		BotTelemetryDashboard.update(telemetry, runtime.getTelemetryDashboard())
	end)

	return screenGui
end

return table.freeze(BotTrainerUI)
