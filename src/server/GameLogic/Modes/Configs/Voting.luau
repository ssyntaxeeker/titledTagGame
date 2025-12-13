local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)
local VotingFunctions = require(ServerStorage.Modules.Voting.VotingFunctions)

return ModesList.AddMode("Voting", function()
	ClockFunctions.SetTime(15)

	VotingFunctions.StartVoting("mode")

	ClockInterface.roundEndedSignal:Once(function()
		if workspace:GetAttribute("Gamemode") ~= "Voting" then return end

		VotingFunctions.EndVoting()
	end)
end)
