--!strict
--[[
    MouseModalService (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Provides explicit toggle-to-unlock mouse ownership for technical UIs
    without using GuiButton.Modal or permanently fighting the custom camera.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Config = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisConfig)
local MouseVisibilityService = require(ReplicatedStorage.Modules.Cursor.MouseVisibilityService)

local MouseModalService = {}
local ACTION_NAME = "TechnicalUIMouseToggle"
local RENDER_NAME = "TechnicalUIMouseState"
local owners: { [Instance]: boolean } = {}
local ownerCount = 0
local sessionJanitor: any = nil
local hintLabel: TextLabel? = nil
local unlocked = false

local function keyText(key: EnumItem): string
	local aliases = {
		Comma = ",",
		MouseButton1 = "LMB",
		MouseButton2 = "RMB",
		MouseButton3 = "MMB",
	}
	return aliases[key.Name] or key.Name
end

local function updateHint()
	local label = hintLabel
	if not label then return end
	local key = Config.mouseToggleKey
	label.Text = if unlocked
		then `Press {keyText(key)} to lock your mouse`
		else `Press {keyText(key)} to unlock your mouse`
end

local function setUnlocked(value: boolean)
	unlocked = value
	local shouldShowMouse = value or MouseVisibilityService.shouldShowMouse()
	UserInputService.MouseBehavior = if shouldShowMouse then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = shouldShowMouse
	updateHint()
end

local function bindToggle()
	ContextActionService:UnbindAction(ACTION_NAME)
	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		function(_, inputState: Enum.UserInputState): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin then setUnlocked(not unlocked) end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		Config.mouseToggleKey
	)
end

local function beginSession()
	assert(not sessionJanitor, "[MouseModalService.beginSession] session already exists")
	local janitor = Janitor.new()
	sessionJanitor = janitor
	local gui = Instance.new("ScreenGui")
	gui.Name = "TechnicalUIMouseHint"
	gui.DisplayOrder = 1000
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	janitor:Add(gui)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -16)
	label.Size = UDim2.fromOffset(250, 28)
	label.BackgroundColor3 = Color3.fromRGB(18, 21, 26)
	label.BackgroundTransparency = 0.3
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(235, 239, 245)
	label.TextSize = 12
	label.Parent = gui
	hintLabel = label
	bindToggle()
	janitor:Add(function() ContextActionService:UnbindAction(ACTION_NAME) end)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 10, function()
		local shouldShowMouse = unlocked or MouseVisibilityService.shouldShowMouse()
		UserInputService.MouseBehavior = if shouldShowMouse then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = shouldShowMouse
	end)
	janitor:Add(function() RunService:UnbindFromRenderStep(RENDER_NAME) end)
	setUnlocked(false)
end

local function endSession()
	setUnlocked(false)
	local janitor = sessionJanitor
	sessionJanitor = nil
	hintLabel = nil
	if janitor then janitor:Cleanup() end
end

-- UI owners must call the returned cleanup function, or destroy the owner.
-- The final owner restores the normal locked camera state.
function MouseModalService.acquire(owner: Instance): () -> ()
	assert(owner.Parent, "[MouseModalService.acquire] owner must be parented")
	if owners[owner] then error("[MouseModalService.acquire] owner already acquired mouse service") end
	owners[owner] = true
	ownerCount += 1
	if ownerCount == 1 then beginSession() end
	local released = false
	local destroyingConnection: RBXScriptConnection?
	local function release()
		if released then return end
		released = true
		if destroyingConnection then destroyingConnection:Disconnect() end
		owners[owner] = nil
		ownerCount -= 1
		assert(ownerCount >= 0, "[MouseModalService.release] owner count became negative")
		if ownerCount == 0 then endSession() end
	end
	destroyingConnection = owner.Destroying:Connect(release)
	return release
end

return table.freeze(MouseModalService)
