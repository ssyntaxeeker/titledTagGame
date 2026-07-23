--!strict
--[[
    ModesList (Server)
    ==================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Stores declarative round definitions used by the round lifecycle.
]]

export type RoundContext = {
	id: number,
	mode: string,
	isActive: () -> boolean,
	delay: (seconds: number, callback: () -> ()) -> thread,
	addCleanup: (cleanup: any, methodName: any?) -> any,
	endRound: (winners: { Player }?, reason: string?) -> boolean,
}

export type TagInfo = {
	attacker: Player,
	target: Player,
	attackerCharacter: Model,
	targetCharacter: Model,
}

export type ModeDefinition = {
	start: (context: RoundContext) -> (),
	onTag: ((context: RoundContext, info: TagInfo) -> boolean)?,
	onTimerExpired: ((context: RoundContext) -> boolean)?,
	getWinners: ((context: RoundContext, reason: string) -> { Player })?,
}

local ModesList = {}
local list: { [string]: ModeDefinition } = {}

function ModesList.AddMode(modeName: string, definition: ModeDefinition | (RoundContext) -> ()): number
	assert(type(modeName) == "string" and modeName ~= "", "[ModesList.AddMode] modeName must be non-empty")
	assert(list[modeName] == nil, `[ModesList.AddMode] {modeName} is already registered`)

	list[modeName] = if type(definition) == "function" then { start = definition } else definition
	assert(type(list[modeName].start) == "function", `[ModesList.AddMode] {modeName} requires start`)
	return 0
end

function ModesList.GetMode(modeName: string): ModeDefinition?
	return list[modeName]
end

return ModesList
