local ChatTextUtils = {}

function ChatTextUtils.Font(color, text, bold)
	if bold then return string.format('<font color="%s"><b>%s</b></font>', color, text) end
	return string.format('<font color="%s">%s</font>', color, text)
end

function ChatTextUtils.GetCurrentWord(text: string, cursor: number)
	local left = text:sub(1, cursor - 1)
	return left:match("(%S+)$")
end

function ChatTextUtils.IsPureNumber(word: string): boolean
	return word:match("^%d+$") ~= nil
end

function ChatTextUtils.ExtractCoreWord(word: string)
	return word:match("^[^%w]*([%a]+)[^%w]*$")
end

function ChatTextUtils.ExtractMention(word: string)
	return word:match("^@([%w_]+)$")
end

function ChatTextUtils.ReplaceCurrentWord(text: string, cursor: number, newWord: string)
	local left = text:sub(1, cursor - 1)
	local right = text:sub(cursor)

	local current = left:match("(%S+)$")
	if not current then return text, cursor end

	local startIndex = #left - #current + 1
	local newText = text:sub(1, startIndex - 1) .. newWord .. right
	return newText, startIndex + #newWord
end

return ChatTextUtils
