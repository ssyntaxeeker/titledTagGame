local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatUIFunctions = require(ReplicatedStorage.Modules.Chat.UI.ChatUIFunctions)
local ClientChatInterface = require(ReplicatedStorage.Modules.Chat.ClientChatInterface)

ClientChatInterface.addedMessageToHistorySignal:Connect(ChatUIFunctions.RefreshUI)

return 0
