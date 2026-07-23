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

	if newGamemode == "RankedClassic" or newGamemode == "CheckpointEscape" then
		Main.LeadingRunner.Visible = true
	else
		Main.LeadingRunner.Visible = false
	end
	if newGamemode == "CheckpointEscape" then
		local standings = workspace:GetAttribute("CheckpointStandings")
		Main.LeadingRunner.Text = if type(standings) == "string" and standings ~= ""
			then standings
			else "waiting for runners..."
	end
end

local function syncTimeLeft()
	local timeLeft = workspace:GetAttribute("TimeLeft")
	local gamemode = workspace:GetAttribute("Gamemode")
	if not timeLeft or not gamemode then return end

	if timeLeft == -1 and gamemode == "RankedFFA" then
		local killsToWin = ReplicatedStorage:GetAttribute("RankedFFAKillsToWin")
		Main.TimeLeft.Text = if type(killsToWin) == "number"
			then `first to {killsToWin} kills`
			else "kill-limited FFA"
	else
		local displayTime = math.max(0, math.ceil(timeLeft))
		Main.TimeLeft.Text = if timeLeft == -1 then "time hidden lol" else `time left: {displayTime}s`
	end

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

local function syncModeStatus()
	local status = workspace:GetAttribute("ModeStatus")
	if type(status) == "string" and status ~= "" then Main.GameDesc.Text = status end
end

local function syncScore(scores)
	local lpId = tostring(localPlayer.UserId)
	local lpScore = tostring(scores[localPlayer.UserId] or scores[lpId] or 0)
	local parts = {}

	for userId, score in scores do
		if tostring(userId) ~= lpId then table.insert(parts, tostring(score or 0)) end
	end

	for i = #parts, 2, -1 do
		local j = math.random(1, i)
		parts[i], parts[j] = parts[j], parts[i]
	end

	table.insert(parts, 1, lpScore)

	Main.Score.Text = table.concat(parts, " - ")
	Main.Score.Visible = true
end

local function updateLeadRunner(runner: string, difference: number)
	if workspace:GetAttribute("Gamemode") ~= "RankedClassic" then return end
	local roundedDifference = math.round(difference)
	local sign = if roundedDifference >= 0 then "+" else ""
	Main.LeadingRunner.Text = `{runner} is leading on time! ({sign}{roundedDifference}s)`
end

local function syncCheckpointStandings()
	if workspace:GetAttribute("Gamemode") ~= "CheckpointEscape" then return end
	local standings = workspace:GetAttribute("CheckpointStandings")
	Main.LeadingRunner.Text = if type(standings) == "string" and standings ~= ""
		then standings
		else "waiting for runners..."
end

workspace:GetAttributeChangedSignal("Gamemode"):Connect(syncGamemode)
workspace:GetAttributeChangedSignal("TimeLeft"):Connect(syncTimeLeft)
workspace:GetAttributeChangedSignal("ModeStatus"):Connect(syncModeStatus)
workspace:GetAttributeChangedSignal("CheckpointStandings"):Connect(syncCheckpointStandings)

UpdateClientScoresRE.OnClientEvent:Connect(syncScore)
UpdateLeadRunnerRE.OnClientEvent:Connect(updateLeadRunner)

local function initializeAttributes()
	syncGamemode()
	syncTimeLeft()
	syncModeStatus()
end

return Schedules.Boot.job(initializeAttributes)
