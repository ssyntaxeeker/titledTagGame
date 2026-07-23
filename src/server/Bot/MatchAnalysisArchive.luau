--!strict
--[[
    MatchAnalysisArchive (Server)
    ====================
    Author: Sol (3693744006)
    Updated: 26/07/21

    Append-only persistence for match-analysis batches. Every authorized batch
    receives its own DataStore key, avoiding growth of one permanently capped
    object while preserving the compact hot index used during live play.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ArchiveStore = DataStoreService:GetDataStore("TitledTagGameMatchAnalysisArchiveV1")
local MAXIMUM_ENCODED_ENTRY_BYTES = 3_500_000
local MAXIMUM_WRITE_ATTEMPTS = 3

local MatchAnalysisArchive = {}

local function archiveKey(mapKey: string, batchId: string): string
	local prefix = string.sub(string.gsub(mapKey, "[^%w]", "_"), 1, 8)
	return `A:{prefix}:{batchId}`
end

--[=[
    @server
    @tag Authoritative
    @yields

    append
    ======

    Writes one immutable observation batch under a unique key. Entries are
    never rotated or deleted by game code. The caller receives failure details
    and must not update its live aggregate unless archival succeeds.

    @return boolean -- Whether the archive entry was persisted.
    @return string -- Entry key on success, or the final error on failure.
]=]
function MatchAnalysisArchive.append(
	mapKey: string,
	batchId: string,
	player: Player,
	batch: { [string]: any }
): (boolean, string)
	assert(#batchId == 36 and string.match(batchId, "^[%x%-]+$") ~= nil, "[MatchAnalysisArchive.append] invalid batchId")
	local entry = {
		version = 1,
		mapKey = mapKey,
		recordedAt = os.time(),
		observerUserId = player.UserId,
		serverJobId = game.JobId,
		batch = batch,
	}
	local encoded = HttpService:JSONEncode(entry)
	if #encoded > MAXIMUM_ENCODED_ENTRY_BYTES then
		return false, `archive entry is {#encoded} bytes and exceeds the safe single-key size`
	end

	local key = archiveKey(mapKey, batchId)
	local lastError = "unknown archive failure"
	for attempt = 1, MAXIMUM_WRITE_ATTEMPTS do
		local success, result = pcall(function()
			ArchiveStore:SetAsync(key, entry)
		end)
		if success then return true, key end
		lastError = tostring(result)
		if attempt < MAXIMUM_WRITE_ATTEMPTS then task.wait(attempt) end
	end
	return false, lastError
end

return table.freeze(MatchAnalysisArchive)
