local ServerStorage = game:GetService("ServerStorage")

local ModesList = require(ServerStorage.Modules.GameLogic.Modes.ModesList)

local RoundManager = {}

function RoundManager.SetMode(mode)
	local modeFunction = ModesList.GetMode(mode)

	if not modeFunction then
		warn(`Couldn't set {mode}: Gamemode is not registered`)
		return
	end

	modeFunction()
	workspace:SetAttribute("Gamemode", mode)
end

return RoundManager
