local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RoundUtils = require(ServerStorage.Modules.GameLogic.Round.RoundUtils)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function initTimer()
	while task.wait(1) do
		local timeLeft = workspace:GetAttribute("TimeLeft")

		if not timeLeft or timeLeft <= 0 then continue end

		local gamemode = workspace:GetAttribute("Gamemode")
		local modeConfig = require(ReplicatedStorage.Shared.Configs.Modes[gamemode])

		if modeConfig.lastPlayerStanding then 
			local lastPlayerStanding = RoundUtils.CheckIfLastPlayerStanding()
		
			if lastPlayerStanding then 
				workspace:SetAttribute("TimeLeft", 0)
				timeLeft = 1
			else
				workspace:SetAttribute("TimeLeft", timeLeft - 1)
			end
		else
			workspace:SetAttribute("TimeLeft", timeLeft - 1)
		end

		if timeLeft - 1 == 0 then
			local winningRole = modeConfig.winRole
			if not winningRole then continue end

			print(winningRole)
		end
	end
end

return Schedules.Boot.job(initTimer)
