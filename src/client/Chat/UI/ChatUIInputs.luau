local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputsManager = require(ReplicatedStorage.Modules.Inputs.InputsManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local TypeBoxFunctions = require(ReplicatedStorage.Modules.Chat.UI.TypeBox.TypeBoxFunctions)

local function addInput()
	InputsManager.AddInput("CaptureChatTypeBoxFocus", {
		Keys = { Enum.KeyCode.Slash },
		OnEnded = function()
			TypeBoxFunctions.CaptureTypeBoxFocus()
		end,
	})
end

return Schedules.Boot.job(addInput)
