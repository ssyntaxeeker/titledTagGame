local channels = {}

local ChatChannelsManager = {}

function ChatChannelsManager.RegisterChannel(channelName, channelData)
	channels[channelName] = {}

	channels[channelName].Data = channelData or {}
	channels[channelName].Players = {}

	return 0
end

function ChatChannelsManager.AddPlayerToChannel(channelName, player)
	local channel = channels[channelName]
	if not channel then return end

	table.insert(channel.Players, player)
end

function ChatChannelsManager.RemovePlayerFromChannel(playerToRemove, channelName)
	local channel = channels[channelName]
	if not channel then return end

	for index, player in channel do
		if playerToRemove ~= player then continue end

		table.remove(channel.Players, index)
	end
end

function ChatChannelsManager.UnlistPlayerFromChannels(player)
	for _, channel in channels do
		for _, channelPlayers in channel.Players do
			local playerIndex = table.find(channelPlayers, player)
			if not playerIndex then continue end

			table.remove(channelPlayers, playerIndex)
		end
	end
end

function ChatChannelsManager.GetPlayersInChannel(channelName)
	return channels[channelName] and channels[channelName].Players
end

function ChatChannelsManager.GetChannelsPlayerIsIn(player)
	local channelsNames = {}

	for channelName, channel in channels do
		for _, channelPlayers in channel.Players do
			local playerIndex = table.find(channelPlayers, player)
			if not playerIndex then continue end

			table.insert(channelsNames, channelName)
		end
	end

	return channelsNames
end

function ChatChannelsManager.GetAvailableChannels()
	local list = {}

	for channelName, _ in channels do
		table.insert(list, channelName) -- Add a check for available channels based on player
	end

	return list
end

return ChatChannelsManager
