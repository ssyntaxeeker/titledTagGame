--!strict
--[[
    RankedFFA (Shared)
    ==================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Defines the kill-limited ranked FFA stage independently from infinite FFA.
]]

return table.freeze({
	UIGlow = Color3.fromRGB(196, 42, 42),
	UIImage = "rbxassetid://114330366845510",
	Name = "FFA",
	Descriptions = { "first to the kill limit wins" },

	onJoinRole = "Alone",
	respawnAsRole = "Alone",

	allowDamage = 51,
	allowTagging = true,
})
