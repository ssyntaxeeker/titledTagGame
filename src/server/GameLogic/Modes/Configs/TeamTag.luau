--!strict
--[[
    TeamTag (Server)
    ================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Tagged opponents join the attacker's team until one team remains.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local CompetitiveModeUtils = require(ServerStorage.Modules.GameLogic.Modes.CompetitiveModeUtils)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local function getWinningTeam(): { Player }
	local redScore = workspace:GetAttribute("RedScore") or 0
	local blueScore = workspace:GetAttribute("BlueScore") or 0
	if redScore == blueScore then return Players:GetPlayers() end
	return CompetitiveModeUtils.GetPlayersWithRole(if redScore > blueScore then "RedTeam" else "BlueTeam")
end

return ModesList.AddMode("TeamTag", {
	start = function(context)
		local players = Players:GetPlayers()
		local redCount = math.ceil(#players / 2)
		CompetitiveModeUtils.AssignShuffled(players, {
			{ role = "RedTeam", count = redCount },
			{ role = "BlueTeam", count = #players - redCount },
		})
		workspace:SetAttribute("RedScore", 0)
		workspace:SetAttribute("BlueScore", 0)
		workspace:SetAttribute("ModeStatus", "RED 0 - 0 BLUE")
		ClockFunctions.SetTime(120)
		if #players < 2 then
			context.delay(1, function()
				context.endRound(players, "NotEnoughPlayers")
			end)
		end
		context.addCleanup(Players.PlayerRemoving:Connect(function()
			context.delay(0, function()
				local red = CompetitiveModeUtils.GetPlayersWithRole("RedTeam")
				local blue = CompetitiveModeUtils.GetPlayersWithRole("BlueTeam")
				if #red == 0 or #blue == 0 then context.endRound(if #red > 0 then red else blue, "TeamEmpty") end
			end)
		end))
	end,
	onTag = function(context, info): boolean
		local attackerRole = info.attackerCharacter:GetAttribute("Role")
		local targetRole = info.targetCharacter:GetAttribute("Role")
		local convertedRole: string
		if attackerRole == "RedTeam" and targetRole == "BlueTeam" then
			workspace:SetAttribute("RedScore", (workspace:GetAttribute("RedScore") or 0) + 1)
			convertedRole = "RedTeam"
		elseif attackerRole == "BlueTeam" and targetRole == "RedTeam" then
			workspace:SetAttribute("BlueScore", (workspace:GetAttribute("BlueScore") or 0) + 1)
			convertedRole = "BlueTeam"
		else
			return false
		end

		assert(
			RolesFunctions.ChangeRole(info.target, convertedRole),
			`[TeamTag.onTag] failed to convert {info.target.Name} to {convertedRole}`
		)
		workspace:SetAttribute("ModeStatus", `RED {workspace:GetAttribute("RedScore")} - {workspace:GetAttribute("BlueScore")} BLUE`)
		context.delay(0, function()
			local red = CompetitiveModeUtils.GetPlayersWithRole("RedTeam")
			local blue = CompetitiveModeUtils.GetPlayersWithRole("BlueTeam")
			if #red == 0 or #blue == 0 then
				context.endRound(if #red > 0 then red else blue, "TeamConverted")
			end
		end)
		return true
	end,
	getWinners = function(): { Player }
		return getWinningTeam()
	end,
})
