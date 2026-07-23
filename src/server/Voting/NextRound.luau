local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)

ClockInterface.roundEndedSignal:Connect(function(_, roundId, _, mode)
	if ReplicatedStorage:GetAttribute("Ranked") or mode == "Voting" then return end

	task.delay(3, function()
		if not RoundManager.IsCurrent(roundId) or workspace:GetAttribute("RoundState") ~= "Ended" then return end
		RoundManager.SetMode("Voting")
	end)
end)

return 0
