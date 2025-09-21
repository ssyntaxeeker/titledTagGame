local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local RetrieveSettingsRE = Net:RemoteFunction("RetrieveSettings")

local function init()
	local newSettings = RetrieveSettingsRE:InvokeServer()

	for index, value in newSettings.keybinds do 
		 local enumType, enumValue = value:match("^Enum%.([%w_]+)%.([%w_]+)$")
		 if not enumType or not enumValue then continue end 

		newSettings.keybinds[index] = Enum[enumType][enumValue] 
	end

	for tab, dict in newSettings do
		SettingsInterface[tab] = dict
	end

	SettingsInterface.updateSignal:Fire()
end

return Schedules.Boot.job(init)
