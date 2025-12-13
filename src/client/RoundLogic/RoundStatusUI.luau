local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets

local UpdateClientScoresRE = Net:RemoteEvent("UpdateClientScores")
local UpdateLeadRunnerRE = Net:RemoteEvent("UpdateLeadRunner")

local localPlayer = Players.LocalPlayer

local RoundStatusUI = Assets.UI.RoundStatusUI:Clone()
RoundStatusUI.Parent = localPlayer.PlayerGui

local Main = RoundStatusUI.Main

local roundSoundAssets = Assets.Sounds.Round

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

	if newGamemode == "RankedClassic" then
		Main.LeadingRunner.Visible = true
	else
		Main.LeadingRunner.Visible = false
	end
end

local function syncTimeLeft()
	local timeLeft = workspace:GetAttribute("TimeLeft")
	local gamemode = workspace:GetAttribute("Gamemode")
	if not timeLeft or not gamemode then return end

	Main.TimeLeft.Text = if timeLeft == -1 then "time hidden lol" else `time left: {timeLeft}s`

	if gamemode == "Voting" then return end

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

local function syncScore(scores)
	local lpId = tostring(localPlayer.UserId)
	local lpScore = tostring(scores[lpId] or 0)
	local parts = {}

	for userId, score in scores do
		if userId ~= lpId then table.insert(parts, tostring(score or 0)) end
	end

	for i = #parts, 2, -1 do
		local j = math.random(1, i)
		parts[i], parts[j] = parts[j], parts[i]
	end

	table.insert(parts, 1, lpScore)

	Main.Score.Text = table.concat(parts, " - ")
	Main.Score.Visible = true
end

local function updateLeadRunner(runner)
	Main.LeadingRunner.Text = runner .. " is leading on time!"
end

workspace:GetAttributeChangedSignal("Gamemode"):Connect(syncGamemode)
workspace:GetAttributeChangedSignal("TimeLeft"):Connect(syncTimeLeft)

UpdateClientScoresRE.OnClientEvent:Connect(syncScore)
UpdateLeadRunnerRE.OnClientEvent:Connect(updateLeadRunner)

local function initializeAttributes()
	syncGamemode()
	syncTimeLeft()
end

return Schedules.Boot.job(initializeAttributes)
