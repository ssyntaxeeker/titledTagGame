local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChatConfig = require(ReplicatedStorage.Shared.Configs.ChatConfig)

if not ChatConfig.enabled then
	ContextActionService:UnbindAction("CaptureChatTypeBoxFocus")
	return 0
end

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
