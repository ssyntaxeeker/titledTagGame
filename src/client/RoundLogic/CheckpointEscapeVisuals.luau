--!strict
--[[
    CheckpointEscapeVisuals (Client)
    =================================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Marks each round participant's own next ordered escape checkpoint.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CheckpointUtils = require(ReplicatedStorage.Shared.Utils.CheckpointUtils)
local CheckpointEscapeConfig = require(ReplicatedStorage.Shared.Configs.CheckpointEscape)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer
local markerJanitor = Janitor.new()
local characterJanitor = Janitor.new()

local function getCompass(): (ScreenGui?, GuiObject?, TextLabel?)
	local compassUI = localPlayer.PlayerGui:FindFirstChild("CheckpointCompassUI")
	if not compassUI then return nil, nil, nil end
	assert(compassUI:IsA("ScreenGui"), "[CheckpointEscapeVisuals] CheckpointCompassUI must be a ScreenGui")
	local compass = compassUI:FindFirstChild("Compass")
	assert(compass and compass:IsA("GuiObject"), "[CheckpointEscapeVisuals] CheckpointCompassUI has no Compass")
	local pointer = compass:FindFirstChild("Pointer")
	local distance = compass:FindFirstChild("Distance")
	assert(pointer and pointer:IsA("GuiObject"), "[CheckpointEscapeVisuals] Compass has no Pointer")
	assert(distance and distance:IsA("TextLabel"), "[CheckpointEscapeVisuals] Compass has no Distance")
	return compassUI, pointer, distance
end

local function syncMarker()
	markerJanitor:Cleanup()
	local compassUI, pointer, distanceLabel = getCompass()
	if compassUI then compassUI.Enabled = false end
	local character = localPlayer.Character
	if workspace:GetAttribute("Gamemode") ~= "CheckpointEscape" or not character then return end
	if localPlayer:GetAttribute("CheckpointParticipant") ~= true then return end

	local map = workspace:FindFirstChild("Map")
	if not map then return end
	local checkpoints = CheckpointUtils.GetOrdered(map)
	if #checkpoints == 0 then return end
	local progress = localPlayer:GetAttribute("CheckpointProgress") or 0
	local totalProgress = #checkpoints * CheckpointEscapeConfig.laps
	if progress >= totalProgress then return end
	local checkpointIndex = progress % #checkpoints + 1
	local lap = math.floor(progress / #checkpoints) + 1
	local checkpoint = checkpoints[checkpointIndex]
	if not checkpoint then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "EscapeCheckpointHighlight"
	highlight.Adornee = checkpoint
	highlight.FillColor = Color3.fromRGB(72, 255, 132)
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(230, 255, 238)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = checkpoint
	markerJanitor:Add(highlight)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EscapeCheckpointLabel"
	billboard.Adornee = checkpoint
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(180, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, checkpoint.Size.Y / 2 + 2, 0)
	billboard.Parent = checkpoint
	markerJanitor:Add(billboard)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = `LAP {lap}/{CheckpointEscapeConfig.laps} - CHECKPOINT {checkpointIndex}/{#checkpoints}`
	label.TextColor3 = Color3.fromRGB(230, 255, 238)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard

	if compassUI and pointer and distanceLabel then
		compassUI.Enabled = true
		markerJanitor:Add(RunService.RenderStepped:Connect(function()
			local activeCharacter = localPlayer.Character
			local rootPart = if activeCharacter then activeCharacter:FindFirstChild("HumanoidRootPart") else nil
			local camera = workspace.CurrentCamera
			if not rootPart or not rootPart:IsA("BasePart") or not camera then return end

			local offset = checkpoint.Position - rootPart.Position
			local flatOffset = offset * Vector3.new(1, 0, 1)
			if flatOffset.Magnitude > 0.001 then
				local cameraDirection = camera.CFrame:VectorToObjectSpace(flatOffset.Unit)
				pointer.Rotation = math.deg(math.atan2(cameraDirection.X, -cameraDirection.Z))
			end
			distanceLabel.Text = `{math.floor(offset.Magnitude + 0.5)} studs`
		end))
	end
end

local function listenToCharacter(character: Model)
	characterJanitor:Cleanup()
	characterJanitor:Add(character:GetAttributeChangedSignal("Role"):Connect(syncMarker))
	syncMarker()
end

local function init()
	workspace:GetAttributeChangedSignal("Gamemode"):Connect(syncMarker)
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Map" then syncMarker() end
	end)
	workspace.ChildRemoved:Connect(function(child)
		if child.Name == "Map" then syncMarker() end
	end)
	localPlayer:GetAttributeChangedSignal("CheckpointProgress"):Connect(syncMarker)
	localPlayer:GetAttributeChangedSignal("CheckpointParticipant"):Connect(syncMarker)
	localPlayer.CharacterAdded:Connect(listenToCharacter)
	if localPlayer.Character then listenToCharacter(localPlayer.Character) end
end

return Schedules.Boot.job(init)
