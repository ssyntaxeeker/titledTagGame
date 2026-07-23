--[[
    Route Trainer UI (Studio Command Bar)
    ======================================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Run once in Studio's Command Bar. It creates the editable hierarchy used
    by RouteTrainerUI under StarterGui.
]]

local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")

local previous = StarterGui:FindFirstChild("RouteTrainerUI")
if previous then previous:Destroy() end

local COLORS = {
	panel = Color3.fromRGB(23, 26, 31),
	band = Color3.fromRGB(31, 35, 41),
	button = Color3.fromRGB(48, 55, 64),
	text = Color3.fromRGB(234, 238, 244),
	muted = Color3.fromRGB(157, 167, 180),
	accent = Color3.fromRGB(65, 181, 255),
}

local function label(parent, name, value, position, size, textSize)
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Position = position
	item.Size = size
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.Code
	item.Text = value
	item.TextColor3 = COLORS.text
	item.TextSize = textSize or 12
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Top
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function button(parent, name, value, position, size)
	local item = Instance.new("TextButton")
	item.Name = name
	item.Position = position
	item.Size = size
	item.BackgroundColor3 = COLORS.button
	item.BorderSizePixel = 0
	item.Font = Enum.Font.GothamMedium
	item.Text = value
	item.TextColor3 = COLORS.text
	item.TextSize = 11
	item.Parent = parent
	return item
end

local function list(parent, name, position, size)
	local item = Instance.new("ScrollingFrame")
	item.Name = name
	item.Position = position
	item.Size = size
	item.BackgroundColor3 = COLORS.band
	item.BorderSizePixel = 0
	item.AutomaticCanvasSize = Enum.AutomaticSize.Y
	item.CanvasSize = UDim2.new()
	item.ScrollBarThickness = 5
	item.ClipsDescendants = true
	item.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingLeft = UDim.new(0, 5)
	padding.Parent = item
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = item
	return item
end

local gui = Instance.new("ScreenGui")
gui.Name = "RouteTrainerUI"
gui.DisplayOrder = 25
gui.IgnoreGuiInset = false
gui.ResetOnSpawn = false
gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = StarterGui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(900, 620)
root.BackgroundColor3 = COLORS.panel
root.BorderSizePixel = 0
root.Parent = gui

local scale = Instance.new("UIScale")
scale.Name = "ResponsiveScale"
scale.Scale = 0.9
scale.Parent = root

local header = Instance.new("Frame")
header.Name = "Header"
header.Position = UDim2.fromOffset(12, 10)
header.Size = UDim2.new(1, -24, 0, 30)
header.BackgroundTransparency = 1
header.Parent = root
local title = label(header, "Title", "ROUTE TRAINER / AUTHORING LAB", UDim2.new(), UDim2.new(1, -40, 1, 0), 16)
title.TextColor3 = COLORS.accent
button(header, "Minimize", "-", UDim2.new(1, -30, 0, 0), UDim2.fromOffset(30, 26))

local status = label(root, "Status", "Ready", UDim2.fromOffset(12, 42), UDim2.new(1, -24, 0, 20), 11)
status.TextColor3 = COLORS.muted

local routeTitle = Instance.new("TextBox")
routeTitle.Name = "RouteTitle"
routeTitle.Position = UDim2.fromOffset(12, 66)
routeTitle.Size = UDim2.new(1, -24, 0, 32)
routeTitle.BackgroundColor3 = COLORS.band
routeTitle.BorderSizePixel = 0
routeTitle.ClearTextOnFocus = false
routeTitle.Font = Enum.Font.Code
routeTitle.PlaceholderText = "Route title"
routeTitle.Text = ""
routeTitle.TextColor3 = COLORS.text
routeTitle.PlaceholderColor3 = COLORS.muted
routeTitle.TextSize = 12
routeTitle.TextXAlignment = Enum.TextXAlignment.Left
routeTitle.Parent = root
local titlePadding = Instance.new("UIPadding")
titlePadding.PaddingLeft = UDim.new(0, 10)
titlePadding.Parent = routeTitle

