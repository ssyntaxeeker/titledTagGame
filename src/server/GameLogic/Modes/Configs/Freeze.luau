--!strict
--[[
    Freeze (Server)
    ===============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Freezers immobilize runners, active runners thaw teammates, and frozen
    runners can repel nearby Freezers with amplified tag knockback.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local CompetitiveModeUtils = require(ServerStorage.Modules.GameLogic.Modes.CompetitiveModeUtils)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

return ModesList.AddMode("Freeze", {
	start = function(context)
		local players = Players:GetPlayers()
		local freezerCount = if #players > 1 then math.max(1, math.floor(#players / 4)) else 0
		CompetitiveModeUtils.AssignShuffled(players, {
			{ role = "Freezer", count = freezerCount },
			{ role = "Runner", count = #players - freezerCount },
		})
		ClockFunctions.SetTime(100 + 3 * #players)
		workspace:SetAttribute("ModeStatus", "Freezers lock runners; runners thaw; frozen players repel")
		context.addCleanup(Players.PlayerRemoving:Connect(function()
			context.delay(0, function()
				if #CompetitiveModeUtils.GetPlayersWithRole("Runner") == 0 then
					context.endRound(CompetitiveModeUtils.GetPlayersWithRole("Freezer"), "NoRunners")
				end
			end)
		end))
		context.addCleanup(function()
			for _, player in CompetitiveModeUtils.GetPlayersWithRole("Frozen") do
				RolesFunctions.ChangeRole(player, "Runner")
			end
		end, true)
	end,
	onTag = function(context, info): boolean
		local attackerRole = info.attackerCharacter:GetAttribute("Role")
		local targetRole = info.targetCharacter:GetAttribute("Role")
		if attackerRole == "Freezer" and targetRole == "Runner" then
			RolesFunctions.ChangeRole(info.target, "Frozen")
			if #CompetitiveModeUtils.GetPlayersWithRole("Runner") == 0 then
				context.endRound(CompetitiveModeUtils.GetPlayersWithRole("Freezer"), "AllFrozen")
			end
			return true
		end
		if attackerRole == "Runner" and targetRole == "Frozen" then
			RolesFunctions.ChangeRole(info.target, "Runner")
			return true
		end
		if attackerRole == "Frozen" and targetRole == "Freezer" then
			return true
		end
		return false
	end,
	getWinners = function(): { Player }
		local winners = CompetitiveModeUtils.GetPlayersWithRole("Runner")
		for _, player in CompetitiveModeUtils.GetPlayersWithRole("Frozen") do
			table.insert(winners, player)
		end
		return winners
	end,
})
