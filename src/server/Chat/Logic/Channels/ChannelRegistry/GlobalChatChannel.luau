local ServerStorage = game:GetService("ServerStorage")

local ChatChannelsManager = require(ServerStorage.Modules.Chat.Logic.Channels.ChatChannelsManager)

return ChatChannelsManager.RegisterChannel("Global")
