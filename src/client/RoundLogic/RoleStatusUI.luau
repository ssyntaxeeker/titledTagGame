local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local Assets = ReplicatedStorage.Assets
local localPlayer = Players.LocalPlayer

local RoleStatusUI = Assets.UI.RoleStatusUI:Clone()
RoleStatusUI.Parent = localPlayer.PlayerGui

local TitleLabel = RoleStatusUI.Role.Title
local DescriptionLabel = RoleStatusUI.Role.Description
local YouAreLabel = RoleStatusUI.Role.YouAre
local Vignette = RoleStatusUI.Vignette

local DescriptionStroke = Instance.new("NumberValue")
DescriptionStroke.Name = "DescriptionStrokeValue"
DescriptionStroke.Value = 0
DescriptionStroke.Parent = RoleStatusUI

local currentDescription
local activeTask

local function updateDescription(desc)
	DescriptionLabel.Text = string.format(
		'<stroke color="#000000" joins="round" thickness="2" transparency="%s">%s</stroke>',
		tostring(DescriptionStroke.Value),
		desc or "WELP LOL"
	)
end

DescriptionStroke.Changed:Connect(function()
	updateDescription(currentDescription or "WELP LOL")
end)

local tweenVignetteFadeOut = TweenService:Create(Vignette, TweenInfo.new(1.5), { ImageTransparency = 1 })
local tweenTitleExpand = TweenService:Create(TitleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
	Size = UDim2.fromScale(0.8, 0.25),
	Position = UDim2.fromScale(0.5, 0.5),
})
local tweenTitleRotate = TweenService:Create(TitleLabel, TweenInfo.new(1, Enum.EasingStyle.Elastic), { Rotation = 0 })
local tweenYouAreMove = TweenService:Create(YouAreLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
	Position = UDim2.fromScale(0.5, 0.4),
})
local tweenDescriptionMove = TweenService:Create(DescriptionLabel, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
	Position = UDim2.fromScale(0.5, 0.6),
})

local initialTweens = {
	tweenVignetteFadeOut,
	tweenTitleExpand,
	tweenTitleRotate,
	tweenYouAreMove,
	tweenDescriptionMove,
}

local fadeOutTweens = {
	TweenService:Create(DescriptionStroke, TweenInfo.new(1.5), { Value = 1 }),
}

for _, descendant in RoleStatusUI.Role:GetDescendants() do
	if descendant:IsA("TextLabel") then
		table.insert(fadeOutTweens, TweenService:Create(descendant, TweenInfo.new(1.5), { TextTransparency = 1 }))
		if descendant:FindFirstChild("Outline") then
			table.insert(fadeOutTweens, TweenService:Create(descendant.Outline, TweenInfo.new(1.5), { Transparency = 1 }))
		end
	end
end

local allTweens = {}
for _, t in initialTweens do
	table.insert(allTweens, t)
end
for _, t in fadeOutTweens do
	table.insert(allTweens, t)
end

local function resetUI()
	DescriptionStroke.Value = 0
	Vignette.ImageTransparency = 0
	Vignette.Visible = true

	TitleLabel.Size = UDim2.fromScale(0.625, 0.15)
	TitleLabel.Position = UDim2.fromScale(0.5, 0.55)
	TitleLabel.Rotation = math.random(-10, 10)

	YouAreLabel.Position = UDim2.fromScale(0.5, 0.47)
	DescriptionLabel.Position = UDim2.fromScale(0.5, 0.63)

	for _, descendant in RoleStatusUI.Role:GetDescendants() do
		if descendant:IsA("TextLabel") then
			descendant.TextTransparency = 0
			if descendant:FindFirstChild("Outline") then descendant.Outline.Transparency = 0 end
		end
	end
end

local function stopTweens()
	for _, t in allTweens do
		t:Cancel()
	end
end

local function DisplayRoleChange(newRole)
	if not newRole or newRole == "Dead" then return end

	if activeTask then
		task.cancel(activeTask)
		stopTweens()
		resetUI()
		RoleStatusUI.Role.Visible = false
	end

	activeTask = task.spawn(function()
		local roleData = require(ReplicatedStorage.Shared.Configs.Roles[newRole])
		if not roleData then return end

		currentDescription = roleData.DescText
		resetUI()
		Vignette.ImageColor3 = roleData.VignetteColor or roleData.Color
		TitleLabel.TextColor3 = roleData.TextColor or roleData.Color
		TitleLabel.Outline.Color = roleData.TextOuterColor or roleData.Color
		YouAreLabel.Text = roleData.YouAreText or "OH GOD"
		TitleLabel.Text = roleData.RoleText or "I BROKE THE DAMN ROLE SYSTEM"

		updateDescription(roleData.DescText)
		PlaySound("RoleChange")

		RoleStatusUI.Role.Visible = (SettingsInterface.display.showRoleChangeText == true)

		for _, t in initialTweens do
			t:Play()
		end

		task.wait((roleData.BecomeTime or 2) - 0.25)
		Vignette.Visible = false
		for _, t in fadeOutTweens do
			t:Play()
		end

		task.wait(1.5)
		RoleStatusUI.Role.Visible = false
		activeTask = nil
	end)
end

local function setupCharacter(character)
	local currentRole = character:GetAttribute("Role")
	if currentRole then DisplayRoleChange(currentRole) end

	character:GetAttributeChangedSignal("Role"):Connect(function()
		DisplayRoleChange(character:GetAttribute("Role"))
	end)
end

local function init()
	if localPlayer.Character then setupCharacter(localPlayer.Character) end

	localPlayer.CharacterAdded:Connect(setupCharacter)
end

return Schedules.Boot.job(init)
