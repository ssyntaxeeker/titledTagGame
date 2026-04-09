local WordList = require(script.Parent.WordList)

-- Trie node structure:
-- {
--   c: { [char] = node },
--   w: boolean
-- }

local TrieRoot = {
	c = {},
	w = false,
}

for _, word in WordList do
	word = string.lower(word)
	local node = TrieRoot

	for i = 1, #word do
		local char = word:sub(i, i)
		node.c[char] = node.c[char] or { c = {}, w = false }
		node = node.c[char]
	end

	node.w = true
end

local DictionaryUtils = {}

function DictionaryUtils.HasWord(word: string): boolean
	word = string.lower(word)
	local node = TrieRoot

	for i = 1, #word do
		local char = word:sub(i, i)
		node = node.c[char]
		if not node then return false end
	end

	return node.w
end

function DictionaryUtils.GetCompletion(prefix: string): string?
	prefix = string.lower(prefix)
	local node = TrieRoot

	for i = 1, #prefix do
		node = node.c[prefix:sub(i, i)]
		if not node then return nil end
	end

	-- stack entries: { node, currentString }
	local stack = { { node, prefix } }

	while #stack > 0 do
		local entry = table.remove(stack)
		local n = entry[1]
		local current = entry[2]

		if n.w then return current end

		for ch, child in n.c do
			stack[#stack + 1] = { child, current .. ch }
		end
	end

	return
end

return DictionaryUtils
