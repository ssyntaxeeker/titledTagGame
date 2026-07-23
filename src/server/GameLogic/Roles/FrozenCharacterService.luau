--!strict
--[[
    FrozenCharacterService (Server)
    =================================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Owns replicated freeze presentation and the physical state that must be
    reversed whenever a character leaves the Frozen role.
]]

local FrozenCharacterService = {}

-- Removes every server-owned freeze effect so role and round transitions
-- cannot leave a character anchored.
function FrozenCharacterService.thaw(character: Model)
	local ice = character:FindFirstChild("FreezeIce")
	if ice then ice:Destroy() end
	character:SetAttribute("KnockbackMultiplier", nil)

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then rootPart.Anchored = false end
end

-- Applies the authoritative frozen state and a non-queryable visual shell.
-- The shell cannot block either physical movement or tag raycasts.
function FrozenCharacterService.freeze(character: Model)
	FrozenCharacterService.thaw(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(rootPart and rootPart:IsA("BasePart"), "[FrozenCharacterService.freeze] character has no HumanoidRootPart")

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	rootPart.Anchored = true
	character:SetAttribute("KnockbackMultiplier", 3)

	local ice = Instance.new("Part")
	ice.Name = "FreezeIce"
	ice.Size = Vector3.new(4.5, 6, 3.5)
	ice.CFrame = rootPart.CFrame
	ice.Color = Color3.fromRGB(145, 230, 255)
	ice.Material = Enum.Material.Ice
	ice.Transparency = 0.38
	ice.CastShadow = false
	ice.Anchored = false
	ice.CanCollide = false
	ice.CanTouch = false
	ice.CanQuery = false
	ice.Massless = true
	ice.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Name = "FreezeIceWeld"
	weld.Part0 = rootPart
	weld.Part1 = ice
	weld.Parent = ice
end

return table.freeze(FrozenCharacterService)
