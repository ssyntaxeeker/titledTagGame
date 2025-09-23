local ServerStorage = game:GetService("ServerStorage")

local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

return RolesFunctions.RegisterRole("Tagger", function(player)
	local character = player.Character

	character:SetAttribute("MinRunSpeed", 16)
	character:SetAttribute("MaxRunSpeed", 33)

	character:SetAttribute("MinJumpPower", 16)
	character:SetAttribute("MaxJumpPower", 28)
	character:SetAttribute("RollboostJumpPower", 33.6)

	character:SetAttribute("AccelerationRate", 24)
	character:SetAttribute("DecelerationRate", 1.3)

	character:SetAttribute("VaultMomentumMultiplier", 0.85)
end)
