local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)

local SetChatTypingModeRE = Net:RemoteEvent("SetChatTypingMode")

local players = {}

local PlayerChatManager = {}

function PlayerChatManager.SetPlayerTypingMode(player, modeNumber) -- 0 = OFF, 1 = LIMITED, 2 = FULL
	if not players[player] then players[player] = {} end
	players[player].typingMode = modeNumber

	SetChatTypingModeRE:FireClient(player, modeNumber)
end

function PlayerChatManager.GetPlayerTypingMode(player)
	if not players[player] then return end

	return players[player].typingMode
end

return PlayerChatManager
