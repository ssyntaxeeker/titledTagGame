--!strict
--[[
    Bomb (Server)
    =============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Runs repeated 50/50 hot-potato phases until one survivor remains.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local CompetitiveModeUtils = require(ServerStorage.Modules.GameLogic.Modes.CompetitiveModeUtils)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

type BombState = {
	phase: number,
	beginPhase: (() -> ())?,
}

local states: { [number]: BombState } = {}
local PHASE_SECONDS = 18

local function beginPhase(context: ModesList.RoundContext)
	local state = states[context.id]
	if not state or not context.isActive() then return end

	local survivors = CompetitiveModeUtils.GetActivePlayers()
	if #survivors <= 1 then
		context.endRound(survivors, "LastRunner")
		return
	end

	state.phase += 1
	local bombCount = math.clamp(math.floor(#survivors / 2), 1, #survivors - 1)
	CompetitiveModeUtils.AssignShuffled(survivors, {
		{ role = "Bomb", count = bombCount },
		{ role = "Runner", count = #survivors - bombCount },
	})
	workspace:SetAttribute("BombPhase", state.phase)
	workspace:SetAttribute("ModeStatus", `Bomb wave {state.phase}: pass it before detonation`)
	ClockFunctions.SetTime(PHASE_SECONDS)
end

return ModesList.AddMode("Bomb", {
	start = function(context)
		states[context.id] = { phase = 0, beginPhase = nil }
		context.addCleanup(function()
			states[context.id] = nil
		end, true)
		context.addCleanup(Players.PlayerRemoving:Connect(function()
			context.delay(0, function()
				local survivors = CompetitiveModeUtils.GetActivePlayers()
				if #survivors <= 1 then
					context.endRound(survivors, "LastRunner")
					return
				end
				if #CompetitiveModeUtils.GetPlayersWithRole("Runner") == 0 then
					local bombs = CompetitiveModeUtils.GetPlayersWithRole("Bomb")
					if bombs[1] then RolesFunctions.ChangeRole(bombs[math.random(1, #bombs)], "Runner") end
				end
			end)
		end))
		beginPhase(context)
	end,
	onTag = function(_, info): boolean
		if info.attackerCharacter:GetAttribute("Role") ~= "Bomb" or info.targetCharacter:GetAttribute("Role") ~= "Runner" then
			return false
		end
		RolesFunctions.ChangeRole(info.attacker, "Runner")
		RolesFunctions.ChangeRole(info.target, "Bomb")
		return true
	end,
	onTimerExpired = function(context): boolean
		local bombs = CompetitiveModeUtils.GetPlayersWithRole("Bomb")
		local runners = CompetitiveModeUtils.GetPlayersWithRole("Runner")

		-- A disconnect at the phase boundary can remove every runner. Spare one
		-- bomb so the mode always converges instead of eliminating everybody.
		if #runners == 0 and #bombs > 0 then
			local spared = table.remove(bombs, math.random(1, #bombs))
			RolesFunctions.ChangeRole(spared, "Runner")
			table.insert(runners, spared)
		end

		for _, player in bombs do
			RolesFunctions.ChangeRole(player, "Dead")
			local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid then humanoid.Health = 0 end
		end

		if #runners <= 1 then
			context.endRound(runners, "LastRunner")
		else
			workspace:SetAttribute("ModeStatus", `{#bombs} bombs detonated; next wave incoming`)
			ClockFunctions.SetTime(-1)
			context.delay(3, function()
				beginPhase(context)
			end)
		end
		return true
	end,
	getWinners = function(): { Player }
		return CompetitiveModeUtils.GetPlayersWithRole("Runner")
	end,
})
