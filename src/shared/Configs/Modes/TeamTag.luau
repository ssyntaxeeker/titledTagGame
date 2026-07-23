--!strict
--[[ Sol (3693744006) | Updated: 26/07/20 | Team Tag client configuration. ]]
return table.freeze({
	UIGlow = Color3.fromRGB(255, 72, 115),
	UIImage = "rbxassetid://131947676399392",
	Name = "team tag",
	Descriptions = { "tag opponents to convert them to your team" },
	onJoinRole = "RedTeam",
	preserveRoleOnRespawn = true,
	allowTagging = true,
})
