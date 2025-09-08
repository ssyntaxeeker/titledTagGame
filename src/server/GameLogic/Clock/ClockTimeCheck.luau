local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function initTimer()
	while task.wait(1) do
		local timeLeft = workspace:GetAttribute("TimeLeft")

		if not timeLeft or timeLeft <= 0 then continue end

		workspace:SetAttribute("TimeLeft", timeLeft - 1)

		if timeLeft - 1 == 0 then
			local gamemode = workspace:GetAttribute("Gamemode")
			local modeConfig = require(ReplicatedStorage.Shared.Configs.Modes[gamemode])

			local winningRole = modeConfig.winRole
			if not winningRole then return end

			print(winningRole)
		end
	end
end

return Schedules.Boot.job(initTimer)
