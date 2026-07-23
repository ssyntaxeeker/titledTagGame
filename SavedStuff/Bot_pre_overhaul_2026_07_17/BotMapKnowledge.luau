--!strict
--[[
    BotMapKnowledge (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Lightweight map perception used to enrich graph nodes with wall, openness,
    verticality, and escape-route facts. This is computed during graph build so
    the runtime does not repeatedly rescan the map while chasing.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)

export type RNodeKnowledge = {
	wallMask: number,
	openDirections: number,
	openness: number,
	nearestWallDistance: number,
	headClearance: number,
	dropHeight: number,
	escapeScore: number,
	climbScore: number,
	rollSetupScore: number,
	isTrampoline: boolean?,
}

local BotMapKnowledge = {}

local DIRECTIONS = table.freeze({
	Vector3.new(1, 0, 0),
	Vector3.new(0.707, 0, 0.707),
	Vector3.new(0, 0, 1),
	Vector3.new(-0.707, 0, 0.707),
	Vector3.new(-1, 0, 0),
	Vector3.new(-0.707, 0, -0.707),
	Vector3.new(0, 0, -1),
	Vector3.new(0.707, 0, -0.707),
})

local function rayDistance(origin: Vector3, direction: Vector3, maxDistance: number, raycastParams: RaycastParams): number
	local result = Workspace:Raycast(origin, direction * maxDistance, raycastParams)
	if not result then return maxDistance end

	return (result.Position - origin).Magnitude
end

function BotMapKnowledge.analyze(position: Vector3, raycastParams: RaycastParams): RNodeKnowledge
	local origin = position + Vector3.yAxis * 1.8
	local wallMask = 0
	local openDirections = 0
	local totalDistance = 0
	local nearestWallDistance = Config.knowledgeWallProbeDistance

	for directionIndex, direction in DIRECTIONS do
		local distance = rayDistance(origin, direction, Config.knowledgeWallProbeDistance, raycastParams)
		totalDistance += distance
		nearestWallDistance = math.min(nearestWallDistance, distance)
		if distance <= Config.wallProbeDistance then
			wallMask += 2 ^ (directionIndex - 1)
		else
			openDirections += 1
		end
	end

	local headClearance = rayDistance(position + Vector3.yAxis * 2, Vector3.yAxis, Config.knowledgeHeadProbeHeight, raycastParams)
	local dropProbeOrigin = position - Vector3.yAxis * 0.2
	local dropResult = Workspace:Raycast(dropProbeOrigin, -Vector3.yAxis * Config.knowledgeDropProbeDepth, raycastParams)
	local dropHeight = if dropResult then math.max(0, dropProbeOrigin.Y - dropResult.Position.Y) else Config.knowledgeDropProbeDepth
	local openness = totalDistance / (#DIRECTIONS * Config.knowledgeWallProbeDistance)
	local escapeScore = openness * 10 + openDirections * 1.4 - math.max(0, Config.wallProbeDistance - nearestWallDistance) * 1.6
	local climbScore = math.max(0, Config.slideBoostMaxWallClearance - nearestWallDistance)
	local rollSetupScore = if dropHeight >= Config.minRollDropHeight then math.min(12, dropHeight) else 0

	return {
		wallMask = wallMask,
		openDirections = openDirections,
		openness = openness,
		nearestWallDistance = nearestWallDistance,
		headClearance = headClearance,
		dropHeight = dropHeight,
		escapeScore = escapeScore,
		climbScore = climbScore,
		rollSetupScore = rollSetupScore,
	}
end

function BotMapKnowledge.wallMaskHasDirection(mask: number, directionIndex: number): boolean
	return bit32.band(mask, 2 ^ (directionIndex - 1)) ~= 0
end

return BotMapKnowledge
