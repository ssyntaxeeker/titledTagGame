local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local ChatChannelsManager = require(ServerStorage.Modules.Chat.Logic.Channels.ChatChannelsManager)
local ChatConfig = require(ReplicatedStorage.Shared.Configs.ChatConfig)
local ChatServerLogicInterface = require(ServerStorage.Modules.Chat.Logic.ChatServerLogicInterface)
local ChatTypeCheckUtils = require(ReplicatedStorage.Shared.Utils.Chat.TypeCheckUtils)
local Net = require(ReplicatedStorage.Packages.Net)
local PlayerChatManager = require(ServerStorage.Modules.Chat.Players.PlayerChatManager)

local BroadcastChatMessageRE = Net:RemoteEvent("BroadcastChatMessage")

local ChatServerFunctions = {}

function ChatServerFunctions.ValidateMessageData(messageData)
	local sender = messageData.sender
	if not sender then return false end

	if not table.find(ChatChannelsManager.GetPlayersInChannel(messageData.channel), sender) then return false end -- checks if player is in the channel

	return true
end

function ChatServerFunctions.FilterMessageData(messageData)
	local sender = messageData.sender
	local message = messageData.message
	if not sender or not message then return end

	local senderTypingMode = PlayerChatManager.GetPlayerTypingMode(sender)
	if not senderTypingMode then senderTypingMode = 1 end

	if senderTypingMode == 1 then
		local messageIsValid = ChatTypeCheckUtils.MessageHasInvalidWord(message) == nil
		if not messageIsValid then return end
	end

	message = message:sub(1, ChatConfig.maxMessageLength)

	messageData.mentions = ChatTypeCheckUtils.ExtractMentions(message)

	messageData.time = os.clock()

	ChatServerLogicInterface.internalMessageId += 1
	messageData.id = ChatServerLogicInterface.internalMessageId

	local success, returnedData = pcall(function()
		return TextService:FilterStringAsync(message, sender.UserId, Enum.TextFilterContext.PublicChat)
	end)

	if success then
		return returnedData:GetNonChatStringForBroadcastAsync()
	else
		warn("Error generating TextFilterResult:", returnedData)
	end

	return
end

function ChatServerFunctions.BroadcastMessage(messageData)
	local players = ChatChannelsManager.GetPlayersInChannel(messageData.channel)

	for _, player in players do
		BroadcastChatMessageRE:FireClient(player, messageData)
	end
end

return ChatServerFunctions
