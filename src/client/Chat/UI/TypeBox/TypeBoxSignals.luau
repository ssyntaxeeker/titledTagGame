local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatUIInterface = require(ReplicatedStorage.Modules.Chat.UI.ChatUIInterface)
local TypeBoxFunctions = require(ReplicatedStorage.Modules.Chat.UI.TypeBox.TypeBoxFunctions)

local function initTypeBox(typeBox)
	TypeBoxFunctions.SetUpHighlightLabel(typeBox)

	TypeBoxFunctions.HookTypeBoxEvents(typeBox)
end

ChatUIInterface.createdChatUISignal:Connect(function()
	initTypeBox(ChatUIInterface.UI.MainFrame.TypeBoxFrame.TypeBox)
end)

return 0
