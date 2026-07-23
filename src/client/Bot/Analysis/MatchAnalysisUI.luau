--!strict
--[[
    MatchAnalysisUI (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Docked technical console for selecting observed players, controlling
    recording, and inspecting objective learned-memory results.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local MouseModalService = require(ReplicatedStorage.Modules.Bot.Analysis.MouseModalService)

local MatchAnalysisUI = {}

local COLORS = table.freeze({
	panel = Color3.fromRGB(24, 27, 32),
	band = Color3.fromRGB(31, 35, 41),
	button = Color3.fromRGB(48, 54, 63),
	buttonHover = Color3.fromRGB(61, 69, 80),
	text = Color3.fromRGB(232, 236, 242),
	muted = Color3.fromRGB(160, 169, 181),
	accent = Color3.fromRGB(62, 175, 255),
	success = Color3.fromRGB(72, 211, 132),
	error = Color3.fromRGB(255, 90, 90),
})

local function text(parent: Instance, value: string, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Font = Enum.Font.Code
	label.Text = value
	label.TextColor3 = COLORS.text
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = parent
	return label
end

local function button(parent: Instance, value: string, callback: () -> (boolean, string)): TextButton
	local control = Instance.new("TextButton")
	control.Size = UDim2.fromOffset(106, 30)
	control.BackgroundColor3 = COLORS.button
	control.BorderSizePixel = 0
	control.AutoButtonColor = false
	control.Font = Enum.Font.GothamMedium
	control.Text = value
	control.TextColor3 = COLORS.text
	control.TextSize = 11
	control.Parent = parent
	control.MouseEnter:Connect(function() control.BackgroundColor3 = COLORS.buttonHover end)
	control.MouseLeave:Connect(function() control.BackgroundColor3 = COLORS.button end)
	control.Activated:Connect(function()
		local success, message = callback()
		control.TextColor3 = if success then COLORS.success else COLORS.error
		control.Text = string.sub(message, 1, 18)
		task.delay(1.2, function()
			if control.Parent then
				control.Text = value
				control.TextColor3 = COLORS.text
			end
		end)
	end)
	return control
end

local function band(parent: Instance, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.BackgroundColor3 = COLORS.band
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function MatchAnalysisUI.create(runtime: any, launcherButton: TextButton?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("MatchAnalysisUI")
	if old then old:Destroy() end
	local janitor = Janitor.new()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MatchAnalysisUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui
	janitor:Add(MouseModalService.acquire(gui))
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 42)
	panel.Size = UDim2.fromOffset(470, 640)
	panel.BackgroundColor3 = COLORS.panel
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = gui
	local panelPadding = Instance.new("UIPadding")
	panelPadding.PaddingTop = UDim.new(0, 10)
	panelPadding.PaddingBottom = UDim.new(0, 10)
	panelPadding.PaddingLeft = UDim.new(0, 10)
	panelPadding.PaddingRight = UDim.new(0, 10)
	panelPadding.Parent = panel
	local panelLayout = Instance.new("UIListLayout")
	panelLayout.Padding = UDim.new(0, 8)
	panelLayout.Parent = panel

	local restoreButton = launcherButton or Instance.new("TextButton")
	restoreButton.AnchorPoint = Vector2.new(1, 0)
	restoreButton.Position = UDim2.new(1, -12, 0, 8)
	restoreButton.Size = UDim2.fromOffset(112, 34)
	restoreButton.BackgroundColor3 = COLORS.panel
	restoreButton.BorderSizePixel = 0
	restoreButton.AutoButtonColor = false
	restoreButton.Font = Enum.Font.GothamMedium
	restoreButton.Text = "ANALYSIS"
	restoreButton.TextColor3 = COLORS.accent
	restoreButton.TextSize = 12
	restoreButton.Visible = false
	if not launcherButton then restoreButton.Parent = gui end
	restoreButton.MouseEnter:Connect(function() restoreButton.BackgroundColor3 = COLORS.buttonHover end)
	restoreButton.MouseLeave:Connect(function() restoreButton.BackgroundColor3 = COLORS.panel end)

	local titleRow = Instance.new("Frame")
	titleRow.Size = UDim2.new(1, 0, 0, 24)
	titleRow.BackgroundTransparency = 1
	titleRow.Parent = panel
	local title = text(titleRow, "MATCH ANALYSIS / OBSERVER", UDim2.new(1, -30, 1, 0), 15)
	title.TextColor3 = COLORS.accent
	local minimizeButton = Instance.new("TextButton")
	minimizeButton.AnchorPoint = Vector2.new(1, 0)
	minimizeButton.Position = UDim2.new(1, 0, 0, 0)
	minimizeButton.Size = UDim2.fromOffset(24, 24)
	minimizeButton.BackgroundColor3 = COLORS.button
	minimizeButton.BorderSizePixel = 0
	minimizeButton.AutoButtonColor = false
	minimizeButton.Font = Enum.Font.GothamBold
	minimizeButton.Text = "-"
	minimizeButton.TextColor3 = COLORS.text
	minimizeButton.TextSize = 16
	minimizeButton.Parent = titleRow
	minimizeButton.MouseEnter:Connect(function() minimizeButton.BackgroundColor3 = COLORS.buttonHover end)
	minimizeButton.MouseLeave:Connect(function() minimizeButton.BackgroundColor3 = COLORS.button end)
	minimizeButton.Activated:Connect(function()
		panel.Visible = false
		restoreButton.Visible = true
	end)
	restoreButton.Activated:Connect(function()
		restoreButton.Visible = false
		panel.Visible = true
	end)
	local status = text(panel, "", UDim2.new(1, 0, 0, 20), 11)
	status.TextColor3 = COLORS.muted

	local pairBand = band(panel, 92)
	local pairLayout = Instance.new("UIListLayout")
	pairLayout.Padding = UDim.new(0, 5)
	pairLayout.Parent = pairBand
	local pairTitle = text(pairBand, "OBSERVED PAIR", UDim2.new(1, 0, 0, 20), 11)
	pairTitle.TextColor3 = COLORS.muted
	local chaserRow = Instance.new("Frame")
	chaserRow.Size = UDim2.new(1, 0, 0, 28)
	chaserRow.BackgroundTransparency = 1
	chaserRow.Parent = pairBand
	local chaserName = text(chaserRow, "CHASER", UDim2.new(1, -138, 1, 0), 12)
	local previousChaser = button(chaserRow, "<", function() return runtime.cycleChaser(-1) end)
	previousChaser.Size = UDim2.fromOffset(28, 28)
	previousChaser.Position = UDim2.new(1, -64, 0, 0)
	local nextChaser = button(chaserRow, ">", function() return runtime.cycleChaser(1) end)
	nextChaser.Size = UDim2.fromOffset(28, 28)
	nextChaser.Position = UDim2.new(1, -30, 0, 0)
	local runnerRow = Instance.new("Frame")
	runnerRow.Size = UDim2.new(1, 0, 0, 28)
	runnerRow.BackgroundTransparency = 1
	runnerRow.Parent = pairBand
	local runnerName = text(runnerRow, "RUNNER", UDim2.new(1, -138, 1, 0), 12)
	local previousRunner = button(runnerRow, "<", function() return runtime.cycleRunner(-1) end)
	previousRunner.Size = UDim2.fromOffset(28, 28)
	previousRunner.Position = UDim2.new(1, -64, 0, 0)
	local nextRunner = button(runnerRow, ">", function() return runtime.cycleRunner(1) end)
	nextRunner.Size = UDim2.fromOffset(28, 28)
	nextRunner.Position = UDim2.new(1, -30, 0, 0)

	local controls = band(panel, 76)
	local controlsLayout = Instance.new("UIGridLayout")
	controlsLayout.CellSize = UDim2.fromOffset(106, 30)
	controlsLayout.CellPadding = UDim2.fromOffset(7, 7)
	controlsLayout.Parent = controls
	button(controls, "Auto Pair", runtime.autoSelectPair)
	button(controls, "Start / Stop", runtime.toggleRecording)
	button(controls, "Save Now", runtime.saveNow)
	button(controls, "Reload Memory", runtime.loadMemory)
	button(controls, "Toggle Visuals", runtime.toggleVisuals)
	button(controls, "Full Visuals", runtime.toggleFullVisuals)

	local memoryBand = band(panel, 160)
	local memoryTitle = text(memoryBand, "LEARNED MEMORY / CANDIDATE LINES", UDim2.new(1, -10, 0, 20), 11)
	memoryTitle.Position = UDim2.fromOffset(5, 4)
	memoryTitle.TextColor3 = COLORS.muted
	local memoryScroll = Instance.new("ScrollingFrame")
	memoryScroll.Position = UDim2.fromOffset(5, 26)
	memoryScroll.Size = UDim2.new(1, -10, 1, -31)
	memoryScroll.BackgroundTransparency = 1
	memoryScroll.BorderSizePixel = 0
	memoryScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	memoryScroll.CanvasSize = UDim2.new()
	memoryScroll.ScrollBarThickness = 5
	memoryScroll.Parent = memoryBand
	local memoryText = text(memoryScroll, "", UDim2.new(1, -8, 0, 240), 11)

	local logBand = band(panel, 200)
	local logTitle = text(logBand, "EVENT LOG", UDim2.new(1, -10, 0, 20), 11)
	logTitle.Position = UDim2.fromOffset(5, 4)
	logTitle.TextColor3 = COLORS.muted
	local logScroll = Instance.new("ScrollingFrame")
	logScroll.Position = UDim2.fromOffset(5, 26)
	logScroll.Size = UDim2.new(1, -10, 1, -31)
	logScroll.BackgroundTransparency = 1
	logScroll.BorderSizePixel = 0
	logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logScroll.CanvasSize = UDim2.new()
	logScroll.ScrollBarThickness = 5
	logScroll.Parent = logBand
	local logText = text(logScroll, "", UDim2.new(1, -8, 0, 800), 10)

	local elapsed = 0
	janitor:Add(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
		scale.Scale = math.clamp(math.min((viewport.X - 20) / 470, (viewport.Y - 60) / 640), 0.62, 1)
		local chaser, runner = runtime.getSelection()
		chaserName.Text = `CHASER  {chaser}`
		runnerName.Text = `RUNNER  {runner}`
		status.Text = runtime.getStatus()
		memoryText.Text = runtime.getMemorySummary()
		logText.Text = runtime.getLogs()
	end))
	gui.Destroying:Connect(function() janitor:Cleanup() end)
	return gui
end

return table.freeze(MatchAnalysisUI)
