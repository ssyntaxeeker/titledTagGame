local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local HealthBarUI = Assets.UI.HealthBarUI:Clone()
HealthBarUI.Parent = localPlayer.PlayerGui

local Main = HealthBarUI.Main

local fillTweenInfo = TweenInfo.new(0.15)

local function updateUI()
	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local health, maxHealth = humanoid.Health, humanoid.MaxHealth

	HealthBarUI.Enabled = health < maxHealth or SettingsInterface.display.alwaysShowHP

	local role = character:GetAttribute("Role")
	if role then
		local roleConfig = require(ReplicatedStorage.Shared.Configs.Roles[role])

		Main.Fill.BackgroundColor3 = roleConfig.Color
	end

	Main.Percentage.Text = math.floor(health)
	TweenService:Create(Main.Fill, fillTweenInfo, { Size = UDim2.fromScale(health / maxHealth, 1) }):Play()
end

return updateUI
