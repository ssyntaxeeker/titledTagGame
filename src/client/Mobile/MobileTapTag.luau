--!strict
--[[
    MobileTapTag (Client)
    =====================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Converts deliberate world taps into tag attempts while rejecting action
    buttons, thumbstick input, camera drags, holds, and multitouch gestures.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MobileFunctions = require(ReplicatedStorage.Modules.Mobile.MobileFunctions)
local TagFunctions = require(ReplicatedStorage.Modules.Tag.TagFunctions)

type TouchInfo = {
	startPosition: Vector2,
	startedAt: number,
	cancelled: boolean,
}

local localPlayer = Players.LocalPlayer
local touchInfoByInput: { [InputObject]: TouchInfo } = {}
local initialized = false
local MAXIMUM_TAP_SECONDS = 0.32
local MAXIMUM_TAP_MOVEMENT = 12

local function touchesInteractiveGui(position: Vector2): boolean
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return true end

	local mobileUI = playerGui:FindFirstChild("MobileUI")
	local buttons = if mobileUI then mobileUI:FindFirstChild("Buttons") else nil
	local thumbstick = if mobileUI then mobileUI:FindFirstChild("ThumbstickFrame") else nil
	for _, guiObject in playerGui:GetGuiObjectsAtPosition(position.X, position.Y) do
		if guiObject:IsA("GuiButton") or guiObject:IsA("TextBox") then return true end
		if buttons and guiObject:IsDescendantOf(buttons) then return true end
		if thumbstick and (guiObject == thumbstick or guiObject:IsDescendantOf(thumbstick)) then return true end
	end
	return false
end

local function cancelCurrentTouches()
	for _, info in touchInfoByInput do
		info.cancelled = true
	end
end

local MobileTapTag = {}

function MobileTapTag.init()
	assert(not initialized, "[MobileTapTag.init] mobile tap input is already initialized")
	initialized = true
	UserInputService.TouchStarted:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent or MobileFunctions.HasActiveButtonInput() then
			cancelCurrentTouches()
			return
		end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if touchesInteractiveGui(position) then return end

		if next(touchInfoByInput) ~= nil then cancelCurrentTouches() end
		touchInfoByInput[input] = {
			startPosition = position,
			startedAt = os.clock(),
			cancelled = next(touchInfoByInput) ~= nil,
		}
	end)

	UserInputService.TouchMoved:Connect(function(input: InputObject)
		local info = touchInfoByInput[input]
		if not info then return end
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if (position - info.startPosition).Magnitude < MAXIMUM_TAP_MOVEMENT then return end
		cancelCurrentTouches()
	end)

	UserInputService.TouchEnded:Connect(function(input: InputObject)
		local info = touchInfoByInput[input]
		if not info then return end
		touchInfoByInput[input] = nil

		if info.cancelled or MobileFunctions.HasActiveButtonInput() then return end
		if os.clock() - info.startedAt > MAXIMUM_TAP_SECONDS then return end
		TagFunctions.Tag()
	end)
end

return table.freeze(MobileTapTag)
