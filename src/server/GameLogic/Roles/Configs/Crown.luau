local ServerStorage = game:GetService("ServerStorage")

local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

return RolesFunctions.RegisterRole("Crown", function(player)
	local character = player.Character

	character:SetAttribute("MaxRunSpeed", 32.75)

	character:SetAttribute("RollboostJumpPower", 35)

	character:SetAttribute("AccelerationRate", 32)
	character:SetAttribute("DecelerationRate", 1.2)

	character:SetAttribute("VaultMomentumMultiplier", 0.6)
end)
