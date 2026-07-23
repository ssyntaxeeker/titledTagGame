--!strict
--[[
    Voting (Server)
    ===============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Registers a cancellable mode vote.
]]

local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local VotingFunctions = require(ServerStorage.Modules.Voting.VotingFunctions)

return ModesList.AddMode("Voting", {
	start = function(context)
		ClockFunctions.SetTime(15)
		VotingFunctions.StartVoting("mode", context.id)
		context.addCleanup(function()
			VotingFunctions.CancelVoting(context.id)
		end, true)
	end,
	onTimerExpired = function(context): boolean
		VotingFunctions.EndVoting(context.id)
		return true
	end,
})
