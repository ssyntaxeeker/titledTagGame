--!strict
--[[
    RoundManager (Server)
    =====================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Owns one cancellable round session, resets combat state between modes, and
    rejects stale delayed work.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)

type RoundContext = ModesList.RoundContext
type TagInfo = ModesList.TagInfo

local RoundManager = {}
local roundId = 0
local activeDefinition: ModesList.ModeDefinition? = nil
local activeContext: RoundContext? = nil
local activeJanitor: any = nil
local endRound: (winners: { Player }?, reason: string?) -> boolean

local function makeContext(id: number, mode: string, janitor: any): RoundContext
	local context = {} :: any
	context.id = id
	context.mode = mode
	context.isActive = function(): boolean
		return roundId == id and workspace:GetAttribute("RoundState") ~= "Ended"
	end
	context.delay = function(seconds: number, callback: () -> ()): thread
		local delayedThread = task.delay(seconds, function()
			if roundId == id then callback() end
		end)
		janitor:Add(delayedThread, true)
		return delayedThread
	end
	context.addCleanup = function(cleanup: any, methodName: any?): any
		return janitor:Add(cleanup, methodName)
	end
	context.endRound = function(winners: { Player }?, reason: string?): boolean
		if roundId ~= id then return false end
		return endRound(winners, reason)
	end
	return context
end

function RoundManager.SetMode(mode: string): boolean
	local definition = ModesList.GetMode(mode)
	if not definition then
		warn(`[RoundManager.SetMode] {mode} is not registered`)
		return false
	end

	if activeJanitor then activeJanitor:Destroy() end

	roundId += 1
	local id = roundId
	local janitor = Janitor.new()
	local context = makeContext(id, mode, janitor)
	activeJanitor = janitor
	activeDefinition = definition
	activeContext = context

	workspace:SetAttribute("RoundId", id)
	workspace:SetAttribute("Gamemode", mode)
	workspace:SetAttribute("RoundState", "Running")
	workspace:SetAttribute("ModeStatus", "")
	workspace:SetAttribute("TimeLeft", -1)

	-- Characters can legitimately be absent during map replacement. Existing
	-- living characters begin every mode with clean health and tag protection.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if character then character:SetAttribute("NTBDurability", 0) end
		if humanoid and humanoid.Health > 0 then humanoid.Health = humanoid.MaxHealth end
	end

	local succeeded, message = xpcall(function()
		definition.start(context)
	end, debug.traceback)
	if not succeeded then
		workspace:SetAttribute("RoundState", "Failed")
		warn(`[RoundManager.SetMode] {mode} failed:\n{message}`)
		return false
	end

	return true
end

function RoundManager.GetRoundId(): number
	return roundId
end

function RoundManager.IsCurrent(id: number): boolean
	return roundId == id
end

function RoundManager.HandleTag(info: TagInfo): boolean
	local definition = activeDefinition
	local context = activeContext
	if not definition or not context or not context.isActive() then return false end
	local onTag = definition.onTag
	if not onTag then return false end
	return onTag(context, info)
end

function RoundManager.EndRound(winners: { Player }?, reason: string?): boolean
	local context = activeContext
	if not context or workspace:GetAttribute("RoundState") ~= "Running" then return false end

	local resolvedReason = reason or "Completed"
	local resolvedWinners = winners
	local getWinners = if activeDefinition then activeDefinition.getWinners else nil
	if not resolvedWinners and getWinners then
		resolvedWinners = getWinners(context, resolvedReason)
	end
	if not resolvedWinners then
		resolvedWinners = {}
		local gamemode = workspace:GetAttribute("Gamemode")
		local configModule = if type(gamemode) == "string" then ReplicatedStorage.Shared.Configs.Modes:FindFirstChild(gamemode) else nil
		if configModule then
			local modeConfig = require(configModule)
			if modeConfig.winRole then
				for _, player in Players:GetPlayers() do
					if player.Character and player.Character:GetAttribute("Role") == modeConfig.winRole then
						table.insert(resolvedWinners, player)
					end
				end
			end
		end
	end

	workspace:SetAttribute("RoundState", "Ended")
	workspace:SetAttribute("TimeLeft", 0)
	ClockInterface.roundEndedSignal:Fire(resolvedWinners, context.id, resolvedReason, context.mode)
	if activeJanitor then activeJanitor:Cleanup() end
	return true
end

endRound = RoundManager.EndRound

function RoundManager.TimerExpired(id: number): boolean
	local context = activeContext
	if not context or context.id ~= id or workspace:GetAttribute("RoundState") ~= "Running" then return false end
	local onTimerExpired = if activeDefinition then activeDefinition.onTimerExpired else nil
	if onTimerExpired and onTimerExpired(context) then return true end
	return RoundManager.EndRound(nil, "Timer")
end

return RoundManager
