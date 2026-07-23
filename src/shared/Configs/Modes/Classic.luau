return {
	UIGlow = Color3.fromRGB(111, 136, 248),
	UIImage = "rbxassetid://131947676399392",
	Name = "classic",
	Descriptions = { "run from the TAGGERS!" },

	onJoinRole = "Tagger",
	winRole = "Runner",

	respawnAsRole = "Dead",

	regiveRoleOnCharacterRemoved = "Runner",
	allowedRolesToGetRegivenRole = { "Tagger" },

	allowTagging = true,
}
