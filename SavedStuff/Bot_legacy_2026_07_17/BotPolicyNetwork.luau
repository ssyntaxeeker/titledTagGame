--!strict
--[[
    BotPolicyNetwork (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Tiny linear policy used by the trainer. It behaves like a very small neural
    model: features are multiplied by learned weights, and rewards nudge those
    weights over time without expensive inference.
]]

export type Weights = { [string]: number }
export type Features = { [string]: number }

local BotPolicyNetwork = {}

local LEARNING_RATE = 0.018
local MAX_WEIGHT = 18

local function clampFeature(value: number): number
	return math.clamp(value, -1, 1)
end

function BotPolicyNetwork.featuresForChase(
	botPosition: Vector3,
	targetPosition: Vector3,
	targetVelocity: Vector3,
	previousDistance: number?,
	currentDistance: number,
	floorDelta: number
): Features
	local flatVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)
	local directionToTarget = targetPosition - botPosition
	local flatDirection = Vector3.new(directionToTarget.X, 0, directionToTarget.Z)
	local targetAlignment = if flatVelocity.Magnitude > 0.1 and flatDirection.Magnitude > 0.1
		then flatVelocity.Unit:Dot(flatDirection.Unit)
		else 0
	local distanceGain = if previousDistance then previousDistance - currentDistance else 0

	return {
		bias = 1,
		distanceNear = clampFeature((42 - currentDistance) / 42),
		distanceGain = clampFeature(distanceGain / 18),
		targetSpeed = clampFeature(flatVelocity.Magnitude / 42),
		targetAway = clampFeature(targetAlignment),
		verticalNeed = clampFeature(floorDelta / 16),
	}
end

function BotPolicyNetwork.featuresForTech(botPosition: Vector3, targetPosition: Vector3, floorDelta: number, clearDistance: number?): Features
	local distance = (targetPosition - botPosition).Magnitude
	return {
		bias = 1,
		distance = clampFeature(distance / 90),
		close = clampFeature((36 - distance) / 36),
		verticalNeed = clampFeature(floorDelta / 16),
		blocked = clampFeature(((clearDistance or 10) < 4) and 1 or 0),
		open = clampFeature(((clearDistance or 0) - 4) / 12),
	}
end

function BotPolicyNetwork.score(weights: Weights, actionName: string, features: Features): number
	local score = 0
	for featureName, value in features do
		score += (weights[`{actionName}:{featureName}`] or 0) * value
	end
	return score
end

function BotPolicyNetwork.reward(weights: Weights, actionName: string, features: Features, reward: number, sampleWeight: number?)
	local weightedReward = math.clamp(reward, -24, 24) * math.clamp(sampleWeight or 1, 0.25, 3)
	for featureName, value in features do
		local key = `{actionName}:{featureName}`
		weights[key] = math.clamp((weights[key] or 0) + LEARNING_RATE * weightedReward * value, -MAX_WEIGHT, MAX_WEIGHT)
	end
end

function BotPolicyNetwork.copySanitized(rawWeights: any): Weights
	local weights = {}
	if typeof(rawWeights) ~= "table" then return weights end

	for key, value in rawWeights do
		if typeof(key) == "string" and typeof(value) == "number" then
			weights[string.sub(key, 1, 80)] = math.clamp(value, -MAX_WEIGHT, MAX_WEIGHT)
		end
	end

	return weights
end

return table.freeze(BotPolicyNetwork)
