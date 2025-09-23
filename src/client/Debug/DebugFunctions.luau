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
local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

local function fadeAndDestroy(label, delayTime)
	TweenService:Create(label, tweenInfo, { TextTransparency = 1 }):Play()
	if label:FindFirstChild("UIStroke") then TweenService:Create(label.UIStroke, tweenInfo, { Transparency = 1 }):Play() end

	task.delay(delayTime, function()
		if label.Parent then label:Destroy() end
	end)
end

function DebugFunctions.Print(message, color)
	if SettingsInterface.debug.showValues == false then return end

	local printList = DebugUI.PrintList
	local newPrint = printList.Template:Clone()

	newPrint.Text, newPrint.Name, newPrint.Visible, newPrint.LayoutOrder = message, "Print", true, 0

	if color == "Rainbow" then
		Assets.UI.Extra.Rainbow:Clone().Parent = newPrint
	elseif typeof(color) == "Color3" then
		newPrint.TextColor3 = color
	end

	newPrint.Parent = printList

	for _, child in printList:GetChildren() do
		if child:IsA("TextLabel") and child ~= newPrint and child.Name ~= "Template" then fadeAndDestroy(child, 0.5) end
	end

	task.delay(2, function()
		if newPrint.Parent then fadeAndDestroy(newPrint, 0.5) end
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
