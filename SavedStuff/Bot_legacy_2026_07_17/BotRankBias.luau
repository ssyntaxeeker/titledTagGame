--!strict
--[[
    BotRankBias (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Converts replicated player rank data into learning sample weights. Better
    ranked players influence bot policy more than low-rank or unranked players.
]]

local BotRankBias = {}

local RANK_WEIGHTS = table.freeze({
	C = 0.72,
	["B-"] = 0.95,
	B = 1.08,
	["B+"] = 1.22,
	["A-"] = 1.38,
	A = 1.55,
	["A+"] = 1.78,
	S = 2.05,
	X = 2.32,
})

function BotRankBias.weightForPlayer(player: Player?): number
	if not player then return 1 end

	local rank = player:GetAttribute("Rank")
	local rankWeight = if typeof(rank) == "string" then RANK_WEIGHTS[rank] or 0.72 else 0.72

	local stars = tonumber(player:GetAttribute("Stars")) or 0
	local starsWeight = math.clamp(stars, 0, 5) * 0.12

	local elo = tonumber(player:GetAttribute("ELO")) or 200
	local eloWeight = math.clamp((elo - 200) / 800, -0.25, 0.75)

	return math.clamp(rankWeight + starsWeight + eloWeight, 0.45, 3)
end

function BotRankBias.summaryForPlayer(player: Player?): string
	if not player then return "unknown" end

	return `rank {player:GetAttribute("Rank") or "C"} | stars {player:GetAttribute("Stars") or 0} | elo {player:GetAttribute("ELO") or 200}`
end

return table.freeze(BotRankBias)
