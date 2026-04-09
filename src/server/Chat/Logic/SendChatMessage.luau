local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ChatConfig = require(ReplicatedStorage.Shared.Configs.ChatConfig)
local ChatServerFunctions = require(ServerStorage.Modules.Chat.Logic.ChatServerFunctions)
local CommandRegistry = require(ServerStorage.Modules.Chat.Commands.CommandRegistry)
local Net = require(ReplicatedStorage.Packages.Net)

local SendChatMessageRE = Net:RemoteEvent("SendChatMessage")

SendChatMessageRE.OnServerEvent:Connect(function(player, messageData)
	local serverMessageData = {
		sender = player,
		message = messageData.text,
		channel = messageData.channel,
		mentions = messageData.mentions,
	}

	local dataIsValid = ChatServerFunctions.ValidateMessageData(serverMessageData)
	if not dataIsValid then
		warn(`Invalid chat message data`)
		return
	end

	if serverMessageData.message:sub(1, 1) == ChatConfig.commandPrefix then
		local messageWords = serverMessageData.message:split(" ")
		local command = table.remove(messageWords, 1)
		command = command:gsub("/", "")
		if not command then return end

		local commandFn = CommandRegistry.GetCommand(command)
		if not commandFn then return end

		commandFn(serverMessageData.sender, table.unpack(messageWords))

		return
	end

	local filteredMessage = ChatServerFunctions.FilterMessageData(serverMessageData)
	if not filteredMessage then return end

	serverMessageData.message = filteredMessage

	ChatServerFunctions.BroadcastMessage(serverMessageData)
end)

return 0
