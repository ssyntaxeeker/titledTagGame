local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Packages.Net)

local Assets = ReplicatedStorage.Assets

local SplashScreenRE = Net:RemoteEvent("SplashScreen")

local localPlayer = Players.LocalPlayer

local SplashUI = Assets.UI.SplashUI:Clone()
SplashUI.Parent = localPlayer.PlayerGui

local splashTweenInfo = TweenInfo.new(0.34, Enum.EasingStyle.Linear)

local splashTween = TweenService:Create(SplashUI.Main, splashTweenInfo, { Size = UDim2.fromScale(1, 2), Rotation = 360 })
local unsplashTween = TweenService:Create(SplashUI.Main, splashTweenInfo, { Size = UDim2.fromScale(0, 0), Rotation = 0 })

local function splashScreen(splash)
	if splash == true then
		splashTween:Play()
	else
		unsplashTween:Play()
	end
end

SplashScreenRE.OnClientEvent:Connect(splashScreen)

return splashScreen
