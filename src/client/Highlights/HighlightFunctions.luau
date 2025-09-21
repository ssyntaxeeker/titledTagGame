local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local HighlightFunctions = {}
local characterHighlights = {}
local highlightedRoles = {}

local function clearCharacterHighlight(character)
	local existing = characterHighlights[character]
	if existing then
		if existing.Parent then existing:Destroy() end
		characterHighlights[character] = nil
	end
end

local function highlight(character, color)
	if not character then return end

	clearCharacterHighlight(character)

	local Highlight = Instance.new("Highlight")
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.FillColor = color
	Highlight.FillTransparency = 0.5
	Highlight.OutlineColor = color
	Highlight.OutlineTransparency = 0.25
	Highlight.Parent = character

	characterHighlights[character] = Highlight
end

function HighlightFunctions.HighlightRole(roleName)
	if not roleName then return end
	highlightedRoles[roleName] = true

	local roleConfig = require(ReplicatedStorage.Shared.Configs.Roles[roleName])
	if not roleConfig then return end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if player ~= localPlayer and character and character:GetAttribute("Role") == roleName then highlight(character, roleConfig.Color) end
	end
end

function HighlightFunctions.AttemptToHighlightCharacter(character)
	if character == localPlayer.Character then return end

	local role = character:GetAttribute("Role")
	if not role or not highlightedRoles[role] then
		clearCharacterHighlight(character)
		return
	end

	local roleConfig = require(ReplicatedStorage.Shared.Configs.Roles[role])

	if not roleConfig then
		clearCharacterHighlight(character)
		return
	end

	highlight(character, roleConfig.Color)
end

function HighlightFunctions.ResetHighlights()
	for character, highlightObj in pairs(characterHighlights) do
		if highlightObj and highlightObj.Parent then highlightObj:Destroy() end
		characterHighlights[character] = nil
	end

	highlightedRoles = {}
end

return HighlightFunctions
