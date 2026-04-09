local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatTextUtils = require(ReplicatedStorage.Shared.Utils.Chat.TextUtils)
local DictionaryUtils = require(ReplicatedStorage.Shared.Utils.Chat.DictionaryUtils)

local ChatTypeCheckUtils = {}

function ChatTypeCheckUtils.MessageHasInvalidWord(text: string): string?
	for word in text:gmatch("%S+") do
		if ChatTextUtils.ExtractMention(word) then continue end
		if ChatTextUtils.IsPureNumber(word) then continue end

		local core = ChatTextUtils.ExtractCoreWord(word:lower())
		if not core or not DictionaryUtils.HasWord(core) then return core end
	end

	return
end

function ChatTypeCheckUtils.ExtractMentions(text: string): { number }
	local mentioned = {}
	local seen = {}

	for word in text:gmatch("%S+") do
		local name = ChatTextUtils.ExtractMention(word)
		if not name then continue end

		for _, player in Players:GetPlayers() do
			if player.Name ~= name or seen[player.UserId] then continue end

			seen[player.UserId] = true
			table.insert(mentioned, player.UserId)
		end
	end

	return mentioned
end

return ChatTypeCheckUtils
