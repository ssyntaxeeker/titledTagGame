--!strict
--[[
    RoleMovementPresets (Server)
    ============================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Shared movement presets for role definitions.
]]

local RoleMovementPresets = {}
local FrozenCharacterService = require(game:GetService("ServerStorage").Modules.GameLogic.Roles.FrozenCharacterService)

function RoleMovementPresets.Standard(player: Player)
	local character = player.Character
	assert(character, `[RoleMovementPresets.Standard] {player.Name} has no character`)
	character:SetAttribute("MinRunSpeed", 16)
	character:SetAttribute("MaxRunSpeed", 32)
	character:SetAttribute("MinJumpPower", 16)
	character:SetAttribute("MaxJumpPower", 28)
	character:SetAttribute("RollboostJumpPower", 33.6)
	character:SetAttribute("AccelerationRate", 12)
	character:SetAttribute("DecelerationRate", 14)
	character:SetAttribute("MomentumMultiplier", 1)
	character:SetAttribute("VaultMomentumMultiplier", 1)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then rootPart.Anchored = false end
end

function RoleMovementPresets.Frozen(player: Player)
	local character = player.Character
	assert(character, `[RoleMovementPresets.Frozen] {player.Name} has no character`)
	character:SetAttribute("MinRunSpeed", 0)
	character:SetAttribute("MaxRunSpeed", 0)
	character:SetAttribute("MinJumpPower", 0)
	character:SetAttribute("MaxJumpPower", 0)
	character:SetAttribute("RollboostJumpPower", 0)
	character:SetAttribute("AccelerationRate", 0)
	character:SetAttribute("DecelerationRate", 30)
	character:SetAttribute("MomentumMultiplier", 0)
	character:SetAttribute("VaultMomentumMultiplier", 0)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	FrozenCharacterService.freeze(character)
end

return table.freeze(RoleMovementPresets)
