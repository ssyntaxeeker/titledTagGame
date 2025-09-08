local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)
local RolesUtils = require(ServerStorage.Modules.GameLogic.Roles.RolesUtils)

return ModesList.AddMode("InfCrown", function()
	ClockFunctions.SetTime(-1)

	local teamsList = RolesUtils.SeparatePlayersIntoTeams(
		Players:GetPlayers(),
		{ Crown = (math.clamp(math.round(#Players:GetPlayers() / 10), 1, 4)), Peasant = 40 }
	)

	for player, team in teamsList do
		RolesFunctions.ChangeRole(player, team)
	end
end)
