local ServerStorage = game:GetService("ServerStorage")

local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

return RolesFunctions.RegisterRole("Alone", function(player)
	local character = player.Character

	character:SetAttribute("MinRunSpeed", 16)
	character:SetAttribute("MaxRunSpeed", 32)

	character:SetAttribute("MinJumpPower", 16)
	character:SetAttribute("MaxJumpPower", 28)
	character:SetAttribute("RollboostJumpPower", 33.6)

	character:SetAttribute("AccelerationRate", 16)
	character:SetAttribute("DecelerationRate", 1.4)

	character:SetAttribute("VaultMomentumMultiplier", 0.4)
end)
