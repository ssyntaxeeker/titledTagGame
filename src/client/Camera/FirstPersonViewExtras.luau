local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local localPlayer = Players.LocalPlayer

local viewableParts = { "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local renderStepped

local function FirstPerson(character)
	for _, part in character:GetDescendants() do
		if not part:IsA("BasePart") then continue end

		local highlight = part:FindFirstChild("NTBBreakHighlight")
		if highlight then highlight.Visible = false end

		if not table.find(viewableParts, part.Name) then
			part.LocalTransparencyModifier = 1
			continue
		end

		part.LocalTransparencyModifier = SettingsInterface.display.firstPersonTransparency
	end
end

local function ThirdPerson(character)
	for _, part in character:GetDescendants() do
		if not part:IsA("BasePart") or part.Name == "HumanoidRootPart" then continue end

		part.LocalTransparencyModifier = 0

		local highlight = part:FindFirstChild("NTBBreakHighlight")
		if highlight then highlight.Visible = true end
	end
end

local function setMouseIcon()
	UserInputService.MouseIcon = "rbxassetid://15722065980"
end

local function initCharacter(character)
	if renderStepped then renderStepped:Disconnect() end

	local humanoid = character:WaitForChild("Humanoid")

	setMouseIcon()

	--humanoid.HipHeight = -0.1

	humanoid.Died:Connect(function()
		if not renderStepped then return end
		renderStepped:Disconnect()
		renderStepped = nil
	end)

	renderStepped = RunService.PreRender:Connect(function()
		if CameraModule.FirstPerson == true then
			FirstPerson(character)
		else
			ThirdPerson(character)
		end
	end)
end

local function handleConnections()
	localPlayer.CharacterAdded:Connect(initCharacter)

	if localPlayer.Character then initCharacter(localPlayer.Character) end
end

return Schedules["Boot"].job(handleConnections)
