local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HighlightFunctions = require(ReplicatedStorage.Modules.Highlights.HighlightFunctions)
local localPlayer = Players.LocalPlayer

local function startHighlight()
	HighlightFunctions.ResetHighlights()

	if not localPlayer.Character then return end

	local roleName = localPlayer.Character:GetAttribute("Role")
	if not roleName then return end

	local roleConfig = require(ReplicatedStorage.Shared.Configs.Roles[roleName])
	if not roleConfig or not roleConfig.canTagRoles then return end

	for _, role in roleConfig.canTagRoles do
		HighlightFunctions.HighlightRole(role)
	end
end

local function onRoleChanged(character)
	local player = Players:GetPlayerFromCharacter(character)
	if player == localPlayer then
		startHighlight()
	else
		HighlightFunctions.AttemptToHighlightCharacter(character)
	end
end

local function characterListen(character)
	HighlightFunctions.AttemptToHighlightCharacter(character)
	if character == localPlayer.Character then startHighlight() end

	character:GetAttributeChangedSignal("Role"):Connect(function()
		onRoleChanged(character)
	end)
end

local function initPlayer(player)
	player.CharacterAdded:Connect(characterListen)

	if player.Character then characterListen(player.Character) end
end

for _, player in Players:GetPlayers() do
	initPlayer(player)
end

Players.PlayerAdded:Connect(initPlayer)

return 0
