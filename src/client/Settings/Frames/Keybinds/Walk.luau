--!strict
--[[
    Walk (Client)
    =============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Binds the configurable hold-to-walk action and ensures its settings row
    exists for older SettingsUI assets.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local SettingsUtils = require(ReplicatedStorage.Modules.Settings.SettingsUtils)

local localPlayer = Players.LocalPlayer

local function displayKey(key: EnumItem): string
	return ({ MouseButton1 = "LMB", MouseButton2 = "RMB", MouseButton3 = "MMB" })[key.Name] or key.Name
end

local function updateInput(key: EnumItem)
	MovementInterface.WalkRequested = false
	InputsManager.RemoveInput("Walk")
	InputsManager.AddInput("Walk", {
		Keys = { key },
		OnBegan = function()
			MovementInterface.WalkRequested = true
		end,
		OnEnded = function()
			MovementInterface.WalkRequested = false
		end,
	})
end

local function getFrame(): GuiObject
	local keybinds = localPlayer.PlayerGui.SettingsUI.Main.Frames.Keybinds
	local existing = keybinds:FindFirstChild("walk")
	if existing then
		assert(existing:IsA("GuiObject"), "[Walk.getFrame] Keybinds.walk must be a GuiObject")
		return existing
	end

	local source = keybinds:FindFirstChild("slideAndCrouch")
	assert(source and source:IsA("GuiObject"), "[Walk.getFrame] Keybinds has no row to clone")
	local frame = source:Clone()
	frame.Name = "walk"
	frame.Visible = true
	local greatestLayoutOrder = 0
	for _, child in keybinds:GetChildren() do
		if child:IsA("GuiObject") then greatestLayoutOrder = math.max(greatestLayoutOrder, child.LayoutOrder) end
	end
	frame.LayoutOrder = greatestLayoutOrder + 1

	for _, descendant in frame:GetDescendants() do
		if descendant:IsA("TextLabel") then
			descendant.Text = "walk"
			break
		end
	end
	frame.Parent = keybinds
	return frame
end

local function init()
	local frame = getFrame()
	local button = frame:FindFirstChild("Button")
	assert(button and button:IsA("TextButton"), "[Walk.init] walk frame has no TextButton named Button")
	button:SetAttribute("settingName", "keybinds")
	button:SetAttribute("keyName", "walk")
	local key = SettingsInterface.keybinds.walk
	if typeof(key) ~= "EnumItem" then
		key = Enum.KeyCode.LeftShift
		SettingsInterface.keybinds.walk = key
	end
	button.Text = displayKey(key)
	SettingsUtils.KeybindButton(button, updateInput)
	updateInput(key)

	SettingsInterface.updateSignal:Connect(function()
		local updatedKey = SettingsInterface.keybinds.walk
		if typeof(updatedKey) ~= "EnumItem" then updatedKey = Enum.KeyCode.LeftShift end
		button.Text = displayKey(updatedKey)
		updateInput(updatedKey)
	end)
end

return Schedules.Boot.job(init)
