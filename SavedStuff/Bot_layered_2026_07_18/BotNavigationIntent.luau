--!strict
--[[
    BotNavigationIntent (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Separates fast opponent tracking from committed graph objectives. Taggers
    lock a cross-layer access goal until they reach that layer, preventing
    small player movements from repeatedly discarding useful climb routes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole

export type Mode = "Reactive" | "VerticalAccess"

export type RState = {
	mode: Mode,
	goalPosition: Vector3?,
	targetLayerY: number?,
	lockedAt: number,
}

local BotNavigationIntent = {}

function BotNavigationIntent.create(): RState
	return {
		mode = "Reactive",
		goalPosition = nil,
		targetLayerY = nil,
		lockedAt = 0,
	}
end

function BotNavigationIntent.invalidate(state: RState)
	state.mode = "Reactive"
	state.goalPosition = nil
	state.targetLayerY = nil
	state.lockedAt = 0
end

--[=[
	@client

	update
	======

	Returns the stable graph objective. Same-layer goals remain fully reactive;
	cross-layer tagger goals retain their original X/Z access objective while
	the opponent moves around on that layer.
]=]
function BotNavigationIntent.update(
	state: RState,
	role: BotRole,
	botPosition: Vector3,
	tacticalGoal: Vector3,
	opponentPosition: Vector3,
	isIndependentGoal: boolean
): (Vector3, Mode)
	if role ~= "Tagger" or isIndependentGoal then
		BotNavigationIntent.invalidate(state)
		return tacticalGoal, "Reactive"
	end

	if state.mode == "VerticalAccess" then
		local targetLayerY = state.targetLayerY
		local reachedLayer = targetLayerY ~= nil
			and math.abs(botPosition.Y - targetLayerY) <= Config.navigationVerticalExitTolerance
		local targetReturnedToBotLayer = math.abs(opponentPosition.Y - botPosition.Y)
			<= Config.directChaseVerticalTolerance
		if reachedLayer or targetReturnedToBotLayer then
			BotNavigationIntent.invalidate(state)
		end
	end

	if state.mode ~= "VerticalAccess"
		and math.abs(opponentPosition.Y - botPosition.Y) >= Config.navigationVerticalEnterTolerance
	then
		state.mode = "VerticalAccess"
		state.goalPosition = tacticalGoal
		state.targetLayerY = opponentPosition.Y
		state.lockedAt = os.clock()
	end

	return state.goalPosition or tacticalGoal, state.mode
end

return table.freeze(BotNavigationIntent)
