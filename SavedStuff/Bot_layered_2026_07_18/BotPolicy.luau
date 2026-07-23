--!strict
--[[
    BotPolicy (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Tiny hot-swappable inference policy used to bias the graph planner. Full
    training happens offline; bounded output-head calibration may run in-game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weights = require(ReplicatedStorage.Modules.Bot.BotPolicyWeights)

local BotPolicy = {}

export type FeatureVector = { number }
export type RLayer = {
	activation: string,
	weights: { { number } },
	bias: { number },
}
export type RModel = {
	version: number,
	inputSize: number,
	actions: { string },
	inputMean: { number },
	inputStd: { number },
	layers: { RLayer },
}

local function cloneModel(source: any): RModel
	local layers: { RLayer } = {}
	for layerIndex, sourceLayer in source.layers do
		local rows: { { number } } = {}
		for rowIndex, sourceRow in sourceLayer.weights do rows[rowIndex] = table.clone(sourceRow) end
		layers[layerIndex] = {
			activation = sourceLayer.activation,
			weights = rows,
			bias = table.clone(sourceLayer.bias),
		}
	end
	return {
		version = source.version,
		inputSize = source.inputSize,
		actions = table.clone(source.actions),
		inputMean = table.clone(source.inputMean),
		inputStd = table.clone(source.inputStd),
		layers = layers,
	}
end

local currentModel = cloneModel(Weights)
local actionIndexes: { [string]: number } = {}
local function rebuildActionIndexes()
	table.clear(actionIndexes)
	for index, actionName in currentModel.actions do actionIndexes[actionName] = index end
end
rebuildActionIndexes()

local function actionScalar(actionName: string): number
	local index = if actionName == "TrussClimb"
		then actionIndexes.TrussClimb or actionIndexes.Vault or 1
		else actionIndexes[actionName] or 1
	return index / math.max(1, #currentModel.actions)
end

function BotPolicy.makeFeatures(
	roleName: string,
	currentNode: any,
	nextNode: any,
	edge: any,
	goalNode: any,
	deadEndPenalty: number,
	areaScore: number,
	speed: number?
): FeatureVector
	local currentPosition = currentNode.position or currentNode.rootPosition
	local nextPosition = nextNode.position or nextNode.rootPosition
	local goalPosition = goalNode.position or goalNode.rootPosition
	local currentGoalDistance = (currentPosition - goalPosition).Magnitude
	local nextGoalDistance = (nextPosition - goalPosition).Magnitude
	local progress = currentGoalDistance - nextGoalDistance
	local heightDelta = nextPosition.Y - currentPosition.Y
	local flatDelta = Vector3.new(nextPosition.X - currentPosition.X, 0, nextPosition.Z - currentPosition.Z).Magnitude
	local roleValue = if roleName == "Runner" or roleName == "Crown" then -1 else 1
	local openDirections = nextNode.openDirections or 0
	local openness = nextNode.openness or openDirections / 4
	local escapeScore = nextNode.escapeScore or openDirections * 2
	local wallPenalty = nextNode.wallPenalty or (if nextNode.isBarrierAdjacent then 10 else math.max(0, 4 - openDirections))

	return {
		roleValue,
		math.clamp(progress / 64, -1, 1),
		math.clamp(heightDelta / 18, -1, 1),
		math.clamp(flatDelta / 32, 0, 1),
		math.clamp(openness, 0, 1),
		math.clamp(escapeScore / 32, -1, 1),
		math.clamp(openDirections / 8, 0, 1),
		math.clamp(wallPenalty / 10, 0, 1),
		math.clamp(deadEndPenalty / 16, 0, 1),
		math.clamp(areaScore / 8, -1, 1),
		math.clamp((speed or 0) / 60, 0, 1),
		actionScalar(edge.action or "Walk"),
	}
end

local function evaluateLayer(inputs: FeatureVector, layer: any): FeatureVector
	local outputs = {}
	for rowIndex, row in layer.weights do
		local value = layer.bias[rowIndex] or 0
		for inputIndex, weight in row do
			value += (inputs[inputIndex] or 0) * weight
		end
		if layer.activation == "relu" and value < 0 then value = 0 end
		outputs[rowIndex] = value
	end
	return outputs
end

local function evaluateAction(features: FeatureVector, actionName: string): number
	local inputs = {}
	for index = 1, currentModel.inputSize do
		local std = currentModel.inputStd[index] or 1
		inputs[index] = ((features[index] or 0) - (currentModel.inputMean[index] or 0)) / math.max(0.0001, std)
	end

	local finalLayerIndex = #currentModel.layers
	for layerIndex = 1, finalLayerIndex - 1 do
		inputs = evaluateLayer(inputs, currentModel.layers[layerIndex])
	end

	local resolvedAction = if actionName == "TrussClimb" and not actionIndexes.TrussClimb
		then "Vault"
		else actionName
	local outputIndex = actionIndexes[resolvedAction] or 1
	local finalLayer = currentModel.layers[finalLayerIndex]
	local row = finalLayer.weights[outputIndex]
	local value = finalLayer.bias[outputIndex] or 0
	for inputIndex, weight in row do value += (inputs[inputIndex] or 0) * weight end
	if finalLayer.activation == "relu" and value < 0 then value = 0 end
	return value
end

function BotPolicy.evaluate(features: FeatureVector): { [string]: number }
	local inputs = {}
	for index = 1, currentModel.inputSize do
		local std = currentModel.inputStd[index] or 1
		inputs[index] = ((features[index] or 0) - (currentModel.inputMean[index] or 0)) / math.max(0.0001, std)
	end

	for _, layer in currentModel.layers do
		inputs = evaluateLayer(inputs, layer)
	end

	local scores = {}
	for index, actionName in currentModel.actions do
		scores[actionName] = inputs[index] or 0
	end
	return scores
end

function BotPolicy.getModel(): RModel
	return cloneModel(currentModel)
end

function BotPolicy.setModel(info: RModel)
	assert(info.inputSize == Weights.inputSize, "[BotPolicy.setModel] input size mismatch")
	assert(#info.actions == #Weights.actions, "[BotPolicy.setModel] action count mismatch")
	assert(#info.layers == #Weights.layers, "[BotPolicy.setModel] layer count mismatch")
	for index, actionName in Weights.actions do
		assert(info.actions[index] == actionName, "[BotPolicy.setModel] action ordering mismatch")
	end
	for layerIndex, layer in info.layers do
		local expectedLayer = Weights.layers[layerIndex]
		assert(#layer.weights == #expectedLayer.weights, "[BotPolicy.setModel] output count mismatch")
		assert(#layer.bias == #expectedLayer.bias, "[BotPolicy.setModel] bias count mismatch")
		for rowIndex, row in layer.weights do
			assert(#row == #expectedLayer.weights[rowIndex], "[BotPolicy.setModel] layer width mismatch")
			for _, value in row do
				assert(value == value and math.abs(value) <= 100, "[BotPolicy.setModel] invalid weight")
			end
			local bias = layer.bias[rowIndex]
			assert(bias == bias and math.abs(bias) <= 100, "[BotPolicy.setModel] invalid bias")
		end
	end
	currentModel = cloneModel(info)
	rebuildActionIndexes()
end

function BotPolicy.scoreAction(actionName: string, scores: { [string]: number }): number
	local score = if actionName == "TrussClimb" then scores.TrussClimb or scores.Vault else scores[actionName]
	return math.clamp(score or 0, -8, 8)
end

function BotPolicy.scoreEdge(
	roleName: string,
	currentNode: any,
	nextNode: any,
	edge: any,
	goalNode: any,
	deadEndPenalty: number,
	areaScore: number,
	speed: number?
): number
	local features = BotPolicy.makeFeatures(roleName, currentNode, nextNode, edge, goalNode, deadEndPenalty, areaScore, speed)
	return math.clamp(evaluateAction(features, edge.action or "Walk"), -8, 8)
end

return BotPolicy
