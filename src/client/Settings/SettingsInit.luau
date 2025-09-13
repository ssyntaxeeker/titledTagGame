local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local RetrieveSettingsRE = Net:RemoteFunction("RetrieveSettings")

local function init()
	local newSettings = RetrieveSettingsRE:InvokeServer()

	for tab, dict in newSettings do
		SettingsInterface[tab] = dict
	end

	SettingsInterface.updateSignal:Fire()
end

return Schedules.Boot.job(init)
