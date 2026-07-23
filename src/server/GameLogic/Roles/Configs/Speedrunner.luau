--!strict
--[[
    Speedrunner (Server)
    ====================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Registers standard movement with reduced momentum gains for checkpoint
    racing. Collision and tagging rules live in the shared role definition.
]]

local ServerStorage = game:GetService("ServerStorage")

local RoleMovementPresets = require(ServerStorage.Modules.GameLogic.Roles.RoleMovementPresets)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

return RolesFunctions.RegisterRole("Speedrunner", function(player: Player)
	RoleMovementPresets.Standard(player)
	local character = player.Character
	assert(character, `[Speedrunner] {player.Name} has no character`)
	character:SetAttribute("MomentumMultiplier", 0.5)
	character:SetAttribute("VaultMomentumMultiplier", 0.5)
end)
