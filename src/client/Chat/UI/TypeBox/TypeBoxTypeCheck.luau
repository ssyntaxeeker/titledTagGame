local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatConfig = require(ReplicatedStorage.Shared.Configs.ChatConfig)
local ChatTextUtils = require(ReplicatedStorage.Shared.Utils.Chat.TextUtils)
local ChatTypeCheckUtils = require(ReplicatedStorage.Shared.Utils.Chat.TypeCheckUtils)
local ChatUIInterface = require(ReplicatedStorage.Modules.Chat.UI.ChatUIInterface)
local DictionaryUtils = require(ReplicatedStorage.Shared.Utils.Chat.DictionaryUtils)
local TypeBoxTypingModes = require(ReplicatedStorage.Modules.Chat.UI.TypeBox.TypeBoxTypingModes)

local TypeBoxTypeCheck = {}

local function getMode()
	return TypeBoxTypingModes[ChatUIInterface.typingMode] or TypeBoxTypingModes[1]
end

function TypeBoxTypeCheck.GetMentionAutocomplete(prefix: string): string?
	prefix = prefix:sub(2):lower()

	for _, player in Players:GetPlayers() do
		if player.Name:lower():sub(1, #prefix) == prefix then return "@" .. player.Name end
	end

	return
end

function TypeBoxTypeCheck.GetAutocomplete(text: string, cursor: number)
	local current = ChatTextUtils.GetCurrentWord(text, cursor)
	if not current then return end

	local mode = getMode()

	if current:sub(1, 1) == "@" and mode.mentions then return TypeBoxTypeCheck.GetMentionAutocomplete(current) end

	if not mode.autocomplete then return end

	if ChatTextUtils.IsPureNumber(current) then return end

	local core = ChatTextUtils.ExtractCoreWord(current:lower())
	if not core then return end

	return DictionaryUtils.GetCompletion(core)
end

function TypeBoxTypeCheck.ApplyAutocomplete(text, cursor, completion)
	return ChatTextUtils.ReplaceCurrentWord(text, cursor, completion)
end

function TypeBoxTypeCheck.BuildHighlightedText(text: string, cursor: number)
	local parts = {}
	local current = ChatTextUtils.GetCurrentWord(text, cursor)
	local mode = getMode()
	local position = 1

	for word, space in text:gmatch("(%S+)(%s*)") do
		local startPos = position
		local endPos = position + #word - 1
		local isActive = current and cursor > startPos and cursor <= endPos + 1

		local mention = ChatTextUtils.ExtractMention(word)
		if mention then
			parts[#parts + 1] = ChatTextUtils.Font(ChatConfig.mentionWordColor, word, true)

			parts[#parts + 1] = space
			position = endPos + #space + 1
			continue
		end

		if ChatTextUtils.IsPureNumber(word) or text:sub(1, 1) == "/" or not mode.dictionary then
			parts[#parts + 1] = ChatTextUtils.Font(ChatConfig.validWordColor, word)

			parts[#parts + 1] = space
			position = endPos + #space + 1
			continue
		end

		local core = ChatTextUtils.ExtractCoreWord(word:lower())
		if not core then
			parts[#parts + 1] = ChatTextUtils.Font(ChatConfig.invalidWordColor, word)

			parts[#parts + 1] = space
			position = endPos + #space + 1
			continue
		end

		local hasWord = DictionaryUtils.HasWord(core)
		local completion = isActive and mode.ghost and DictionaryUtils.GetCompletion(core)

		if not hasWord and not completion then
			parts[#parts + 1] = ChatTextUtils.Font(ChatConfig.invalidWordColor, word)

			parts[#parts + 1] = space
			position = endPos + #space + 1
			continue
		end

		parts[#parts + 1] = ChatTextUtils.Font(ChatConfig.validWordColor, word)

		if completion and not hasWord then
			local remainder = completion:sub(#core + 1)
			if remainder ~= "" then parts[#parts + 1] = ChatTextUtils.Font(ChatConfig.ghostWordColor, remainder) end
		end

		parts[#parts + 1] = space
		position = endPos + #space + 1
	end

	return table.concat(parts)
end

function TypeBoxTypeCheck.IsMessageValid(text: string): boolean
	local mode = getMode()
	if not mode.dictionary or text:sub(1, 1) == "/" then return true end

	local invalidWord = ChatTypeCheckUtils.MessageHasInvalidWord(text)

	return invalidWord == nil
end

return TypeBoxTypeCheck
