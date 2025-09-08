local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterLoader = require(ServerStorage.Modules.Characters.CharacterLoader)
local Net = require(ReplicatedStorage.Packages.Net)

local SplashScreenRE = Net:RemoteEvent("SplashScreen")

local function changeMap(mapModel: Model)
	SplashScreenRE:FireAllClients(true)

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		character:Destroy()
	end

	if workspace:FindFirstChild("Map") then workspace.Map:Destroy() end

	local newMap = mapModel:Clone()
	newMap.Name = "Map"
	newMap.Parent = workspace

	for _, player in Players:GetPlayers() do
		CharacterLoader.Load(player)
	end

	SplashScreenRE:FireAllClients(false)
end

return changeMap
