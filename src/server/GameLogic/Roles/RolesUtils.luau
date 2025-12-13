local RolesUtils = {}

function RolesUtils.SeparatePlayersIntoTeams(players, teams)
	if not teams or next(teams) == nil then return {} end

	local result = {}

	local teamList = {}
	for name, slots in teams do
		table.insert(teamList, { name = name, slots = slots })
	end

	table.sort(teamList, function(a, b)
		return a.slots < b.slots
	end)

	local teamIndex = 1
	for _, player in players do
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
