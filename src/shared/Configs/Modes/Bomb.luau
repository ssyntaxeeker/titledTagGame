--!strict
--[[ Sol (3693744006) | Updated: 26/07/19 | Bomb mode client configuration. ]]
return table.freeze({
	UIGlow = Color3.fromRGB(255, 86, 31),
	UIImage = "rbxassetid://114330366845510",
	Name = "bomb",
	Descriptions = { "pass the bomb before each detonation" },
	onJoinRole = "Dead",
	respawnAsRole = "Dead",
	winRole = "Runner",
	allowTagging = true,
})
