--!strict
--[[
    BotTechHints (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Stores and resolves local "you can do this here" tech hints for the bot
    trainer without creating full route data.
]]

type DirectionScore = {
	score: number,
	visits: number,
}

type HintState = {
	routeTechNotes: { [string]: DirectionScore },
}

type NearestNodeId = (Vector3, number?) -> number?

local BotTechHints = {}

local HINT_ACTIONS = table.freeze({
	"Jump",
	"Vault",
	"TimedHighVault",
	"SlideBoost",
	"SlideVault",
	"ClimbableWall",
	"Roll",
	"RollBoost",
	"Swing",
})

function BotTechHints.canonicalAction(actionName: string): string
	local action = actionName:gsub("^%s+", ""):gsub("%s+$", "")
	if action == "" or action == "Move" or action == "Start" or action == "End" then return "Jump" end

	local lowerAction = string.lower(action)
	if lowerAction == "highvault" or lowerAction == "high vault" or lowerAction == "timed vault" then return "TimedHighVault" end
	if lowerAction == "slide" or lowerAction == "slidecancel" or lowerAction == "slide cancel" or lowerAction == "slideboost" then
		return "SlideBoost"
	end
	if lowerAction == "climbablewall" or lowerAction == "climbable wall" or lowerAction == "wallslide" or lowerAction == "wall slide" then
		return "ClimbableWall"
	end
	if lowerAction == "rollboost" or lowerAction == "roll boost" then return "RollBoost" end
	if string.find(lowerAction, "swing") then return "Swing" end
	if string.find(lowerAction, "roll") then return "Roll" end
	if string.find(lowerAction, "vault") then return "Vault" end
	if string.find(lowerAction, "jump") then return "Jump" end

	return action
end

function BotTechHints.runtimeTech(actionName: string, heightDelta: number): string
	local action = BotTechHints.canonicalAction(actionName)
	if action == "Jump" then return if heightDelta > 2.5 then "JumpVault" else "JumpProbe" end
	if action == "SlideBoost" or action == "SlideVault" or action == "ClimbableWall" then return "SlideVault" end
	if action == "Roll" then return "RollBoost" end
	if action == "TimedHighVault" then return "TimedHighVault" end
	if action == "RollBoost" then return "RollBoost" end
	if action == "Swing" then return "Swing" end
	return action
end

function BotTechHints.hintKey(nodeId: number, actionName: string): string
	return `hint:{nodeId}:{BotTechHints.canonicalAction(actionName)}`
end

function BotTechHints.findBestRuntimeTech(
	state: HintState,
	nearestNodeId: NearestNodeId,
	position: Vector3,
	searchRadius: number,
	heightDelta: number
): (string?, string?)
	local nodeId = nearestNodeId(position, searchRadius)
	if not nodeId then return nil, nil end

	local bestAction: string? = nil
	local bestScore = 0
	for _, actionName in HINT_ACTIONS do
		local scoreInfo = state.routeTechNotes[BotTechHints.hintKey(nodeId, actionName)]
		if not scoreInfo then continue end

		local confidence = scoreInfo.score + math.min(scoreInfo.visits, 12) * 0.2
		if confidence > bestScore then
			bestScore = confidence
			bestAction = actionName
		end
	end

	if not bestAction then return nil, nil end
	return BotTechHints.runtimeTech(bestAction, heightDelta), bestAction
end

return table.freeze(BotTechHints)
