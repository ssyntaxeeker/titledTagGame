local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Packages.Net)

local ChangeSettingsRE = Net:RemoteEvent("ChangeSettings")

local SettingsUtils = {}

function SettingsUtils.SlideMarker(marker, onUpdate)
	if not marker then return end
	local slider = marker.Parent
	marker.Active = true

	local dragging = false
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

	local function getPercentFromMouse()
		if not slider then return lastPercent end
		local mouse = UserInputService:GetMouseLocation()
		local absPos, absSize = slider.AbsolutePosition, slider.AbsoluteSize
		if absSize.X <= 0 then return lastPercent end
		local x = math.clamp(mouse.X - absPos.X, 0, absSize.X)
		return x / absSize.X, mouse, absPos, absSize
	end

	local function finish()
		if not dragging then return end
		dragging = false

		local percent = getPercentFromMouse()
		lastPercent = percent
		local result = safeCall(onUpdate, percent)
		ChangeSettingsRE:FireServer(marker:GetAttribute("settingName"), marker:GetAttribute("keyName"), result)

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
		local percent, mouse, absPos, absSize = getPercentFromMouse()
		if not percent then
			finish()
			return
		end

		lastPercent = percent
		marker.Position = UDim2.new(percent, 0, marker.Position.Y.Scale, marker.Position.Y.Offset)
		safeCall(onUpdate, percent)

		if mouse then
			if
				mouse.X < absPos.X - margin
				or mouse.X > absPos.X + absSize.X + margin
				or mouse.Y < absPos.Y - margin
				or mouse.Y > absPos.Y + absSize.Y + margin
			then
				finish()
			end
		end
	end

	local function begin()
		if dragging then return end
		dragging = true
		update()
		renderConn = RunService.RenderStepped:Connect(update)
		inputEndedConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then finish() end
		end)
	end

	marker.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then begin() end
	end)

	if slider then
		slider.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then begin() end
		end)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not slider then return end
			local pos = UserInputService:GetMouseLocation()
			local ap, asz = slider.AbsolutePosition, slider.AbsoluteSize
			if pos.X >= ap.X and pos.X <= ap.X + asz.X and pos.Y >= ap.Y and pos.Y <= ap.Y + asz.Y then begin() end
		end
	end)

	marker:GetPropertyChangedSignal("Parent"):Connect(function()
		slider = marker.Parent
	end)

	local initial = marker.Position.X.Scale or 0
	lastPercent = initial
	safeCall(onUpdate, initial)
end

return SettingsUtils
