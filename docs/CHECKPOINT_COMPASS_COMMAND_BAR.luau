--[[
    Checkpoint Compass (Studio Command Bar)
    =======================================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Run this once in Studio's Command Bar. It creates the editable compass UI
    expected by CheckpointEscapeVisuals under StarterGui.
]]

local StarterGui = game:GetService("StarterGui")
local Selection = game:GetService("Selection")

local previous = StarterGui:FindFirstChild("CheckpointCompassUI")
if previous then previous:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CheckpointCompassUI"
screenGui.DisplayOrder = 8
screenGui.IgnoreGuiInset = false
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = StarterGui

local compass = Instance.new("Frame")
compass.Name = "Compass"
compass.AnchorPoint = Vector2.new(0.5, 0)
compass.Position = UDim2.new(0.5, 0, 0, 72)
compass.Size = UDim2.fromOffset(54, 72)
compass.BackgroundTransparency = 1
compass.Parent = screenGui

local dial = Instance.new("Frame")
dial.Name = "Dial"
dial.AnchorPoint = Vector2.new(0.5, 0)
dial.Position = UDim2.fromScale(0.5, 0)
dial.Size = UDim2.fromOffset(50, 50)
dial.BackgroundColor3 = Color3.fromRGB(16, 20, 19)
dial.BackgroundTransparency = 0.22
dial.BorderSizePixel = 0
dial.Parent = compass

local dialCorner = Instance.new("UICorner")
dialCorner.CornerRadius = UDim.new(1, 0)
dialCorner.Parent = dial

local dialStroke = Instance.new("UIStroke")
dialStroke.Color = Color3.fromRGB(154, 255, 187)
dialStroke.Transparency = 0.2
dialStroke.Thickness = 1.5
dialStroke.Parent = dial

local pointer = Instance.new("TextLabel")
pointer.Name = "Pointer"
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Position = UDim2.new(0.5, 0, 0, 25)
pointer.Size = UDim2.fromOffset(38, 38)
pointer.BackgroundTransparency = 1
pointer.Font = Enum.Font.GothamBold
pointer.Text = "▲"
pointer.TextColor3 = Color3.fromRGB(72, 255, 132)
pointer.TextScaled = true
pointer.ZIndex = 2
pointer.Parent = compass

local center = Instance.new("Frame")
center.Name = "Center"
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.new(0.5, 0, 0, 25)
center.Size = UDim2.fromOffset(5, 5)
center.BackgroundColor3 = Color3.fromRGB(235, 255, 241)
center.BorderSizePixel = 0
center.ZIndex = 3
center.Parent = compass

local centerCorner = Instance.new("UICorner")
centerCorner.CornerRadius = UDim.new(1, 0)
centerCorner.Parent = center

local distance = Instance.new("TextLabel")
distance.Name = "Distance"
distance.AnchorPoint = Vector2.new(0.5, 1)
distance.Position = UDim2.fromScale(0.5, 1)
distance.Size = UDim2.fromOffset(100, 18)
distance.BackgroundTransparency = 1
distance.Font = Enum.Font.GothamMedium
distance.Text = "0 studs"
distance.TextColor3 = Color3.fromRGB(235, 255, 241)
distance.TextSize = 13
distance.TextStrokeTransparency = 0.45
distance.ZIndex = 2
distance.Parent = compass

Selection:Set({ screenGui })
print("Created StarterGui.CheckpointCompassUI")
