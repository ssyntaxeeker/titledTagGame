--!strict
--[[ Sol (3693744006) | Updated: 26/07/20 | Freeze mode client configuration. ]]
return table.freeze({
	UIGlow = Color3.fromRGB(89, 221, 255),
	UIImage = "rbxassetid://131947676399392",
	Name = "freeze",
	Descriptions = { "freeze runners; thaw teammates; frozen runners can repel freezers" },
	onJoinRole = "Runner",
	winRole = "Runner",
	preserveRoleOnRespawn = true,
	allowTagging = true,
})
