local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local ChatChannelsManager = require(ServerStorage.Modules.Chat.Logic.Channels.ChatChannelsManager)
local PlayerChatManager = require(ServerStorage.Modules.Chat.Players.PlayerChatManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function setUpPlayer(player)
	local canPlayerChat = TextChatService:CanUserChatAsync(player.UserId)
	PlayerChatManager.SetPlayerTypingMode(player, canPlayerChat == true and 2 or 1)

	ChatChannelsManager.AddPlayerToChannel("Global", player)
end

local function initPlayers()
	Players.PlayerAdded:Connect(setUpPlayer)

	for _, player in Players:GetPlayers() do
		setUpPlayer(player)
	end
end

return Schedules.Boot.job(initPlayers)
