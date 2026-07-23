--!strict
--[[
    BotTrainingRecorder (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Records compact state/action/reward samples for offline policy training.
    A fixed-size ring overwrites the oldest sample without shifting the array.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)

local BotTrainingRecorder = {}

export type RTrainingSample = {
	role: string,
	action: string,
	reward: number,
	nodeId: number?,
	targetNodeId: number?,
	features: { number },
	createdAt: number,
	weight: number?,
	mapName: string?,
	source: string?,
}

export type RRecorder = {
	enabled: boolean,
	maxSamples: number,
	samples: { RTrainingSample },
	actionCounts: { [string]: number },
	sourceCounts: { [string]: number },
	writeIndex: number,
}

function BotTrainingRecorder.create(maxSamples: number?): RRecorder
	local capacity = math.max(1, math.floor(maxSamples or Config.policyRecorderMaxSamples))
	return {
		enabled = false,
		maxSamples = capacity,
		samples = {},
		actionCounts = {},
		sourceCounts = {},
		writeIndex = 1,
	}
end

function BotTrainingRecorder.setEnabled(recorder: RRecorder, enabled: boolean)
	recorder.enabled = enabled
end

function BotTrainingRecorder.isEnabled(recorder: RRecorder): boolean
	return recorder.enabled
end

function BotTrainingRecorder.count(recorder: RRecorder): number
	return #recorder.samples
end

function BotTrainingRecorder.getActionSummary(recorder: RRecorder): string
	local actions: { string } = {}
	for action in recorder.actionCounts do actions[#actions + 1] = action end
	table.sort(actions)
	local parts: { string } = {}
	for _, action in actions do parts[#parts + 1] = `{action} {recorder.actionCounts[action]}` end
	return if #parts > 0 then table.concat(parts, ", ") else "none"
end

function BotTrainingRecorder.getSourceSummary(recorder: RRecorder): string
	local sources: { string } = {}
	for source in recorder.sourceCounts do
		if typeof(source) == "string" then sources[#sources + 1] = source end
	end
	table.sort(sources)
	local parts: { string } = {}
	for _, source in sources do parts[#parts + 1] = `{source} {recorder.sourceCounts[source]}` end
	return if #parts > 0 then table.concat(parts, ", ") else "none"
end

function BotTrainingRecorder.clear(recorder: RRecorder)
	table.clear(recorder.samples)
	table.clear(recorder.actionCounts)
	table.clear(recorder.sourceCounts)
	recorder.writeIndex = 1
end

function BotTrainingRecorder.record(recorder: RRecorder, sample: RTrainingSample)
	if not recorder.enabled then return end
	if sample.action == "Walk" and #recorder.samples >= Config.policyWalkAdmissionWarmup then
		local walkFraction = (recorder.actionCounts.Walk or 0) / math.max(1, #recorder.samples)
		if walkFraction >= Config.policyMaximumWalkFraction then return end
	end
	local removed: RTrainingSample? = nil
	if #recorder.samples < recorder.maxSamples then
		recorder.samples[#recorder.samples + 1] = sample
		if #recorder.samples == recorder.maxSamples then recorder.writeIndex = 1 end
	else
		removed = recorder.samples[recorder.writeIndex]
		recorder.samples[recorder.writeIndex] = sample
		recorder.writeIndex = recorder.writeIndex % recorder.maxSamples + 1
	end
	recorder.actionCounts[sample.action] = (recorder.actionCounts[sample.action] or 0) + 1
	local source = if typeof(sample.source) == "string" then sample.source else "Unknown"
	sample.source = source
	recorder.sourceCounts[source] = (recorder.sourceCounts[source] or 0) + 1

	if removed then
		local remaining = (recorder.actionCounts[removed.action] or 1) - 1
		if remaining > 0 then
			recorder.actionCounts[removed.action] = remaining
		else
			recorder.actionCounts[removed.action] = nil
		end
		local removedSource = if typeof(removed.source) == "string" then removed.source else "Unknown"
		local remainingSourceCount = (recorder.sourceCounts[removedSource] or 1) - 1
		if remainingSourceCount > 0 then
			recorder.sourceCounts[removedSource] = remainingSourceCount
		else
			recorder.sourceCounts[removedSource] = nil
		end
	end
end

function BotTrainingRecorder.exportJson(recorder: RRecorder): string
	local orderedSamples: { RTrainingSample } = {}
	local count = #recorder.samples
	if count < recorder.maxSamples then
		for index = 1, count do
			local sample = recorder.samples[index]
			if typeof(sample.source) ~= "string" then sample.source = "Unknown" end
			orderedSamples[index] = sample
		end
	else
		for offset = 0, count - 1 do
			local sourceIndex = (recorder.writeIndex + offset - 1) % count + 1
			local sample = recorder.samples[sourceIndex]
			if typeof(sample.source) ~= "string" then sample.source = "Unknown" end
			orderedSamples[offset + 1] = sample
		end
	end
	return HttpService:JSONEncode({
		version = 2,
		inputSize = 12,
		samples = orderedSamples,
	})
end

function BotTrainingRecorder.printJsonChunks(recorder: RRecorder, label: string?)
	local payload = BotTrainingRecorder.exportJson(recorder)
	local chunkSize = Config.policyExportChunkSize
	local chunkCount = math.ceil(#payload / chunkSize)
	local exportLabel = label or "BotPolicySamples"

	for chunkIndex = 1, chunkCount do
		local startIndex = (chunkIndex - 1) * chunkSize + 1
		local endIndex = math.min(#payload, chunkIndex * chunkSize)
		print(`[{exportLabel} {chunkIndex}/{chunkCount}] {string.sub(payload, startIndex, endIndex)}`)
	end
end

return BotTrainingRecorder
