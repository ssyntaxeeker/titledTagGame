local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function getServerData()
	local _, getIp = pcall(function()
		return HttpService:GetAsync("https://ifconfig.io/all.json")
	end)

	local ipData = {}
	local serverIP

	if getIp then
		ipData = HttpService:JSONDecode(getIp)
		serverIP = ipData["ip"]
	end

	local _, serverData = pcall(function()
		return HttpService:GetAsync("https://ipapi.co/" .. serverIP .. "/json/")
	end)

	if serverData then serverData = HttpService:JSONDecode(serverData) end

	print(serverData)

	ReplicatedStorage:SetAttribute("Region", serverData.region)
end

return Schedules.Boot.job(getServerData)
