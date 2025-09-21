local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local Profiles = require(ServerStorage.Modules.Data.Profiles)

local ChangeSettingsRE = Net:RemoteEvent("ChangeSettings")
local RetrieveSettingsRE = Net:RemoteFunction("RetrieveSettings")

ChangeSettingsRE.OnServerEvent:Connect(function(player, settingName, key, value)
	repeat
		task.wait(0.1)
	until player:GetAttribute("DataReady")

	local proxy = Profiles.ReturnProxy(player)

	local _settings = proxy.Settings[settingName]
	if not _settings or _settings[key] == nil then return end

	if typeof(value) == "EnumItem" then value = tostring(value) end

	_settings[key] = value
end)

RetrieveSettingsRE.OnServerInvoke = function(player)
	repeat
		task.wait(0.1)
	until player:GetAttribute("DataReady")

	local profile = Profiles.ReturnProfile(player)

	return profile.Data.Settings
end

return 0
