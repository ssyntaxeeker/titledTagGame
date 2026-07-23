--!strict
--[[
    BotTrainingRecorder (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Records compact state/action/reward samples for offline policy training.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)

local BotTrainingRecorder = {}

export type RTrainingSample = {
	role: string,
	action: string,
	reward: number,
	nodeId: number?,
	targetNodeId: number?,
	features: { number },
	createdAt: number,
}

export type RRecorder = {
	enabled: boolean,
	maxSamples: number,
	samples: { RTrainingSample },
}

function BotTrainingRecorder.create(maxSamples: number?): RRecorder
	return {
		enabled = false,
		maxSamples = maxSamples or Config.policyRecorderMaxSamples,
		samples = {},
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

function BotTrainingRecorder.clear(recorder: RRecorder)
	table.clear(recorder.samples)
end

function BotTrainingRecorder.record(recorder: RRecorder, sample: RTrainingSample)
	if not recorder.enabled then return end
	recorder.samples[#recorder.samples + 1] = sample

	while #recorder.samples > recorder.maxSamples do
		table.remove(recorder.samples, 1)
	end
end

function BotTrainingRecorder.exportJson(recorder: RRecorder): string
	return HttpService:JSONEncode({
		version = 1,
		inputSize = 12,
		samples = recorder.samples,
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
