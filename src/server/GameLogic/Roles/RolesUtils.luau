--!strict
--[[
    RolesUtils (Server)
    ===================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Splits a randomized player list across configured role capacities.
]]

local random = Random.new()
local RolesUtils = {}

function RolesUtils.SeparatePlayersIntoTeams(players: { Player }, teams: { [string]: number }): { [Player]: string }
	if not teams or next(teams) == nil then return {} end

	local result = {}
	local shuffledPlayers = table.clone(players)
	for index = #shuffledPlayers, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		shuffledPlayers[index], shuffledPlayers[swapIndex] = shuffledPlayers[swapIndex], shuffledPlayers[index]
	end

	local teamList = {}
	for name, slots in teams do
		table.insert(teamList, { name = name, slots = slots })
	end

	table.sort(teamList, function(a, b)
		return a.slots < b.slots
	end)

	local teamIndex = 1
	for _, player in shuffledPlayers do
		while teamIndex <= #teamList and teamList[teamIndex].slots <= 0 do
			teamIndex = teamIndex + 1
		end

		if teamIndex > #teamList then break end

		local team = teamList[teamIndex]
		result[player] = team.name
		team.slots = team.slots - 1

		teamIndex = (teamIndex % #teamList) + 1
	end

	return result
end

return RolesUtils
