local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterUtils = require(ReplicatedStorage.Vendor.CharacterUtils)

local Assets = ReplicatedStorage.Assets

local OutfitFunctions = {}

local function glueModel(character, outfitModel: Model)
	outfitModel:PivotTo(character.WorldPivot)

	for _, part in outfitModel:GetChildren() do
		if not part:IsA("BasePart") then continue end

		local partOutfitFolder = outfitModel:FindFirstChild(`Outfit{part.Name}`)
		if not partOutfitFolder then continue end

		local characterPart = character[part.Name]

		for _, accessory in partOutfitFolder:GetChildren() do
			local positionDifference = part.CFrame:ToObjectSpace(accessory.CFrame)

			local weld = Instance.new("Weld")
			weld.Part0 = characterPart
			weld.Part1 = accessory
			weld.C0 = positionDifference
			weld.Parent = accessory

			accessory.Name = "Accessory"
			accessory.Anchored = false
			accessory.Parent = characterPart
		end
	end

	outfitModel:Destroy()
end

function OutfitFunctions.ShowOutfit(character, outfitName)
	if not outfitName then return end

	local outfitModel = Assets.Outfits:FindFirstChild(outfitName)
	if not outfitModel then return end

	CharacterUtils.RemoveExtraAccessories(character)

	outfitModel = outfitModel:Clone()

	glueModel(character, outfitModel)
end

function OutfitFunctions.RemoveOutfit(character)
	for _, part in character:GetChildren() do
		if not part:IsA("BasePart") then continue end

		for _, accessory in part:GetChildren() do
			if accessory.Name ~= "Accessory" then continue end

			accessory:Destroy()
		end
	end
end

return OutfitFunctions
