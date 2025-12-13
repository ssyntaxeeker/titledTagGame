local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClockInterface = require(ServerStorage.Modules.GameLogic.Clock.ClockInterface)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)

ClockInterface.roundEndedSignal:Connect(function()
	if ReplicatedStorage:GetAttribute("Ranked") or workspace:GetAttribute("Gamemode") == "Voting" then return end

	task.delay(3, function()
		RoundManager.SetMode("Voting")
	end)
end)

return 0
