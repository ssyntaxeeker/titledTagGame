local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterLoader = require(ServerStorage.Modules.Characters.CharacterLoader)
local Net = require(ReplicatedStorage.Packages.Net)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)

local SplashScreenRE = Net:RemoteEvent("SplashScreen")

local function changeMap(mapModel: Model)
	local currentMode = workspace:GetAttribute("Gamemode")

	RoundManager.SetMode("Intermission")

	SplashScreenRE:FireAllClients(true)

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		character:Destroy()
	end

	if workspace:FindFirstChild("Map") then workspace.Map:Destroy() end

	workspace:SetAttribute("Map", mapModel.Name)

	local newMap = mapModel:Clone()
	newMap.Name = "Map"
	newMap.Parent = workspace

	task.wait(1)

	for _, player in Players:GetPlayers() do
		CharacterLoader.Load(player)
	end

	RoundManager.SetMode(currentMode or "Intermission")

	SplashScreenRE:FireAllClients(false)
end

return changeMap
