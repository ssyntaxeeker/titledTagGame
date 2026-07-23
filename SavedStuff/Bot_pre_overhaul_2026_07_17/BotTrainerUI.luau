--!strict
--[[
    BotTrainerUI (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Minimal docked controls for the fresh lightweight bot runtime.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BotTrainerUI = {}

local function makeButton(text: string, order: number, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = text:gsub("%s+", "")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, -12, 0, 30)
	button.BackgroundColor3 = Color3.fromRGB(42, 45, 51)
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.fromRGB(235, 238, 244)
	button.TextSize = 13
	button.Font = Enum.Font.GothamMedium
	button.Text = text
	button.Parent = parent
	return button
end

function BotTrainerUI.create(runtime: any)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LightweightBotTrainer"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Dock"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, -40)
	panel.Size = UDim2.new(0, 380, 0, 680)
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 30)
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local panelScale = Instance.new("UIScale")
	panelScale.Scale = 1
	panelScale.Parent = panel

	local function updatePanelScale()
		local camera = Workspace.CurrentCamera
		if not camera then return end

		local viewportSize = camera.ViewportSize
		local availableWidth = math.max(220, viewportSize.X - 24)
		local availableHeight = math.max(320, viewportSize.Y - 72)
		local scale = math.min(1, availableWidth / 380, availableHeight / 680)
		panelScale.Scale = math.clamp(scale, 0.55, 1)
		panel.Position = UDim2.new(1, -12, 0, -40)
	end

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, -12, 0, 24)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 15
	title.Font = Enum.Font.GothamBold
	title.Text = "Lightweight Bot"
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.LayoutOrder = 10
	status.Size = UDim2.new(1, -12, 0, 72)
	status.BackgroundColor3 = Color3.fromRGB(32, 35, 40)
	status.BorderSizePixel = 0
	status.TextColor3 = Color3.fromRGB(202, 208, 218)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
	status.TextSize = 12
	status.Font = Enum.Font.Code
	status.Text = "Idle"
	status.Parent = panel

	local buildGraph = makeButton("Build Graph", 20, panel)
	local spawnBot = makeButton("Spawn Bot", 30, panel)
	local toggleTraining = makeButton("Start / Pause", 40, panel)
	local toggleRole = makeButton("Toggle Role", 50, panel)
	local toggleLearning = makeButton("Toggle Learning Mode", 60, panel)
	local toggleCopyPlayer = makeButton("Toggle Copy Player", 70, panel)
	local toggleRecorder = makeButton("Toggle Policy Recorder", 80, panel)
	local exportSamples = makeButton("Export Policy Samples", 90, panel)
	local clearSamples = makeButton("Clear Policy Samples", 100, panel)
	local toggleDuel = makeButton("Toggle Two Bots", 110, panel)
	local toggleVisuals = makeButton("Toggle Visuals", 120, panel)
	local toggleGraphNodes = makeButton("Toggle Graph Nodes", 130, panel)
	local toggleAllGraphNodes = makeButton("Toggle All Nodes", 140, panel)
	local toggleGraphEdges = makeButton("Toggle Graph Edges", 150, panel)
	local setStartBot = makeButton("Set Start: Bot", 160, panel)
	local setStartPlayer = makeButton("Set Start: Player", 170, panel)
	local setGoalPlayer = makeButton("Set Goal: Player", 180, panel)
	local startManual = makeButton("Start Goal Run", 190, panel)
	local clearManual = makeButton("Remove Positions", 200, panel)

	local thought = Instance.new("TextLabel")
	thought.Name = "Thought"
	thought.LayoutOrder = 210
	thought.Size = UDim2.new(1, -12, 0, 118)
	thought.BackgroundColor3 = Color3.fromRGB(20, 24, 29)
	thought.BorderSizePixel = 0
	thought.TextColor3 = Color3.fromRGB(220, 226, 236)
	thought.TextXAlignment = Enum.TextXAlignment.Left
	thought.TextYAlignment = Enum.TextYAlignment.Top
	thought.TextWrapped = true
	thought.TextSize = 11
	thought.Font = Enum.Font.Code
	thought.Text = "Thought: idle"
	thought.Parent = panel

	local logFrame = Instance.new("ScrollingFrame")
	logFrame.Name = "Logs"
	logFrame.LayoutOrder = 220
	logFrame.Size = UDim2.new(1, -12, 0, 170)
	logFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 21)
	logFrame.BorderSizePixel = 0
	logFrame.CanvasSize = UDim2.new()
	logFrame.ScrollBarThickness = 6
	logFrame.ClipsDescendants = true
	logFrame.Parent = panel

	local logPadding = Instance.new("UIPadding")
	logPadding.PaddingTop = UDim.new(0, 6)
	logPadding.PaddingBottom = UDim.new(0, 6)
	logPadding.PaddingLeft = UDim.new(0, 6)
	logPadding.PaddingRight = UDim.new(0, 6)
	logPadding.Parent = logFrame

	local logLayout = Instance.new("UIListLayout")
	logLayout.SortOrder = Enum.SortOrder.LayoutOrder
	logLayout.Padding = UDim.new(0, 3)
	logLayout.Parent = logFrame

	buildGraph.Activated:Connect(function()
		runtime.buildGraph()
	end)

	spawnBot.Activated:Connect(function()
		runtime.spawnBot()
	end)

	toggleTraining.Activated:Connect(function()
		runtime.toggleEnabled()
	end)

	toggleRole.Activated:Connect(function()
		runtime.toggleRole()
	end)

	toggleLearning.Activated:Connect(function()
		runtime.toggleLearningMode()
	end)

	toggleCopyPlayer.Activated:Connect(function()
		runtime.toggleCopyPlayerMode()
	end)

	toggleRecorder.Activated:Connect(function()
		runtime.togglePolicyRecorder()
	end)

	exportSamples.Activated:Connect(function()
		runtime.exportPolicySamples()
	end)

	clearSamples.Activated:Connect(function()
		runtime.clearPolicySamples()
	end)

	toggleDuel.Activated:Connect(function()
		runtime.toggleDuelMode()
	end)

	toggleVisuals.Activated:Connect(function()
		runtime.toggleVisuals()
	end)

	toggleGraphNodes.Activated:Connect(function()
		runtime.toggleGraphNodes()
	end)

	toggleAllGraphNodes.Activated:Connect(function()
		runtime.toggleAllGraphNodes()
	end)

	toggleGraphEdges.Activated:Connect(function()
		runtime.toggleGraphEdges()
	end)

	setStartBot.Activated:Connect(function()
		runtime.setStartAtBot()
	end)

	setStartPlayer.Activated:Connect(function()
		runtime.setStartAtPlayer()
	end)

	setGoalPlayer.Activated:Connect(function()
		runtime.setGoalAtPlayer()
	end)

	startManual.Activated:Connect(function()
		runtime.startManualRun()
	end)

	clearManual.Activated:Connect(function()
		runtime.clearManualPositions()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.F8 then panel.Visible = not panel.Visible end
		if input.KeyCode == Enum.KeyCode.F9 then runtime.toggleEnabled() end
	end)

	local lastLogCount = 0

	RunService.RenderStepped:Connect(function()
		updatePanelScale()

		local nodes, pathNodes, enabled, role, rewardTotal = runtime.getStats()
		status.Text =
			`{runtime.getStatus()}\nRole: {role} | Running: {enabled}\nNodes: {nodes} | Path nodes: {pathNodes} | Reward: {math.floor(rewardTotal * 10) / 10}`
		thought.Text = runtime.getThoughtInfo()

		local logs = runtime.getLogs()
		if #logs == lastLogCount then return end
		lastLogCount = #logs
		for _, child in logFrame:GetChildren() do
			if child:IsA("TextLabel") then child:Destroy() end
		end

		for logIndex, line in logs do
			local label = Instance.new("TextLabel")
			label.Name = `Log{logIndex}`
			label.LayoutOrder = logIndex
			label.Size = UDim2.new(1, -8, 0, 30)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(190, 198, 210)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top
			label.TextWrapped = true
			label.TextSize = 11
			label.Font = Enum.Font.Code
			label.Text = line
			label.Parent = logFrame
		end

		logFrame.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize.Y + 12)
		logFrame.CanvasPosition = Vector2.new(0, math.max(0, logLayout.AbsoluteContentSize.Y - logFrame.AbsoluteWindowSize.Y))
	end)

	return screenGui
end

return BotTrainerUI
