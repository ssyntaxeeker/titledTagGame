--!strict
--[[
    BotTrainerUI (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Compact dock for the rebuilt runtime. It exposes only operations that are
    implemented by the new architecture and keeps status/logs scrollable.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BotTrainerUI = {}

local function label(parent: Instance, height: number, text: string): TextLabel
	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(1, -12, 0, height)
	value.BackgroundColor3 = Color3.fromRGB(25, 28, 33)
	value.BorderSizePixel = 0
	value.Font = Enum.Font.Code
	value.TextSize = 11
	value.TextColor3 = Color3.fromRGB(220, 225, 232)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextYAlignment = Enum.TextYAlignment.Top
	value.TextWrapped = true
	value.Text = text
	value.Parent = parent
	return value
end

local function button(parent: Instance, text: string, callback: () -> (boolean, string)): TextButton
	local value = Instance.new("TextButton")
	value.Size = UDim2.new(1, -12, 0, 30)
	value.BackgroundColor3 = Color3.fromRGB(44, 50, 58)
	value.BorderSizePixel = 0
	value.Font = Enum.Font.GothamMedium
	value.TextSize = 12
	value.TextColor3 = Color3.fromRGB(240, 243, 248)
	value.Text = text
	value.Parent = parent
	value.Activated:Connect(function()
		local success, detail = callback()
		value.BackgroundColor3 = if success then Color3.fromRGB(38, 105, 72) else Color3.fromRGB(130, 48, 58)
		value.Text = `{text}: {detail}`
		task.delay(0.8, function()
			if value.Parent then
				value.BackgroundColor3 = Color3.fromRGB(44, 50, 58)
				value.Text = text
			end
		end)
	end)
	return value
end

function BotTrainerUI.create(runtime: any): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("BotTrainerV2")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BotTrainerV2"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -10, 0, 8)
	panel.Size = UDim2.new(0, 330, 0, 520)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local scale = Instance.new("UIScale")
	local camera = Workspace.CurrentCamera
	scale.Scale = if camera then math.clamp(camera.ViewportSize.Y / 720, 0.72, 1) else 1
	scale.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = panel
	local title = label(panel, 28, "  UTG TRAINING BOT V2")
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextYAlignment = Enum.TextYAlignment.Center
	local status = label(panel, 56, "Idle")
	button(panel, "Build 3D Navigation", runtime.buildGraph)
	button(panel, "Spawn / Reset Bot", runtime.spawnBot)
	button(panel, "Start / Pause", runtime.toggleEnabled)
	button(panel, "Toggle Tagger / Runner", runtime.toggleRole)
	button(panel, "Toggle Player / Bot Duel", runtime.toggleDuelMode)
	button(panel, "Toggle Route Visuals", runtime.toggleVisuals)
	button(panel, "Find Marker Routes", runtime.buildRouteLabRoutes)
	button(panel, "Cycle Marker Route", runtime.cycleRouteLab)
	button(panel, "Teach Vault: Mark / Save", runtime.teachVault)
	local logs = Instance.new("ScrollingFrame")
	logs.Size = UDim2.new(1, -12, 1, -405)
	logs.BackgroundColor3 = Color3.fromRGB(23, 26, 31)
	logs.BorderSizePixel = 0
	logs.ScrollBarThickness = 5
	logs.CanvasSize = UDim2.new()
	logs.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logs.Parent = panel
	local logText = label(logs, 300, "")
	logText.Size = UDim2.new(1, -8, 0, 300)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		status.Text = runtime.getStatus()
		logText.Text = runtime.getLogs()
		logText.Size = UDim2.new(1, -8, 0, math.max(300, logText.TextBounds.Y + 8))
	end)
	return gui
end

return table.freeze(BotTrainerUI)
