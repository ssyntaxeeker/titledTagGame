local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local CharacterLoader = require(ServerStorage.Modules.Characters.CharacterLoader)

local function spawnPlayer(player)
	if not workspace:FindFirstChild("Map") then return end

	CharacterLoader.Load(player)
end

Players.PlayerAdded:Connect(spawnPlayer)

return 0
