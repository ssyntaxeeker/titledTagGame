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
	if gamemodeConfig.UIImage then
		Main.Gamemode.GamemodeIcon1.Image = gamemodeConfig.UIImage
		Main.Gamemode.GamemodeIcon2.Image = gamemodeConfig.UIImage
	end
	Main.GameDesc.Text = gamemodeConfig.Descriptions[math.random(1, #gamemodeConfig.Descriptions)]
end

local function syncTimeLeft()
	local timeLeft = workspace:GetAttribute("TimeLeft")
	local gamemode = workspace:GetAttribute("Gamemode")
	if not timeLeft or not gamemode then return end

	Main.TimeLeft.Text = if timeLeft == -1 then "time hidden lol" else `time left: {timeLeft}s`

	local roundSoundAssets = Assets.Sounds.Round

	if timeLeft <= 3 and timeLeft > 0 and not roundSoundAssets.Boom.IsPlaying then
		roundSoundAssets.Boom:Play()
		roundSoundAssets.BuildUp:Play()
	elseif timeLeft == 0 then
		local winningRole = require(ReplicatedStorage.Shared.Configs.Modes[gamemode]).winRole
		local role = localPlayer.Character and localPlayer.Character:GetAttribute("Role")

		roundSoundAssets.Boom:Stop()

		if winningRole and role and role == winningRole then roundSoundAssets.Cheer:Play() end
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
