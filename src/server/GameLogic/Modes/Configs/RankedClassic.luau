local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

return ModesList.AddMode("RankedClassic", function()
	ClockFunctions.SetTime(125)

	local roundNumber = ReplicatedStorage:GetAttribute("RoundNumber") or 0
	local players = Players:GetPlayers()

	for index, player in players do
		local isOdd = index % 2 == 1
		local role

		if roundNumber % 2 == 0 then
			role = isOdd and "Runner" or "Tagger"
		else
			role = isOdd and "Tagger" or "Runner"
		end

		RolesFunctions.ChangeRole(player, role)
	end
end)
