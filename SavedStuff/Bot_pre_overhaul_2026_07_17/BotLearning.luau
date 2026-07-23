--!strict
--[[
    BotLearning (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Tiny statistical memory. This learns success rates and costs without doing
    expensive neural training on the render client.
]]

local BotLearning = {}

export type RLearningMemory = {
	edgeScores: { [string]: number },
	edgeAttempts: { [string]: number },
	techScores: { [string]: number },
	techAttempts: { [string]: number },
	deadEndScores: { [string]: number },
	areaScores: { [string]: number },
	areaAttempts: { [string]: number },
	playerRouteScores: { [string]: number },
}

function BotLearning.createMemory(): RLearningMemory
	return {
		edgeScores = {},
		edgeAttempts = {},
		techScores = {},
		techAttempts = {},
		deadEndScores = {},
		areaScores = {},
		areaAttempts = {},
		playerRouteScores = {},
	}
end

function BotLearning.edgeKey(fromId: number, toId: number): string
	return `{fromId}>{toId}`
end

function BotLearning.techKey(position: Vector3, actionName: string): string
	return `{actionName}:{math.floor(position.X / 4 + 0.5)}:{math.floor(position.Y / 4 + 0.5)}:{math.floor(position.Z / 4 + 0.5)}`
end

function BotLearning.getEdgeMultiplier(memory: RLearningMemory, fromId: number, toId: number): number
	local key = BotLearning.edgeKey(fromId, toId)
	local attempts = memory.edgeAttempts[key] or 0
	if attempts <= 0 then return 1 end

	local score = memory.edgeScores[key] or 0
	return math.clamp(1 - score / math.max(8, attempts) * 0.35, 0.65, 1.65)
end

function BotLearning.recordEdge(memory: RLearningMemory, fromId: number, toId: number, reward: number)
	local key = BotLearning.edgeKey(fromId, toId)
	memory.edgeAttempts[key] = (memory.edgeAttempts[key] or 0) + 1
	memory.edgeScores[key] = math.clamp((memory.edgeScores[key] or 0) + reward, -50, 50)
end

function BotLearning.getTechScore(memory: RLearningMemory, position: Vector3, actionName: string): number
	local key = BotLearning.techKey(position, actionName)
	local attempts = memory.techAttempts[key] or 0
	if attempts <= 0 then return 0 end

	return (memory.techScores[key] or 0) / attempts
end

function BotLearning.recordTech(memory: RLearningMemory, position: Vector3, actionName: string, reward: number)
	local key = BotLearning.techKey(position, actionName)
	memory.techAttempts[key] = (memory.techAttempts[key] or 0) + 1
	memory.techScores[key] = math.clamp((memory.techScores[key] or 0) + reward, -80, 80)
end

function BotLearning.recordDeadEnd(memory: RLearningMemory, position: Vector3, penalty: number)
	local key = `{math.floor(position.X / 8 + 0.5)}:{math.floor(position.Y / 8 + 0.5)}:{math.floor(position.Z / 8 + 0.5)}`
	memory.deadEndScores[key] = math.clamp((memory.deadEndScores[key] or 0) + penalty, -100, 20)
end

function BotLearning.getDeadEndPenalty(memory: RLearningMemory, position: Vector3): number
	local key = `{math.floor(position.X / 8 + 0.5)}:{math.floor(position.Y / 8 + 0.5)}:{math.floor(position.Z / 8 + 0.5)}`
	return math.max(0, -(memory.deadEndScores[key] or 0))
end

function BotLearning.areaKey(position: Vector3): string
	return `{math.floor(position.X / 16 + 0.5)}:{math.floor(position.Y / 12 + 0.5)}:{math.floor(position.Z / 16 + 0.5)}`
end

function BotLearning.recordArea(memory: RLearningMemory, position: Vector3, reward: number)
	local key = BotLearning.areaKey(position)
	memory.areaAttempts[key] = (memory.areaAttempts[key] or 0) + 1
	memory.areaScores[key] = math.clamp((memory.areaScores[key] or 0) + reward, -120, 120)
end

function BotLearning.getAreaScore(memory: RLearningMemory, position: Vector3): number
	local key = BotLearning.areaKey(position)
	local attempts = memory.areaAttempts[key] or 0
	if attempts <= 0 then return 0 end

	return (memory.areaScores[key] or 0) / attempts
end

return BotLearning
