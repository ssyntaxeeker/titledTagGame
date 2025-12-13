local ServerStorage = game:GetService("ServerStorage")

local ClockFunctions = require(ServerStorage.Modules.GameLogic.Clock.ClockFunctions)
local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)

return ModesList.AddMode("Intermission", function()
	ClockFunctions.SetTime(-1)
end)
