--!strict
--[[
    BotOnlinePolicyTrainer (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Frame-budgeted output-head calibration for the tiny route policy. It keeps
    the offline-learned representation fixed and accepts a candidate only when
    weighted loss improves on samples excluded from calibration.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotPolicy = require(ReplicatedStorage.Modules.Bot.BotPolicy)
local BotTrainingRecorder = require(ReplicatedStorage.Modules.Bot.BotTrainingRecorder)

type RModel = BotPolicy.RModel
type RTrainingSample = BotTrainingRecorder.RTrainingSample

export type RJob = {
	model: RModel,
	samples: { RTrainingSample },
	trainingIndexes: { number },
	validationIndexes: { number },
	actionIndexes: { [string]: number },
	actionCounts: { [string]: number },
	phase: string,
	cursor: number,
	epoch: number,
	baselineLoss: number,
	validationLoss: number,
	lossSum: number,
	weightSum: number,
	accepted: boolean,
	processed: number,
}

local BotOnlinePolicyTrainer = {}

local function hiddenFeatures(model: RModel, features: { number }): { number }
	local inputs: { number } = {}
	for index = 1, model.inputSize do
		inputs[index] = ((features[index] or 0) - (model.inputMean[index] or 0))
			/ math.max(0.0001, model.inputStd[index] or 1)
	end
	for layerIndex = 1, #model.layers - 1 do
		local layer = model.layers[layerIndex]
		local outputs: { number } = {}
		for rowIndex, row in layer.weights do
			local value = layer.bias[rowIndex] or 0
			for inputIndex, weight in row do value += (inputs[inputIndex] or 0) * weight end
			outputs[rowIndex] = if layer.activation == "relu" then math.max(0, value) else value
		end
		inputs = outputs
	end
	return inputs
end

local function sampleWeight(job: RJob, sample: RTrainingSample): number
	local actionCount = job.actionCounts[sample.action] or 1
	local classCount = 0
	for _ in job.actionCounts do classCount += 1 end
	local classWeight = math.sqrt(#job.samples / math.max(1, classCount * actionCount))
	return math.clamp(sample.weight or 1, 0.1, 3) * math.clamp(classWeight, 0.4, 3)
end

local function prediction(job: RJob, sample: RTrainingSample): (number, { number }, number)
	local hidden = hiddenFeatures(job.model, sample.features)
	local actionIndex = job.actionIndexes[sample.action]
	assert(actionIndex, "[BotOnlinePolicyTrainer.prediction] sample has unsupported action")
	local outputLayer = job.model.layers[#job.model.layers]
	local value = outputLayer.bias[actionIndex] or 0
	for hiddenIndex, weight in outputLayer.weights[actionIndex] do
		value += (hidden[hiddenIndex] or 0) * weight
	end
	return value, hidden, actionIndex
end

local function evaluateOne(job: RJob, sampleIndex: number)
	local sample = job.samples[sampleIndex]
	local value = prediction(job, sample)
	local errorValue = value - math.clamp(sample.reward, -8, 8)
	local weight = sampleWeight(job, sample)
	job.lossSum += errorValue * errorValue * weight
	job.weightSum += weight
	job.processed += 1
end

local function trainOne(job: RJob, sampleIndex: number)
	local sample = job.samples[sampleIndex]
	local value, hidden, actionIndex = prediction(job, sample)
	local outputLayer = job.model.layers[#job.model.layers]
	local target = math.clamp(sample.reward, -8, 8)
	local gradient = math.clamp(2 * (value - target) * sampleWeight(job, sample), -8, 8)
	local row = outputLayer.weights[actionIndex]
	for hiddenIndex, hiddenValue in hidden do
		local weight = row[hiddenIndex]
		row[hiddenIndex] = weight - Config.onlinePolicyLearningRate
			* (gradient * hiddenValue + Config.onlinePolicyWeightDecay * weight)
	end
	outputLayer.bias[actionIndex] -= Config.onlinePolicyLearningRate * gradient
	job.processed += 1
end

function BotOnlinePolicyTrainer.create(samples: { RTrainingSample }): RJob
	assert(#samples >= Config.onlinePolicyMinimumSamples, "[BotOnlinePolicyTrainer.create] insufficient samples")
	local model = BotPolicy.getModel()
	local actionIndexes: { [string]: number } = {}
	for index, actionName in model.actions do actionIndexes[actionName] = index end
	local validSamples: { RTrainingSample } = {}
	local actionCounts: { [string]: number } = {}
	for _, sample in samples do
		if not actionIndexes[sample.action] or #sample.features ~= model.inputSize then continue end
		validSamples[#validSamples + 1] = sample
		actionCounts[sample.action] = (actionCounts[sample.action] or 0) + 1
	end
	assert(#validSamples >= Config.onlinePolicyMinimumSamples, "[BotOnlinePolicyTrainer.create] insufficient valid samples")
	local representedActions = 0
	for _ in actionCounts do representedActions += 1 end
	assert(representedActions >= 2, "[BotOnlinePolicyTrainer.create] at least two actions are required")

	local trainingIndexes: { number } = {}
	local validationIndexes: { number } = {}
	for index = 1, #validSamples do
		if index % Config.onlinePolicyValidationStride == 0 then
			validationIndexes[#validationIndexes + 1] = index
		else
			trainingIndexes[#trainingIndexes + 1] = index
		end
	end
	assert(#validationIndexes > 0, "[BotOnlinePolicyTrainer.create] validation split is empty")
	local random = Random.new(#validSamples * 7919)
	for index = #trainingIndexes, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		trainingIndexes[index], trainingIndexes[swapIndex] = trainingIndexes[swapIndex], trainingIndexes[index]
	end

	return {
		model = model,
		samples = validSamples,
		trainingIndexes = trainingIndexes,
		validationIndexes = validationIndexes,
		actionIndexes = actionIndexes,
		actionCounts = actionCounts,
		phase = "Baseline",
		cursor = 1,
		epoch = 1,
		baselineLoss = math.huge,
		validationLoss = math.huge,
		lossSum = 0,
		weightSum = 0,
		accepted = false,
		processed = 0,
	}
end

--[=[
	@client

	step
	====

	Consumes at most the supplied wall-clock budget. Returns true only after the
	validation phase has decided whether the candidate is safe to install.
]=]
function BotOnlinePolicyTrainer.step(job: RJob, budgetSeconds: number): boolean
	if job.phase == "Done" then return true end
	local deadline = os.clock() + math.max(0.0001, budgetSeconds)
	while os.clock() < deadline do
		if job.phase == "Baseline" then
			evaluateOne(job, job.validationIndexes[job.cursor])
			job.cursor += 1
			if job.cursor > #job.validationIndexes then
				job.baselineLoss = job.lossSum / math.max(0.0001, job.weightSum)
				job.lossSum = 0
				job.weightSum = 0
				job.cursor = 1
				job.phase = "Training"
			end
		elseif job.phase == "Training" then
			trainOne(job, job.trainingIndexes[job.cursor])
			job.cursor += 1
			if job.cursor > #job.trainingIndexes then
				job.cursor = 1
				job.epoch += 1
				if job.epoch > Config.onlinePolicyEpochs then job.phase = "Validation" end
			end
		elseif job.phase == "Validation" then
			evaluateOne(job, job.validationIndexes[job.cursor])
			job.cursor += 1
			if job.cursor > #job.validationIndexes then
				job.validationLoss = job.lossSum / math.max(0.0001, job.weightSum)
				job.accepted = job.validationLoss
					<= job.baselineLoss * (1 - Config.onlinePolicyMinimumImprovement)
				job.model.version += 1
				job.phase = "Done"
				return true
			end
		end
	end
	return false
end

function BotOnlinePolicyTrainer.getProgress(job: RJob): string
	if job.phase == "Training" then
		return `training epoch {math.min(job.epoch, Config.onlinePolicyEpochs)}/{Config.onlinePolicyEpochs}`
	end
	if job.phase == "Done" then
		return if job.accepted
			then `accepted {job.baselineLoss - job.validationLoss} loss improvement`
			else `rejected: validation {job.validationLoss}, baseline {job.baselineLoss}`
	end
	return string.lower(job.phase)
end

return table.freeze(BotOnlinePolicyTrainer)
