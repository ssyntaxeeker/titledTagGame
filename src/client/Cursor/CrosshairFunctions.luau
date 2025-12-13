local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local CrosshairFunctions = {}

local CrosshairUI = Assets.UI.CrosshairUI:Clone()
CrosshairUI.Parent = localPlayer.PlayerGui

local tweenCooldownUI = TweenService:Create(CrosshairUI.Cooldown, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {
	Size = UDim2.fromOffset(35, 35),
	BackgroundTransparency = 1.3,
})

function CrosshairFunctions.SetCooldown(time)
	tweenCooldownUI:Play()

	task.wait(0.2)

	TweenService:Create(CrosshairUI.Cooldown, TweenInfo.new(time - 0.2, Enum.EasingStyle.Linear), {
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 0.75,
	}):Play()
end

return CrosshairFunctions
