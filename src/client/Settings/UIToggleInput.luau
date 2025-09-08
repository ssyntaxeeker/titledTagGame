local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local UIFunctions = require(ReplicatedStorage.Modules.Settings.UIFunctions)

InputsManager.AddInput("ToggleSettings", {
	Keys = { Enum.KeyCode.M },
	OnBegan = function()
		if UIFunctions.IsOpen() then
			UIFunctions.Close()
		else
			UIFunctions.Open()
		end
	end,
})

return 0
