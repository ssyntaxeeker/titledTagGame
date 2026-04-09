local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatConfig = require(ReplicatedStorage.Shared.Configs.ChatConfig)
local ChatLogicInterface = require(ReplicatedStorage.Modules.Chat.Logic.ChatLogicInterface)
local ClientChatInterface = require(ReplicatedStorage.Modules.Chat.ClientChatInterface)

local ClientChatFunctions = {}

function ClientChatFunctions.AddMessageToHistory(messageData)
	local channel = messageData.channel
	if not channel then return end

	if not ChatLogicInterface.chatHistory[channel] then ChatLogicInterface.chatHistory[channel] = {} end

	local chatHistory = ChatLogicInterface.chatHistory[channel]

	if #chatHistory >= ChatConfig.maxChatHistoryMessages - 1 then table.remove(chatHistory, 1) end

	table.insert(ChatLogicInterface.chatHistory[channel], messageData)
	ClientChatInterface.addedMessageToHistorySignal:Fire(channel)
end

return ClientChatFunctions
