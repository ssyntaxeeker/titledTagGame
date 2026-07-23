--!strict
--[[
    BotSkillCalibration (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Geometry-conditioned contextual bandit for continuous skill parameters.
    It selects bounded parameter arms and records outcomes in transferable
    route memory without ever bypassing deterministic movement eligibility.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type RAffordanceEdge = Types.RAffordanceEdge
type RMemory = BotRouteMemory.RMemory

export type RSelection = {
	key: string,
	name: string,
	value: number,
}

local BotSkillCalibration = {}

local function contextKey(edge: RAffordanceEdge, parameterName: string): string
	local contact = edge.setup.contactPosition or edge.setup.approachPosition
	local delta = contact - edge.setup.approachPosition
	local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local heightBand = math.floor(edge.setup.requiredHeight / 1.5 + 0.5)
	local distanceBand = math.floor(flatDistance / 2 + 0.5)
	local speedBand = math.floor(math.abs(edge.setup.requiredSpeed) / 10 + 0.5)
	return `CalibrationV{Config.skillCalibrationRevision}:{edge.action}:{parameterName}:H{heightBand}:D{distanceBand}:S{speedBand}`
end

function BotSkillCalibration.choose(
	memory: RMemory,
	edge: RAffordanceEdge,
	parameterName: string,
	minimum: number,
	maximum: number,
	fallback: number
): RSelection
	assert(maximum >= minimum, "[BotSkillCalibration.choose] invalid parameter range")
	local baseKey = contextKey(edge, parameterName)
	local armCount = Config.skillCalibrationArmCount
	local totalAttempts = 0
	for arm = 1, armCount do
		local stat = BotRouteMemory.getStat(memory, `{baseKey}:A{arm}`)
		if stat then totalAttempts += stat.attempts end
	end

	local bestArm = 1
	local bestValue = math.clamp(fallback, minimum, maximum)
	local bestScore = -math.huge
	for arm = 1, armCount do
		local alpha = if armCount == 1 then 0.5 else (arm - 1) / (armCount - 1)
		local value = minimum + (maximum - minimum) * alpha
		local key = `{baseKey}:A{arm}`
		local stat = BotRouteMemory.getStat(memory, key)
		local attempts = if stat then stat.attempts else 0
		local averageReward = if stat and attempts > 0 then stat.reward / attempts else 0
		local exploration = Config.skillCalibrationExploration
			* math.sqrt(math.log(totalAttempts + armCount + 1) / (attempts + 1))
		local fallbackBias = -math.abs(value - fallback) / math.max(0.001, maximum - minimum)
			* Config.skillCalibrationFallbackBias
		local score = averageReward + exploration + fallbackBias
		if score > bestScore then
			bestScore = score
			bestArm = arm
			bestValue = value
		end
	end
	return { key = `{baseKey}:A{bestArm}`, name = parameterName, value = bestValue }
end

function BotSkillCalibration.chooseBoolean(
	memory: RMemory,
	edge: RAffordanceEdge,
	parameterName: string,
	fallback: boolean
): RSelection
	local baseKey = contextKey(edge, parameterName)
	local totalAttempts = 0
	for arm = 1, 2 do
		local stat = BotRouteMemory.getStat(memory, `{baseKey}:A{arm}`)
		if stat then totalAttempts += stat.attempts end
	end
	local bestArm = if fallback then 2 else 1
	local bestScore = -math.huge
	for arm = 1, 2 do
		local key = `{baseKey}:A{arm}`
		local stat = BotRouteMemory.getStat(memory, key)
		local attempts = if stat then stat.attempts else 0
		local averageReward = if stat and attempts > 0 then stat.reward / attempts else 0
		local exploration = Config.skillCalibrationExploration
			* math.sqrt(math.log(totalAttempts + 3) / (attempts + 1))
		local value = arm - 1
		local fallbackValue = if fallback then 1 else 0
		local fallbackBias = if value == fallbackValue then Config.skillCalibrationFallbackBias else 0
		local score = averageReward + exploration + fallbackBias
		if score > bestScore then
			bestScore = score
			bestArm = arm
		end
	end
	return {
		key = `{baseKey}:A{bestArm}`,
		name = parameterName,
		value = bestArm - 1,
	}
end

function BotSkillCalibration.record(
	memory: RMemory,
	selection: RSelection,
	succeeded: boolean,
	duration: number,
	progressQuality: number?
)
	local reward = (if succeeded then Config.skillCalibrationSuccessReward else -Config.skillCalibrationFailurePenalty)
		- duration * Config.skillCalibrationDurationPenalty
	if not succeeded then reward += math.clamp(progressQuality or 0, 0, 1) * Config.skillCalibrationProgressReward end
	BotRouteMemory.recordStatKey(memory, selection.key, succeeded, reward, duration, selection.value, 1)
end

return table.freeze(BotSkillCalibration)
