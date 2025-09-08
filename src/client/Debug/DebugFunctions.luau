local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = ReplicatedStorage.Assets
local localPlayer = Players.LocalPlayer

local DebugUI = Assets.UI.DebugUI:Clone()
DebugUI.Parent = localPlayer:WaitForChild("PlayerGui")

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
	local printList = DebugUI.PrintList
	local newPrint = printList.Template:Clone()

	newPrint.Text, newPrint.Name, newPrint.Visible, newPrint.LayoutOrder = message, "Print", true, 0

	if color == "Rainbow" then
		Assets.UI.Extra.Rainbow:Clone().Parent = newPrint
	elseif typeof(color) == "Color3" then
		newPrint.TextColor3 = color
	end

	newPrint.Parent = printList

	for _, child in ipairs(printList:GetChildren()) do
		if child:IsA("TextLabel") and child ~= newPrint and child.Name ~= "Template" then fadeAndDestroy(child, 0.5) end
	end

	task.delay(2, function()
		if newPrint.Parent then fadeAndDestroy(newPrint, 0.5) end
	end)
end

function DebugFunctions.Update()
	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	local fps = math.floor(1 / RunService.RenderStepped:Wait())
	local walkSpeed, jumpPower, velocity = humanoid.WalkSpeed, humanoid.JumpPower, rootPart.Velocity
	local momentum = math.clamp(walkSpeed - (character:GetAttribute("MaxRunSpeed") or walkSpeed), 0, 100)

	DebugUI.DebugLabel.Text = string.format(
		"debug:\nFPS: %d\nWalkSpeed: %.2f\nJumpPower: %.2f\nVelocity: %.2f\nFalling speed: %.2f\nMomentum: %.2f",
		fps,
		walkSpeed,
		jumpPower,
		velocity.Magnitude,
		velocity.Y,
		momentum
	)
end

return DebugFunctions
