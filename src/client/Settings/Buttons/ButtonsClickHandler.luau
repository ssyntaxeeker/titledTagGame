local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)
local UIFunctions = require(ReplicatedStorage.Modules.Settings.UIFunctions)

local function clickedButton(tab)
	UIFunctions.ChangeTab(tab)
end

local function initListener()
	for _, button in UIFunctions.ReturnUI().Main.Buttons:GetChildren() do
		if not button:IsA("TextButton") then continue end

		button.MouseButton1Up:Connect(function()
			clickedButton(button.Name)
		end)
	end
end

return Schedules.Boot.job(initListener)
