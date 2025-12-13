local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function getServerData()
	local serverIP

	local success, response = pcall(function()
		return HttpService:GetAsync("https://ifconfig.io/all.json")
	end)

	if success and response then
		local ok, ipData = pcall(function()
			return HttpService:JSONDecode(response)
		end)
		if ok and ipData then serverIP = ipData.ip end
	end

	if not serverIP then
		warn("Failed to get server IP")
		return
	end

	local regionSuccess, serverData = pcall(function()
		return HttpService:GetAsync("https://ipapi.co/" .. serverIP .. "/json/")
	end)

	if regionSuccess and serverData then
		local ok, decodedData = pcall(function()
			return HttpService:JSONDecode(serverData)
		end)
		if ok and decodedData then
			ReplicatedStorage:SetAttribute("Region", decodedData.region)
		else
			warn("Failed to decode server data")
		end
	else
		warn("Failed to get server data")
	end
end

return Schedules.Boot.job(getServerData)
