--!strict
--[[
    BotRouteAdvantage (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Predicts the opponent-relative value and interception risk of one planned
    transition without performing world queries inside the route search.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole

export type RResult = {
	advantage: number,
	clearance: number,
	interceptionMargin: number,
	costAdjustment: number,
}

local BotRouteAdvantage = {}

local function horizontal(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function distanceToSegment(position: Vector3, fromPosition: Vector3, toPosition: Vector3): number
	local segment = toPosition - fromPosition
	local lengthSquared = segment:Dot(segment)
	if lengthSquared <= 0.001 then return (position - fromPosition).Magnitude end
	local alpha = math.clamp((position - fromPosition):Dot(segment) / lengthSquared, 0, 1)
	return (position - (fromPosition + segment * alpha)).Magnitude
end

--[=[
	@client

	evaluate
	========

	Returns role-relative advantage in studs. Positive means the transition
	improves the bot's position: a runner gains separation, while a tagger closes
	separation. Clearance and arrival margin expose interception risk separately.
]=]
function BotRouteAdvantage.evaluate(
	role: BotRole,
	fromPosition: Vector3,
	toPosition: Vector3,
	transitionTime: number,
	arrivalTime: number,
	opponentPosition: Vector3?,
	opponentVelocity: Vector3?
): RResult
	if not opponentPosition then
		return {
			advantage = 0,
			clearance = math.huge,
			interceptionMargin = math.huge,
			costAdjustment = 0,
		}
	end

	local flatVelocity = horizontal(opponentVelocity or Vector3.zero)
	local predictionStart = math.min(arrivalTime, Config.routeOpponentPredictionSeconds)
	local predictionEnd = math.min(arrivalTime + transitionTime, Config.routeOpponentPredictionSeconds)
	local predictedStart = opponentPosition + flatVelocity * predictionStart
	local predictedEnd = opponentPosition + flatVelocity * predictionEnd
	local fromFlat = horizontal(fromPosition)
	local toFlat = horizontal(toPosition)
	local startSeparation = (fromFlat - horizontal(predictedStart)).Magnitude
	local endSeparation = (toFlat - horizontal(predictedEnd)).Magnitude
	local advantage = if role == "Runner"
		then endSeparation - startSeparation
		else startSeparation - endSeparation

	local predictedMidpoint = predictedStart:Lerp(predictedEnd, 0.5)
	local midpointClearance = distanceToSegment(
		horizontal(predictedMidpoint),
		fromFlat,
		toFlat
	)
	local clearance = math.min(startSeparation, endSeparation, midpointClearance)
	local opponentSpeed = math.max(flatVelocity.Magnitude, Config.routeOpponentMinimumSpeed)
	local opponentArrivalTime = (toFlat - horizontal(opponentPosition)).Magnitude / opponentSpeed
	local interceptionMargin = opponentArrivalTime - (arrivalTime + transitionTime)
	local costAdjustment = -math.clamp(advantage, -Config.routeAdvantageClamp, Config.routeAdvantageClamp)
		* Config.routeAdvantageCostWeight

	if role == "Runner" then
		local unsafeDistance = math.max(0, Config.runnerRouteSafeClearance - clearance)
		costAdjustment += unsafeDistance * Config.runnerRouteClearanceCostWeight
		if clearance <= Config.tagRange + Config.runnerRouteTagBuffer then
			costAdjustment += Config.runnerRouteInterceptPenalty
		end
		if interceptionMargin < 0 then
			costAdjustment += math.min(
			Config.runnerRouteMaximumMarginPenalty,
			-interceptionMargin * Config.runnerRouteMarginCostWeight
			)
		end
	end

	return {
		advantage = advantage,
		clearance = clearance,
		interceptionMargin = interceptionMargin,
		costAdjustment = costAdjustment,
	}
end

return table.freeze(BotRouteAdvantage)
