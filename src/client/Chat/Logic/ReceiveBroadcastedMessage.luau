local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientChatFunctions = require(ReplicatedStorage.Modules.Chat.Logic.ClientChatFunctions)
local Net = require(ReplicatedStorage.Packages.Net)

local BroadcastChatMessageRE = Net:RemoteEvent("BroadcastChatMessage")

BroadcastChatMessageRE.OnClientEvent:Connect(function(messageData)
	ClientChatFunctions.AddMessageToHistory(messageData)
end)

return 0
