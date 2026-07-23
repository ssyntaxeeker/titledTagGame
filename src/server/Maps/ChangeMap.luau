--!strict
--[[
    ChangeMap (Server)
    ==================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Replaces the live map incrementally. Ordinary changes preserve the active
    mode and player roles; lifecycle transitions explicitly opt out.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterLoader = require(ServerStorage.Modules.Characters.CharacterLoader)
local Net = require(ReplicatedStorage.Packages.Net)
local RoundManager = require(ServerStorage.Modules.GameLogic.Round.RoundManager)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local Assets = ReplicatedStorage.Assets

local SplashScreenRE = Net:RemoteEvent("SplashScreen")
local mapChangeId = 0

export type Params = {
	preserveSession: boolean?,
}

local function changeMap(mapModel: Instance, params: Params?): boolean
	assert(mapModel:IsA("Folder") or mapModel:IsA("Model"), "[ChangeMap] mapModel must be a Folder or Model")
	mapChangeId += 1
	local requestId = mapChangeId
	local preserveSession = params == nil or params.preserveSession ~= false
	local preservedMode = if preserveSession then workspace:GetAttribute("Gamemode") else nil
	local preservedTime = if preserveSession then workspace:GetAttribute("TimeLeft") else nil
	local preservedRoles: { [Player]: string } = {}
	if preserveSession then
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local role = if character then character:GetAttribute("Role") else nil
			if typeof(role) == "string" then preservedRoles[player] = role end
		end
	end
	RoundManager.SetMode("Intermission")

	SplashScreenRE:FireAllClients(true)

	for playerIndex, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		character:Destroy()
		if playerIndex % 4 == 0 then task.wait() end
		if requestId ~= mapChangeId then return false end
	end

	local oldMap = workspace:FindFirstChild("Map")
	if oldMap then
		oldMap:Destroy()
		task.wait()
		if requestId ~= mapChangeId then return false end
	end

	workspace:SetAttribute("Map", mapModel.Name)

	-- Large maps can exhaust Studio's script budget when destruction, cloning,
	-- and replication are charged to one uninterrupted resume.
	task.wait()
	if requestId ~= mapChangeId then return false end
	local newMap = mapModel:Clone()
	task.wait()
	if requestId ~= mapChangeId then
		newMap:Destroy()
		return false
	end
	newMap.Name = "Map"
	newMap.Parent = workspace
	task.wait()

	local sky = newMap:GetAttribute("Sky")
	if sky then
		local skyInstance = Assets.Skies:FindFirstChild(sky)
		if skyInstance then
			local currentSkyBox = Lighting:FindFirstAncestorOfClass("Sky")
			if currentSkyBox then currentSkyBox:Destroy() end

			local newSky = skyInstance:Clone()
			newSky.Parent = Lighting
		end
	end

	task.wait(1)
	if requestId ~= mapChangeId then return false end

	for _, player in Players:GetPlayers() do
		CharacterLoader.Load(player)
	end
	if requestId ~= mapChangeId then return false end

	if typeof(preservedMode) == "string" then
		if not RoundManager.SetMode(preservedMode) then
			SplashScreenRE:FireAllClients(false)
			return false
		end
		if typeof(preservedTime) == "number" then workspace:SetAttribute("TimeLeft", preservedTime) end
		for player, role in preservedRoles do
			if player.Parent == Players and not RolesFunctions.ChangeRole(player, role) then
				warn(`[ChangeMap] Could not restore {player.Name}'s role {role}`)
			end
		end
	end

	SplashScreenRE:FireAllClients(false)
	return requestId == mapChangeId
end

return changeMap
