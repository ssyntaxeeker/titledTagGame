local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)
local RolesUtils = require(ServerStorage.Modules.GameLogic.Roles.RolesUtils)

return ModesList.AddMode("InfClassic", function()
	ClockFunctions.SetTime(-1)

	local teamsList = RolesUtils.SeparatePlayersIntoTeams(Players:GetPlayers(), { Tagger = 20, Runner = 20 })

	for player, team in teamsList do
		RolesFunctions.ChangeRole(player, team)
	end
end)
