local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local UIFunctions = require(ReplicatedStorage.Modules.Settings.UIFunctions)

InputsManager.AddInput("ToggleSettings", {
	Keys = { Enum.KeyCode.M },
	OnBegan = function()
		if UIFunctions.IsOpen() then
			UIFunctions.Close()
			UserInputService.MouseIconEnabled = false
		else
			UIFunctions.Open()
			UserInputService.MouseIconEnabled = true
		end
	end,
})

return 0
