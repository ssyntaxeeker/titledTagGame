local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.Packages.ProfileStore)
local Profiles = require(ServerStorage.Modules.Data.Profiles)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local PlayerProfileStore = ProfileStore.New("PRE_RELEASE_1", Profiles.PlayerDataTemplate)

local function initPlayer(player)
	local profile = Profiles.Create(PlayerProfileStore, player)

	if not profile then
		warn(`Profile did not load for {player.Name}`)
		return
	end

	for data, value in profile.Data do
		if typeof(value) == "table" then continue end

		player:SetAttribute(data, value)
	end

	player:SetAttribute("DataReady", true)
end

local function init()
	Players.PlayerAdded:Connect(function(player)
		initPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = Profiles.ReturnProfile(player)

		if profile ~= nil then profile:EndSession() end
	end)
end

return Schedules["Boot"].job(init)
