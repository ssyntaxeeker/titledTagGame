--!strict
--[[
    BotPolicy (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Tiny inference-only policy used to bias the graph planner. Heavy training
    happens offline and exports BotPolicyWeights.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weights = require(ReplicatedStorage.Modules.Bot.BotPolicyWeights)

local BotPolicy = {}

export type FeatureVector = { number }

local actionIndexes: { [string]: number } = {}
for index, actionName in Weights.actions do
	actionIndexes[actionName] = index
end

local function actionScalar(actionName: string): number
	local index = actionIndexes[actionName] or 1
	return index / math.max(1, #Weights.actions)
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
	local currentGoalDistance = (currentNode.position - goalNode.position).Magnitude
	local nextGoalDistance = (nextNode.position - goalNode.position).Magnitude
	local progress = currentGoalDistance - nextGoalDistance
	local heightDelta = nextNode.position.Y - currentNode.position.Y
	local flatDelta = Vector3.new(nextNode.position.X - currentNode.position.X, 0, nextNode.position.Z - currentNode.position.Z).Magnitude
	local roleValue = if roleName == "Runner" or roleName == "Crown" then -1 else 1

	return {
		roleValue,
		math.clamp(progress / 64, -1, 1),
		math.clamp(heightDelta / 18, -1, 1),
		math.clamp(flatDelta / 32, 0, 1),
		math.clamp((nextNode.openness or 0), 0, 1),
		math.clamp((nextNode.escapeScore or 0) / 32, -1, 1),
		math.clamp((nextNode.openDirections or 0) / 8, 0, 1),
		math.clamp((nextNode.wallPenalty or 0) / 10, 0, 1),
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

function BotPolicy.evaluate(features: FeatureVector): { [string]: number }
	local inputs = {}
	for index = 1, Weights.inputSize do
		local std = Weights.inputStd[index] or 1
		inputs[index] = ((features[index] or 0) - (Weights.inputMean[index] or 0)) / math.max(0.0001, std)
	end

	for _, layer in Weights.layers do
		inputs = evaluateLayer(inputs, layer)
	end

	local scores = {}
	for index, actionName in Weights.actions do
		scores[actionName] = inputs[index] or 0
	end
	return scores
end

function BotPolicy.scoreAction(actionName: string, scores: { [string]: number }): number
	return math.clamp(scores[actionName] or 0, -8, 8)
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
	local scores = BotPolicy.evaluate(features)
	return BotPolicy.scoreAction(edge.action or "Walk", scores)
end

return BotPolicy
