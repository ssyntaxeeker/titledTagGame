local CharacterUtils = {}

function CharacterUtils.RemoveExtraAccessories(character)
	if character:FindFirstChild("Shirt") then character.Shirt:Destroy() end
	if character:FindFirstChild("Pants") then character.Pants:Destroy() end

	for _, accessory in character:GetChildren() do
		if accessory:IsA("CharacterMesh") then accessory:Destroy() end
		if not accessory:IsA("Accessory") then continue end

		for _, v in accessory:GetDescendants() do
			if v:IsA("BasePart") then v.CanCollide = false end
		end

		local accessoryType = accessory.AccessoryType
		if accessoryType == Enum.AccessoryType.Hair then continue end
		if accessoryType == Enum.AccessoryType.Hat then continue end
		if accessoryType == Enum.AccessoryType.Face then continue end

		accessory:Destroy()
	end
end

function CharacterUtils.CheckIfInstanceIsPartOfCharacter(instance)
	local parent = instance

	while parent do
		if parent:IsA("Model") and parent:FindFirstChild("Humanoid") then return parent.Humanoid end
		parent = parent.Parent
	end

	return false
end

return CharacterUtils
