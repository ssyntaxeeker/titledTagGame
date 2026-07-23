--!strict
--[[
    Bounty (Server)
    ===============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Scores each second a player successfully holds the bounty.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local CompetitiveModeUtils = require(ServerStorage.Modules.GameLogic.Modes.CompetitiveModeUtils)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local function getLeaders(): { Player }
	local winners = {}
	local bestScore = -1
	for _, player in Players:GetPlayers() do
		local score = player:GetAttribute("BountyScore") or 0
		if score > bestScore then
			bestScore = score
			table.clear(winners)
			table.insert(winners, player)
		elseif score == bestScore then
			table.insert(winners, player)
		end
	end
	return winners
end

return ModesList.AddMode("Bounty", {
	start = function(context)
		local players = Players:GetPlayers()
		for _, player in players do
			player:SetAttribute("BountyScore", 0)
		end
		CompetitiveModeUtils.AssignShuffled(players, {
			{ role = "Bounty", count = math.min(1, #players) },
			{ role = "Hunter", count = math.max(0, #players - 1) },
		})
		ClockFunctions.SetTime(90 + 3 * #players)

		local function scoreTick()
			if not context.isActive() then return end
			for _, player in CompetitiveModeUtils.GetPlayersWithRole("Bounty") do
				player:SetAttribute("BountyScore", (player:GetAttribute("BountyScore") or 0) + 1)
			end
			local leader = getLeaders()[1]
			if leader then workspace:SetAttribute("ModeStatus", `{leader.Name} leads with {leader:GetAttribute("BountyScore")}s`) end
			context.delay(1, scoreTick)
		end
		context.delay(1, scoreTick)
		context.addCleanup(Players.PlayerRemoving:Connect(function(leavingPlayer)
			if not leavingPlayer.Character or leavingPlayer.Character:GetAttribute("Role") ~= "Bounty" then return end
			context.delay(0, function()
				local hunters = CompetitiveModeUtils.GetPlayersWithRole("Hunter")
				if hunters[1] then RolesFunctions.ChangeRole(hunters[math.random(1, #hunters)], "Bounty") end
			end)
		end))
	end,
	onTag = function(_, info): boolean
		if info.attackerCharacter:GetAttribute("Role") ~= "Hunter" or info.targetCharacter:GetAttribute("Role") ~= "Bounty" then
			return false
		end
		RolesFunctions.ChangeRole(info.attacker, "Bounty")
		RolesFunctions.ChangeRole(info.target, "Hunter")
		return true
	end,
	getWinners = function(): { Player }
		return getLeaders()
	end,
})
