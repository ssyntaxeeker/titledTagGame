local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local RoundStatusUI = Assets.UI.RoundStatusUI:Clone()
RoundStatusUI.Parent = localPlayer.PlayerGui

local Main = RoundStatusUI.Main

local function syncGamemode()
	local newGamemode = workspace:GetAttribute("Gamemode")
	if newGamemode == nil then return end

	local gamemodeConfig = require(ReplicatedStorage.Shared.Configs.Modes[newGamemode])

	Main.Gamemode.Text = gamemodeConfig.Name
	Main.Gamemode.GamemodeGlow.ImageColor3 = gamemodeConfig.UIGlow
	Main.GameDesc.Text = gamemodeConfig.Descriptions[math.random(1, #gamemodeConfig.Descriptions)]
end

local function syncTimeLeft()
	local timeLeft = workspace:GetAttribute("TimeLeft")

	Main.TimeLeft.Text = if timeLeft == -1 then "time hidden lol" else `time left: {timeLeft}s`

	local roundSoundAssets = Assets.Sounds.Round

	if timeLeft == 7 then roundSoundAssets.Boom:Play() end

	if timeLeft == 0 then
		roundSoundAssets.Cheer:Play()
		roundSoundAssets.Ended:Play()
	end
end

workspace:GetAttributeChangedSignal("Gamemode"):Connect(syncGamemode)
workspace:GetAttributeChangedSignal("TimeLeft"):Connect(syncTimeLeft)

local function initializeAttributes()
	syncGamemode()
	syncTimeLeft()
end

return Schedules.Boot.job(initializeAttributes)
