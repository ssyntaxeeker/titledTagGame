local ServerStorage = game:GetService("ServerStorage")

local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

return RolesFunctions.RegisterRole("Tagger", function(player)
	local character = player.Character

	character:SetAttribute("MaxRunSpeed", 33)

	character:SetAttribute("AccelerationRate", 32)
	character:SetAttribute("DecelerationRate", 1.3)

	character:SetAttribute("VaultMomentumMultiplier", 0.6)
end)
