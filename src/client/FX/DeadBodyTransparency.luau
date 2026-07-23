local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function updatePart(character, part)
	if not part:IsA("BasePart") then return end
	local originalTransparency = part:GetAttribute("DeadBodyOriginalTransparency")
	if typeof(originalTransparency) ~= "number" then
		originalTransparency = part.Transparency
		part:SetAttribute("DeadBodyOriginalTransparency", originalTransparency)
	end
	part.Transparency = if character:GetAttribute("Role") == "Dead"
		then math.max(originalTransparency, 0.6)
		else originalTransparency
end

local function checkCharacterRole(character)
	for _, part in character:GetDescendants() do
		updatePart(character, part)
	end
end

local function initPlayer(player)
	local function onCharacterAdded(character)
		character:GetAttributeChangedSignal("Role"):Connect(function()
			checkCharacterRole(character)
		end)
		character.DescendantAdded:Connect(function(descendant)
			updatePart(character, descendant)
		end)
		checkCharacterRole(character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then onCharacterAdded(player.Character) end
end

local function init()
	for _, player in Players:GetPlayers() do
		initPlayer(player)
	end

	Players.PlayerAdded:Connect(initPlayer)
end

return Schedules.Boot.job(init)
