--!strict
--[[
    BotRouteMemory (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Compact local and geometry-generalized statistics for affordance success,
    timing, dead ends, and tactical outcomes. General keys transfer learned
    skill behavior between maps without replacing useful local route evidence.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type RAffordanceEdge = Types.RAffordanceEdge
type BotRole = Types.BotRole

export type RStat = {
	attempts: number,
	successes: number,
	reward: number,
	meanDuration: number,
	meanTiming: number,
}

export type RMemory = {
	edges: { [string]: RStat },
	areas: { [string]: number },
	playerRoutes: { [string]: number },
	evidenceCount: number,
	dirty: boolean,
}

local BotRouteMemory = {}

local function actionRevision(action: Types.ActionKind): string
	if action == "Vault" or action == "HighVault" then return "V2:" end
	return if action == "SlideBoost" then "S4:" else ""
end

local function quantized(position: Vector3, step: number): string
	return `{math.floor(position.X / step + 0.5)}:{math.floor(position.Y / step + 0.5)}:{math.floor(position.Z / step + 0.5)}`
end

local function edgeKeys(edge: RAffordanceEdge): { edge: string, areaAction: string, general: string }
	if edge.memoryKeys then return edge.memoryKeys end

	local revision = actionRevision(edge.action)
	local contact = edge.setup.contactPosition or edge.setup.approachPosition
	local delta = contact - edge.setup.approachPosition
	local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local heightBand = math.floor(edge.setup.requiredHeight * 2 + 0.5) / 2
	local distanceBand = math.floor(flatDistance / 2 + 0.5) * 2
	local speedBand = math.floor(edge.setup.requiredSpeed / 5 + 0.5) * 5
	local keys = {
		edge = `{revision}{edge.action}:{quantized(edge.setup.approachPosition, 4)}>{quantized(contact, 4)}`,
		areaAction = `{revision}LocalAction:{edge.action}:{quantized(edge.setup.approachPosition, 8)}`,
		general = `{revision}General:{edge.action}:H{heightBand}:D{distanceBand}:S{speedBand}`,
	}
	edge.memoryKeys = keys
	return keys
end

function BotRouteMemory.create(): RMemory
	return { edges = {}, areas = {}, playerRoutes = {}, evidenceCount = 0, dirty = false }
end

function BotRouteMemory.edgeKey(edge: RAffordanceEdge): string
	return edgeKeys(edge).edge
end

function BotRouteMemory.areaActionKey(edge: RAffordanceEdge): string
	return edgeKeys(edge).areaAction
end

function BotRouteMemory.generalEdgeKey(edge: RAffordanceEdge): string
	return edgeKeys(edge).general
end

function BotRouteMemory.areaKey(position: Vector3): string
	return quantized(position, 16)
end

function BotRouteMemory.getSuccessProbability(memory: RMemory, edge: RAffordanceEdge): number
	local localStat = memory.edges[BotRouteMemory.edgeKey(edge)]
	local areaActionStat = memory.edges[BotRouteMemory.areaActionKey(edge)]
	local generalStat = memory.edges[BotRouteMemory.generalEdgeKey(edge)]
	local probability = edge.successProbability
	if generalStat and generalStat.attempts >= 2 then
		local learned = (generalStat.successes + 1) / (generalStat.attempts + 2)
		probability = probability * 0.55 + learned * 0.45
	end
	if areaActionStat and areaActionStat.attempts >= 2 then
		local learned = (areaActionStat.successes + 1) / (areaActionStat.attempts + 2)
		probability = probability * 0.45 + learned * 0.55
	end
	if localStat and localStat.attempts >= 2 then
		local learned = (localStat.successes + 1) / (localStat.attempts + 2)
		probability = probability * 0.4 + learned * 0.6
	end
	return math.clamp(probability, 0.08, 0.99)
end

function BotRouteMemory.getCostBias(memory: RMemory, edge: RAffordanceEdge): number
	local localStat = memory.edges[BotRouteMemory.edgeKey(edge)]
	local areaActionStat = memory.edges[BotRouteMemory.areaActionKey(edge)]
	local generalStat = memory.edges[BotRouteMemory.generalEdgeKey(edge)]
	local bias = 0
	if generalStat and generalStat.attempts > 0 then bias -= generalStat.reward / generalStat.attempts * 0.025 end
	if areaActionStat and areaActionStat.attempts > 0 then
		bias -= areaActionStat.reward / areaActionStat.attempts * 0.032
	end
	if localStat and localStat.attempts > 0 then bias -= localStat.reward / localStat.attempts * 0.04 end
	return math.clamp(bias, -0.6, 1.8)
end

function BotRouteMemory.getTiming(memory: RMemory, edge: RAffordanceEdge, fallback: number): number
	local localStat = memory.edges[BotRouteMemory.edgeKey(edge)]
	local generalStat = memory.edges[BotRouteMemory.generalEdgeKey(edge)]
	local stat = if localStat and localStat.successes > 0
		then localStat
		elseif generalStat
		then generalStat
		else localStat
	if not stat then return math.clamp(fallback, edge.setup.timingMin, edge.setup.timingMax) end
	if stat.successes <= 0 then
		local offsets = { 0, -0.06, 0.06 }
		local offset = offsets[stat.attempts % #offsets + 1]
		return math.clamp(fallback + offset, edge.setup.timingMin, edge.setup.timingMax)
	end
	return math.clamp(stat.meanTiming, edge.setup.timingMin, edge.setup.timingMax)
end

function BotRouteMemory.getExperienceCount(memory: RMemory, edge: RAffordanceEdge): number
	local localStat = memory.edges[BotRouteMemory.edgeKey(edge)]
	return if localStat then localStat.attempts else 0
end

function BotRouteMemory.getStat(memory: RMemory, key: string): RStat?
	return memory.edges[key]
end

local function recordStat(
	stat: RStat,
	succeeded: boolean,
	reward: number,
	duration: number,
	timing: number?,
	weight: number
)
	stat.attempts += weight
	if succeeded then stat.successes += weight end
	stat.reward = math.clamp(stat.reward + reward * weight, -500, 500)
	stat.meanDuration += (duration - stat.meanDuration) * weight / stat.attempts
	if succeeded and timing then
		stat.meanTiming += (timing - stat.meanTiming) * weight / math.max(weight, stat.successes)
	end
end

function BotRouteMemory.recordStatKey(
	memory: RMemory,
	key: string,
	succeeded: boolean,
	reward: number,
	duration: number,
	timing: number?,
	weight: number
)
	local stat = memory.edges[key]
	if not stat then
		stat = { attempts = 0, successes = 0, reward = 0, meanDuration = 0, meanTiming = 0 }
		memory.edges[key] = stat
	end
	recordStat(stat, succeeded, reward, duration, timing, math.clamp(weight, 0.25, 8))
	memory.evidenceCount += weight
	memory.dirty = true
end

function BotRouteMemory.recordEdge(
	memory: RMemory,
	edge: RAffordanceEdge,
	succeeded: boolean,
	reward: number,
	duration: number,
	timing: number?,
	weight: number?
)
	local sampleWeight = math.clamp(weight or 1, 0.25, 8)
	local keys = {
		BotRouteMemory.edgeKey(edge),
		BotRouteMemory.areaActionKey(edge),
		BotRouteMemory.generalEdgeKey(edge),
	}
	for _, key in keys do
		local stat = memory.edges[key]
		if not stat then
			stat = { attempts = 0, successes = 0, reward = 0, meanDuration = 0, meanTiming = 0 }
			memory.edges[key] = stat
		end
		recordStat(stat, succeeded, reward, duration, timing, sampleWeight)
	end
	memory.evidenceCount += sampleWeight
	memory.dirty = true
end

function BotRouteMemory.getPlayerReliance(memory: RMemory): number
	local missingEvidence = 1 - math.clamp(memory.evidenceCount / Config.playerEvidenceForFullConfidence, 0, 1)
	return Config.playerRelianceFloor + (1 - Config.playerRelianceFloor) * missingEvidence
end

function BotRouteMemory.recordArea(memory: RMemory, position: Vector3, reward: number, role: BotRole?)
	local areaKey = BotRouteMemory.areaKey(position)
	local key = if role then `{role}:{areaKey}` else areaKey
	memory.areas[key] = math.clamp((memory.areas[key] or 0) + reward, -100, 100)
	memory.dirty = true
end

function BotRouteMemory.getAreaScore(memory: RMemory, position: Vector3, role: BotRole?): number
	local areaKey = BotRouteMemory.areaKey(position)
	if role then
		local roleScore = memory.areas[`{role}:{areaKey}`]
		if roleScore then return roleScore end
	end
	return memory.areas[areaKey] or 0
end

function BotRouteMemory.recoverySlideKey(position: Vector3, direction: Vector3): string
	local directionKey = `{math.floor(direction.X * 4 + 0.5)}:{math.floor(direction.Z * 4 + 0.5)}`
	return `RecoverySlide:{quantized(position, 4)}:{directionKey}`
end

function BotRouteMemory.shouldTryRecoverySlide(memory: RMemory, key: string): boolean
	local stat = memory.edges[key]
	if not stat then return true end
	return stat.successes > 0 or stat.attempts < Config.escapeSlideMaxFailedAttempts
end

function BotRouteMemory.getRecoverySlideScore(memory: RMemory, key: string): number
	local stat = memory.edges[key]
	if not stat or stat.attempts == 0 then return 0 end
	return stat.successes / stat.attempts * 4 + stat.reward / stat.attempts * 0.25
end

function BotRouteMemory.recordRecoverySlide(memory: RMemory, key: string, succeeded: boolean, displacement: number)
	local stat = memory.edges[key]
	if not stat then
		stat = { attempts = 0, successes = 0, reward = 0, meanDuration = 0, meanTiming = 0 }
		memory.edges[key] = stat
	end
	stat.attempts += 1
	if succeeded then stat.successes += 1 end
	local reward = if succeeded then displacement else -3
	stat.reward = math.clamp(stat.reward + reward, -500, 500)
	stat.meanDuration += (Config.escapeSlideDurationSeconds - stat.meanDuration) / stat.attempts
	memory.dirty = true
end

local function playerTransitionBaseKey(fromPosition: Vector3, toPosition: Vector3): string
	local mapName = string.sub(tostring(Workspace:GetAttribute("Map") or "Unknown"), 1, 24)
	return `{mapName}:{quantized(fromPosition, Config.playerRoutePositionStep)}>{quantized(toPosition, Config.playerRoutePositionStep)}`
end

local function taughtTransitionBaseKey(
	edge: RAffordanceEdge,
	fromPosition: Vector3,
	toPosition: Vector3
): string
	local cached = edge.taughtTransitionBaseKey
	if cached then return cached end
	local mapName = string.sub(tostring(Workspace:GetAttribute("Map") or "Unknown"), 1, 24)
	cached = `{mapName}:{edge.action}:{quantized(fromPosition, Config.playerRoutePositionStep)}>{quantized(toPosition, Config.playerRoutePositionStep)}`
	edge.taughtTransitionBaseKey = cached
	return cached
end

function BotRouteMemory.playerTransitionKey(fromPosition: Vector3, toPosition: Vector3): string
	return `PR2:{playerTransitionBaseKey(fromPosition, toPosition)}`
end

function BotRouteMemory.recordPlayerTransition(
	memory: RMemory,
	fromPosition: Vector3,
	toPosition: Vector3,
	duration: number,
	weight: number
)
	local baseKey = playerTransitionBaseKey(fromPosition, toPosition)
	local evidenceKey = `PR2:{baseKey}`
	local durationKey = `PT2:{baseKey}`
	memory.playerRoutes[evidenceKey] = math.clamp((memory.playerRoutes[evidenceKey] or 0) + weight, 0, 500)
	memory.playerRoutes[durationKey] = math.clamp(
		(memory.playerRoutes[durationKey] or 0) + math.max(0.01, duration) * weight,
		0,
		500
	)
	memory.dirty = true
end

function BotRouteMemory.getPlayerTransitionScore(memory: RMemory, fromPosition: Vector3, toPosition: Vector3): number
	return memory.playerRoutes[BotRouteMemory.playerTransitionKey(fromPosition, toPosition)] or 0
end

function BotRouteMemory.getPlayerTransitionTime(
	memory: RMemory,
	fromPosition: Vector3,
	toPosition: Vector3
): (number?, number)
	local baseKey = playerTransitionBaseKey(fromPosition, toPosition)
	local evidence = memory.playerRoutes[`PR2:{baseKey}`] or 0
	if evidence <= 0 then return nil, 0 end
	local durationSum = memory.playerRoutes[`PT2:{baseKey}`] or 0
	return durationSum / evidence, evidence
end

function BotRouteMemory.getPlayerEdgeTransitionTime(
	memory: RMemory,
	edge: RAffordanceEdge,
	fromPosition: Vector3,
	toPosition: Vector3
): (number?, number)
	local baseKey = edge.playerTransitionBaseKey
	if not baseKey then
		baseKey = playerTransitionBaseKey(fromPosition, toPosition)
		edge.playerTransitionBaseKey = baseKey
	end
	local evidence = memory.playerRoutes[`PR2:{baseKey}`] or 0
	if evidence <= 0 then return nil, 0 end
	local durationSum = memory.playerRoutes[`PT2:{baseKey}`] or 0
	return durationSum / evidence, evidence
end

function BotRouteMemory.recordTaughtTransition(
	memory: RMemory,
	edge: RAffordanceEdge,
	fromPosition: Vector3,
	toPosition: Vector3,
	duration: number,
	weight: number
)
	local baseKey = taughtTransitionBaseKey(edge, fromPosition, toPosition)
	local sampleWeight = math.clamp(weight, 1, 20)
	memory.playerRoutes[`TR3:{baseKey}`] = math.clamp(
		(memory.playerRoutes[`TR3:{baseKey}`] or 0) + sampleWeight,
		0,
		500
	)
	memory.playerRoutes[`TT3:{baseKey}`] = math.clamp(
		(memory.playerRoutes[`TT3:{baseKey}`] or 0) + math.max(0.01, duration) * sampleWeight,
		0,
		500
	)
	memory.dirty = true
end

function BotRouteMemory.getTaughtTransition(
	memory: RMemory,
	edge: RAffordanceEdge,
	fromPosition: Vector3,
	toPosition: Vector3
): (number?, number)
	local baseKey = taughtTransitionBaseKey(edge, fromPosition, toPosition)
	local evidence = memory.playerRoutes[`TR3:{baseKey}`] or 0
	if evidence <= 0 then return nil, 0 end
	local durationSum = memory.playerRoutes[`TT3:{baseKey}`] or 0
	return durationSum / evidence, evidence
end

return table.freeze(BotRouteMemory)