local controls = Instance.new("Frame")
controls.Name = "Controls"
controls.Position = UDim2.fromOffset(12, 106)
controls.Size = UDim2.new(1, -24, 0, 34)
controls.BackgroundTransparency = 1
controls.Parent = root
button(controls, "StartAttempt", "Start Attempt", UDim2.fromOffset(0, 0), UDim2.fromOffset(130, 32))
button(controls, "Success", "Mark Success", UDim2.fromOffset(138, 0), UDim2.fromOffset(130, 32))
button(controls, "Failure", "Mark Failure", UDim2.fromOffset(276, 0), UDim2.fromOffset(130, 32))
button(controls, "Publish", "Publish Best 3", UDim2.fromOffset(414, 0), UDim2.fromOffset(140, 32))
button(controls, "Refresh", "Refresh Routes", UDim2.fromOffset(562, 0), UDim2.fromOffset(140, 32))
local deleteSelected = button(controls, "DeleteSelected", "Delete Owned Route", UDim2.fromOffset(710, 0), UDim2.fromOffset(166, 32))
deleteSelected.BackgroundColor3 = Color3.fromRGB(126, 45, 51)
deleteSelected.Visible = false

label(root, "AttemptsTitle", "DRAFT ATTEMPTS / CLICK TO PREVIEW", UDim2.fromOffset(12, 148), UDim2.fromOffset(280, 18), 11).TextColor3 = COLORS.muted
list(root, "AttemptsList", UDim2.fromOffset(12, 168), UDim2.fromOffset(280, 270))
label(root, "RoutesTitle", "PUBLISHED ROUTES", UDim2.fromOffset(304, 148), UDim2.fromOffset(290, 18), 11).TextColor3 = COLORS.muted
list(root, "RoutesList", UDim2.fromOffset(304, 168), UDim2.fromOffset(290, 270))
label(root, "PublishedTitle", "SELECTED ROUTE ATTEMPTS", UDim2.fromOffset(606, 148), UDim2.fromOffset(282, 18), 11).TextColor3 = COLORS.muted
list(root, "PublishedAttempts", UDim2.fromOffset(606, 168), UDim2.fromOffset(282, 270))

local similar = Instance.new("Frame")
similar.Name = "SimilarPrompt"
similar.Position = UDim2.fromOffset(304, 450)
similar.Size = UDim2.fromOffset(290, 150)
similar.BackgroundColor3 = Color3.fromRGB(42, 38, 28)
similar.BorderSizePixel = 0
similar.Visible = false
similar.Parent = root
label(similar, "Message", "Similar route found", UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 38), 11)
button(similar, "Preview", "Preview Existing", UDim2.fromOffset(8, 52), UDim2.fromOffset(132, 28))
button(similar, "Merge", "Same / Merge", UDim2.fromOffset(148, 52), UDim2.fromOffset(132, 28))
button(similar, "Separate", "Different Route", UDim2.fromOffset(8, 88), UDim2.fromOffset(272, 28))

local ratings = Instance.new("Frame")
ratings.Name = "Ratings"
ratings.Position = UDim2.fromOffset(606, 450)
ratings.Size = UDim2.fromOffset(282, 46)
ratings.BackgroundColor3 = COLORS.band
ratings.BorderSizePixel = 0
ratings.Parent = root
label(ratings, "Title", "RATE SELECTED", UDim2.fromOffset(7, 4), UDim2.fromOffset(105, 18), 10).TextColor3 = COLORS.muted
for rating = 1, 5 do
	button(ratings, "Rate" .. rating, tostring(rating), UDim2.fromOffset(112 + (rating - 1) * 32, 7), UDim2.fromOffset(27, 28))
end

local logFrame = Instance.new("ScrollingFrame")
logFrame.Name = "LogFrame"
logFrame.Position = UDim2.fromOffset(12, 450)
logFrame.Size = UDim2.fromOffset(280, 150)
logFrame.BackgroundColor3 = COLORS.band
logFrame.BorderSizePixel = 0
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.CanvasSize = UDim2.new()
logFrame.ScrollBarThickness = 5
logFrame.Parent = root
local logs = label(logFrame, "Logs", "", UDim2.fromOffset(6, 6), UDim2.new(1, -12, 0, 400), 10)
logs.ZIndex = 2

local restore = button(gui, "RestoreButton", "ROUTE TRAINER | P START", UDim2.new(1, -202, 0, 42), UDim2.fromOffset(190, 34))
restore.AnchorPoint = Vector2.new(0, 0)
restore.Visible = false

Selection:Set { gui }
print("Created StarterGui.RouteTrainerUI")
