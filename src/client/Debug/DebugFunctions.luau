local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local DebugUI = Assets.UI.DebugUI:Clone()
DebugUI.Parent = playerGui

local SpeedDisplayUI = Assets.UI.SpeedDisplayUI:Clone()
SpeedDisplayUI.Parent = playerGui

local DebugFunctions = {}
local ENTER_OFFSET = UDim2.fromOffset(0, 6)
local EXIT_OFFSET = UDim2.fromOffset(0, -4)
local ENTER_TWEEN_INFO = TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EXIT_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local LAYOUT_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function fadeAndDestroy(printFrame)
	if printFrame:GetAttribute("Fading") then return end
	printFrame:SetAttribute("Fading", true)

	local textLabel = printFrame:FindFirstChild("TextLabel")
	assert(textLabel and textLabel:IsA("TextLabel"), "[DebugFunctions.fadeAndDestroy] print has no TextLabel")
	local printList = printFrame.Parent
	local hasOtherPrint = false
	if printList then
		for _, sibling in printList:GetChildren() do
			if sibling:IsA("Frame") and sibling ~= printFrame and sibling.Name == "Print" then
				hasOtherPrint = true
				break
			end
		end
	end
	if hasOtherPrint then
		local currentSize = printFrame.Size
		local automaticSize = printFrame.AutomaticSize
		if automaticSize == Enum.AutomaticSize.Y or automaticSize == Enum.AutomaticSize.XY then
			printFrame.AutomaticSize = Enum.AutomaticSize.None
			printFrame.Size = UDim2.new(currentSize.X.Scale, currentSize.X.Offset, 0, printFrame.AbsoluteSize.Y)
			currentSize = printFrame.Size
		end
		printFrame.ClipsDescendants = true
		TweenService:Create(printFrame, LAYOUT_TWEEN_INFO, {
			Size = UDim2.new(currentSize.X.Scale, currentSize.X.Offset, 0, 0),
		}):Play()
	end

	local fadeTween = TweenService:Create(textLabel, EXIT_TWEEN_INFO, {
		Position = textLabel.Position + EXIT_OFFSET,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local stroke = textLabel:FindFirstChildOfClass("UIStroke")
	if stroke then TweenService:Create(stroke, EXIT_TWEEN_INFO, { Transparency = 1 }):Play() end
	fadeTween:Play()

	task.delay(EXIT_TWEEN_INFO.Time, function()
		if printFrame.Parent then printFrame:Destroy() end
	end)
end

function DebugFunctions.Print(message, color)
	if SettingsInterface.debug.showValues == false then return end

	local printList = DebugUI.PrintList
	local newPrint = printList.Template:Clone()
	assert(newPrint:IsA("Frame"), "[DebugFunctions.Print] PrintList.Template must be a Frame")
	local textLabel = newPrint:FindFirstChild("TextLabel")
	assert(textLabel and textLabel:IsA("TextLabel"), "[DebugFunctions.Print] PrintList.Template has no TextLabel")
	local restingPosition = textLabel.Position
	local restingTextTransparency = textLabel.TextTransparency
	local restingStrokeTransparency = textLabel.TextStrokeTransparency
	local stroke = textLabel:FindFirstChildOfClass("UIStroke")
	local restingUIStrokeTransparency = if stroke then stroke.Transparency else nil

	textLabel.Text = message
	newPrint.Name, newPrint.Visible, newPrint.LayoutOrder = "Print", true, 0

	if color == "Rainbow" then
		Assets.UI.Extra.RainbowBright:Clone().Parent = textLabel
	elseif typeof(color) == "Color3" then
		textLabel.TextColor3 = color
	end

	textLabel.Position = restingPosition + ENTER_OFFSET
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1
	if stroke then stroke.Transparency = 1 end
	newPrint.Parent = printList
	TweenService:Create(textLabel, ENTER_TWEEN_INFO, {
		Position = restingPosition,
		TextTransparency = restingTextTransparency,
		TextStrokeTransparency = restingStrokeTransparency,
	}):Play()
	if stroke and restingUIStrokeTransparency then
		TweenService:Create(stroke, ENTER_TWEEN_INFO, { Transparency = restingUIStrokeTransparency }):Play()
	end

	for _, child in printList:GetChildren() do
		if child:IsA("Frame") and child ~= newPrint and child.Name == "Print" then fadeAndDestroy(child) end
	end

	task.delay(2, function()
		if newPrint.Parent then fadeAndDestroy(newPrint) end
	end)
end

function DebugFunctions.VisualizeRaycast(origin, direction, color)
	if SettingsInterface.debug.showRaycasts == false then return end

	local rayLength = direction.Magnitude

	local rayPart = Instance.new("Part")
	rayPart.Anchored = true
	rayPart.CanCollide = false
	rayPart.CanQuery = false
	rayPart.Size = Vector3.new(0.02, 0.02, rayLength)
	rayPart.Color = color or Color3.fromRGB(128, 0, 128)
	rayPart.Material = Enum.Material.Neon
	rayPart.CFrame = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -rayLength / 2)
	rayPart.Parent = workspace.Debug

	game:GetService("Debris"):AddItem(rayPart, 3)
end

function DebugFunctions.VisualizeSpherecast(origin, radius)
	if SettingsInterface.debug.showRaycasts == false then return end

	local sphere = Instance.new("Part")
	sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	sphere.Shape = Enum.PartType.Ball
	sphere.CFrame = CFrame.new(origin)
	sphere.Color = Color3.new(0.25, 1, 0.25)
	sphere.Material = Enum.Material.Neon
	sphere.Transparency = 0.8
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.Parent = workspace
	Debris:AddItem(sphere, 5)
end

local currentFps = 0
local lastFpsUpdate = os.clock()
local currentRegion = ReplicatedStorage:GetAttribute("Region")

function DebugFunctions.Update()
	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then return end

	local walkSpeed = humanoid.WalkSpeed

	SpeedDisplayUI.Speed.Text = math.floor(walkSpeed)

	if SettingsInterface.debug.showDebug == false then
		DebugUI.DebugLabel.Text = ""
		return
	end

	if not currentRegion then currentRegion = "N/A" end

	local jumpPower, velocity = humanoid.JumpPower, rootPart.Velocity

	if os.clock() - lastFpsUpdate > 0.5 then
		currentFps = math.floor(1 / RunService.RenderStepped:Wait())
		lastFpsUpdate = os.clock()
	end

	local momentum = math.clamp(walkSpeed - (character:GetAttribute("MaxRunSpeed") or walkSpeed), 0, 100)

	DebugUI.DebugLabel.Text = string.format(
		"debug:\nFPS: %d\nWalkSpeed: %.2f\nJumpPower: %.2f\nVelocity: %.2f\nFalling speed: %.2f\nMomentum: %.2f\nRegion: %s",
		currentFps,
		walkSpeed,
		jumpPower,
		velocity.Magnitude,
		velocity.Y,
		momentum,
		currentRegion
	)
end

return DebugFunctions
