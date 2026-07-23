--!strict
--[[
    RankedClassic (Shared)
    ======================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Defines ranked Classic presentation, role behavior, and movement tuning.
]]

return table.freeze({
	UIGlow = Color3.fromRGB(248, 111, 111),
	UIImage = "rbxassetid://131947676399392",
	Name = "ranked classic",
	Descriptions = { "get that ELO!" },

	onJoinRole = "Tagger",
	winRole = "Runner",

	regiveRoleOnCharacterRemoved = "Runner",
	allowedRolesToGetRegivenRole = { "Tagger" },

	allowTagging = true,
	maximumMomentum = 36,
})
