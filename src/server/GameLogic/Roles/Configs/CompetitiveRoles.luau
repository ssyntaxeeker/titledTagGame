--!strict
--[[
    CompetitiveRoles (Server)
    =========================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Registers the movement behavior for competitive mode roles.
]]

local ServerStorage = game:GetService("ServerStorage")

local RoleMovementPresets = require(ServerStorage.Modules.GameLogic.Roles.RoleMovementPresets)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

for _, roleName in { "Freezer", "Bounty", "Hunter", "RedTeam", "BlueTeam", "Bomb" } do
	RolesFunctions.RegisterRole(roleName, RoleMovementPresets.Standard)
end

RolesFunctions.RegisterRole("Frozen", RoleMovementPresets.Frozen)

return 0
