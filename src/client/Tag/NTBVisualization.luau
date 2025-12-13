local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local function showNTBEffect(character, roleData, broken)
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local highlight = part:FindFirstChild("NTBBreakHighlight")
			if highlight then highlight:Destroy() end

			if not broken then
				local box = Instance.new("SelectionBox")
				box.Adornee = part
				box.Color3 = roleData.NoTagBackColor or roleData.Color or Color3.new(1, 0, 0)
				box.LineThickness = 0.09
				box.Transparency = 1
				box.Name = "NTBBreakHighlight"
				box.Parent = part

				TweenService:Create(box, TweenInfo.new(0.5), { Transparency = 0 }):Play()
			end
		end
	end

	if broken then
		task.spawn(function()
			task.wait(1)

			for _, part in character:GetChildren() do
				local box = part:FindFirstChild("NTBBreakHighlight")
				if box then box:Destroy() end
			end
		end)
	end
end

local function onDurabilityChanged(character)
	local durability = character:GetAttribute("NTBDurability")
	local playerRole = character:GetAttribute("Role")
	if not playerRole then return end

	local roleData = require(ReplicatedStorage.Shared.Configs.Roles[playerRole])
	if not roleData then return end

	if durability > 0 then
		showNTBEffect(character, roleData, false)
	else
		showNTBEffect(character, roleData, true)
	end
end

local function characterListen(character)
	character:GetAttributeChangedSignal("NTBDurability"):Connect(function()
		onDurabilityChanged(character)
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
