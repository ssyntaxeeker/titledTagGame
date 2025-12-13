local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local MobileFunctions = require(ReplicatedStorage.Modules.Mobile.MobileFunctions)
local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local ChangeSettingsRE = Net:RemoteEvent("ChangeSettings")

local localPlayer = Players.LocalPlayer
local MobileUI

local Customization = {
	Active = false,
	Selected = nil,
	DragOffset = nil,
	Resizing = false,
}

local function createResizeHandle(element)
	local handle = element:FindFirstChild("ResizeHandle")
	if not handle then
		handle = Instance.new("Frame")
		handle.Name = "ResizeHandle"
		handle.AnchorPoint = Vector2.new(1, 1)
		handle.Size = UDim2.fromOffset(23, 23)
		handle.Position = UDim2.fromScale(1, 1)
		handle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		handle.BackgroundTransparency = 0.3
		handle.BorderSizePixel = 0
		handle.ZIndex = element.ZIndex + 1
		handle.Parent = element
	end
	handle.Visible = Customization.Active
	return handle
end

local function startDrag(button, input)
	Customization.Selected = button
	Customization.DragOffset = Vector2.new(input.Position.X, input.Position.Y) - button.AbsolutePosition
	Customization.Resizing = false
end

local function startResize(button, input)
	Customization.Selected = button
	Customization.DragOffset = Vector2.new(input.Position.X, input.Position.Y)
	Customization.Resizing = true
end

local function endInteraction()
	if not Customization.Selected then return end

	local name = Customization.Selected.Name
	SettingsInterface.mobile[name .. "Position"] = Customization.Selected.Position
	SettingsInterface.mobile[name .. "Size"] = Customization.Selected.Size

	ChangeSettingsRE:FireServer("mobile", name .. "Position", Customization.Selected.Position)
	ChangeSettingsRE:FireServer("mobile", name .. "Size", Customization.Selected.Size)

	Customization.Selected = nil
end

local function onInputChanged(input)
	if not Customization.Active or not Customization.Selected then return end
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

	local selected = Customization.Selected

	if Customization.Resizing then
		local corner = selected.AbsolutePosition
		local delta = Vector2.new(input.Position.X, input.Position.Y) - corner
		selected.Size = UDim2.fromOffset(math.max(20, delta.X), math.max(20, delta.Y))
	else
		local newPos = Vector2.new(input.Position.X, input.Position.Y) - Customization.DragOffset
		selected.Position = UDim2.fromOffset(newPos.X, newPos.Y)
	end
end

local function connectElement(element)
	createResizeHandle(element)

	element.InputBegan:Connect(function(input)
		if not Customization.Active then return end
		if Customization.Selected then return end

		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			local handle = element:FindFirstChild("ResizeHandle")
			if handle and input.Position.X > handle.AbsolutePosition.X and input.Position.Y > handle.AbsolutePosition.Y then
				startResize(element, input)
			else
				startDrag(element, input)
			end
		end
	end)
end

function Customization.Toggle(state)
	if not MobileUI then return end

	Customization.Active = state
	MobileUI.CloseCustomization.Visible = state
	MobileUI.ResetButtons.Visible = state

	if state == true then
		MobileFunctions.UnhookButtons()
	else
		MobileFunctions.HookButtons()
	end

	for _, btn in MobileUI.Buttons:GetChildren() do
		if btn:IsA("GuiObject") then
			local handle = btn:FindFirstChild("ResizeHandle")
			if handle then handle.Visible = state end
			local stroke = btn:FindFirstChild("CustomizationStroke")
			if stroke then stroke.Enabled = state end
		end
	end
	local thumb = MobileUI:FindFirstChild("ThumbstickFrame")
	if thumb then
		local handle = thumb:FindFirstChild("ResizeHandle")
		if handle then handle.Visible = state end
		local stroke = thumb:FindFirstChild("CustomizationStroke")
		if stroke then stroke.Enabled = state end
	end
end

Schedules.Boot.job(function()
	if UserInputService.TouchEnabled ~= true then return end

	MobileUI = localPlayer.PlayerGui:WaitForChild("MobileUI")
	for _, btn in MobileUI.Buttons:GetChildren() do
		if btn:IsA("TextButton") then connectElement(btn) end
	end

	MobileUI.CloseCustomization.MouseButton1Down:Connect(function()
		Customization.Toggle(false)
	end)

	MobileUI.ResetButtons.MouseButton1Down:Connect(function()
		for _, btn in MobileUI.Buttons:GetChildren() do
			if btn:IsA("TextButton") then
				btn.Position = UDim2.fromScale(0.5, 0.5)
				btn.Size = UDim2.fromScale(0.2, 0.2)
			end
		end

		MobileUI.ThumbstickFrame.Position = UDim2.fromScale(0.3, 0.5)
		MobileUI.ThumbstickFrame.Size = UDim2.fromScale(0.25, 0.25)
	end)

	connectElement(MobileUI.ThumbstickFrame)
end)

UserInputService.InputChanged:Connect(onInputChanged)
UserInputService.InputEnded:Connect(function()
	if Customization.Active then endInteraction() end
end)

return Customization
