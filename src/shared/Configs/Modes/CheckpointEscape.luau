--!strict
--[[ Sol (3693744006) | Updated: 26/07/20 | Checkpoint Escape client configuration. ]]
return table.freeze({
	UIGlow = Color3.fromRGB(72, 255, 132),
	UIImage = "rbxassetid://131947676399392",
	Name = "checkpoint escape",
	Descriptions = { "clear every checkpoint before the other speedrunners" },
	onJoinRole = "Dead",
	preserveRoleOnRespawn = true,
	winRole = "Speedrunner",
	allowTagging = false,
})
