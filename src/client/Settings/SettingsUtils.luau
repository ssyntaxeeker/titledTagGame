local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Packages.Net)

local ChangeSettingsRE = Net:RemoteEvent("ChangeSettings")

local SettingsUtils = {}

-- Roblox can dispatch touch input to descendants briefly after an ancestor UI
-- closes. Slider writes are valid only while the complete UI branch is visible.
local function isVisibleForInput(guiObject)
	local current = guiObject
	while current do
		if current:IsA("ScreenGui") then return current.Enabled end
		if current:IsA("GuiObject") and not current.Visible then return false end
		current = current.Parent
	end
	return false
end

function SettingsUtils.KeybindButton(button, onUpdate)
	button.MouseButton1Up:Connect(function()
		button.Text = "-"
		UserInputService.InputBegan:Once(function(input)
			local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
			button.Text = ({ MouseButton1 = "LMB", MouseButton2 = "RMB", MouseButton3 = "MMB" })[key.Name] or key.Name

			onUpdate(key)
			ChangeSettingsRE:FireServer(button:GetAttribute("settingName"), button:GetAttribute("keyName"), key)
		end)
	end)
end

function SettingsUtils.SlideMarker(marker, onUpdate)
	if not marker then return end
	local slider = marker.Parent
	marker.Active = true

	local dragging = false
	local dragInput
	local renderConn
	local inputEndedConn
	local margin = 120
	local lastPercent = 0

	local function safeCall(fn, ...)
		if not fn then return ... end
		local ok, result = pcall(fn, ...)
		if not ok then
			warn("SlideMarker onUpdate error:", result)
			return ...
		end
		return result
	end

	local function getPointerPosition()
		if dragInput and dragInput.UserInputType == Enum.UserInputType.Touch then
			return Vector2.new(dragInput.Position.X, dragInput.Position.Y)
		end
		return UserInputService:GetMouseLocation()
	end

	local function getPercentFromPointer()
		if not slider then return lastPercent end
		local pointerPosition = getPointerPosition()
		local absPos, absSize = slider.AbsolutePosition, slider.AbsoluteSize
		if absSize.X <= 0 then return lastPercent end
		local x = math.clamp(pointerPosition.X - absPos.X, 0, absSize.X)
		return x / absSize.X, pointerPosition, absPos, absSize
	end

	local function finish()
		if not dragging then return end
		dragging = false

		local percent = getPercentFromPointer()
		lastPercent = percent
		local result = safeCall(onUpdate, percent)
		ChangeSettingsRE:FireServer(marker:GetAttribute("settingName"), marker:GetAttribute("keyName"), result)
		dragInput = nil

		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
		if inputEndedConn then
			inputEndedConn:Disconnect()
			inputEndedConn = nil
		end
	end

	local function update()
		local percent, pointerPosition, absPos, absSize = getPercentFromPointer()
		if not percent then
			finish()
			return
		end

		lastPercent = percent
		marker.Position = UDim2.new(percent, 0, marker.Position.Y.Scale, marker.Position.Y.Offset)
		safeCall(onUpdate, percent)

		if pointerPosition then
			if
				pointerPosition.X < absPos.X - margin
				or pointerPosition.X > absPos.X + absSize.X + margin
				or pointerPosition.Y < absPos.Y - margin
				or pointerPosition.Y > absPos.Y + absSize.Y + margin
			then
				finish()
			end
		end
	end

	local function begin(input)
		if dragging or not isVisibleForInput(slider) then return end
		dragging = true
		dragInput = input
		update()
		renderConn = RunService.RenderStepped:Connect(update)
		inputEndedConn = UserInputService.InputEnded:Connect(function(endedInput)
			if endedInput == dragInput then finish() end
		end)
	end

	marker.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then begin(input) end
	end)

	if slider then
		slider.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then begin(input) end
		end)
	end

	marker:GetPropertyChangedSignal("Parent"):Connect(function()
		slider = marker.Parent
	end)

	local initial = marker.Position.X.Scale or 0
	lastPercent = initial
end

return SettingsUtils
