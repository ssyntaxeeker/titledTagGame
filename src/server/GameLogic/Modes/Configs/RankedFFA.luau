--!strict
--[[
    RankedFFA (Server)
    ==================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Starts the kill-limited ranked FFA ruleset and assigns neutral combat roles.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

return ModesList.AddMode("RankedFFA", function()
	ClockFunctions.SetTime(-1)

	for _, player in Players:GetPlayers() do
		assert(RolesFunctions.ChangeRole(player, "Alone"), `[RankedFFA] failed to assign Alone to {player.Name}`)
	end
end)
