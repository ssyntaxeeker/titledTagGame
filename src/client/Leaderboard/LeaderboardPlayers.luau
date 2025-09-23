local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LeaderboardFunctions = require(ReplicatedStorage.Modules.Leaderboard.LeaderboardFunctions)
local RankColors = require(ReplicatedStorage.Shared.Configs.RankColors)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local StarsColors = require(ReplicatedStorage.Shared.Configs.StarsColors)

local _, ScrollFrame = LeaderboardFunctions.GetUI()
local UIListLayout = ScrollFrame:WaitForChild("UIListLayout")
local PlayerTemplate = UIListLayout:WaitForChild("PlayerTemplate")
local RoleTemplate = UIListLayout:WaitForChild("RoleTemplate")

local playerRows = {}
local roleHeaders = {}

local cachedThumbnails = {}

local function getRoleConfig(roleName)
	local rolesFolder = ReplicatedStorage.Shared.Configs.Roles

	local moduleObj = rolesFolder:FindFirstChild(roleName)
	if not moduleObj then return nil end

	local ok, config = pcall(require, moduleObj)
	if not ok or type(config) ~= "table" then return nil end

	return config
end

local function ensureRoleHeader(roleName, playerCount)
	if roleHeaders[roleName] then
		local header = roleHeaders[roleName]
		header.gamemode.Text = string.format("%s - %d", roleName:upper(), playerCount)
		return header
	end

	local header = RoleTemplate:Clone()
	header.Name = "Role_" .. roleName
	header.Visible = true
	header.Parent = ScrollFrame

	local config = getRoleConfig(roleName)
	local roleColor = (config and config.Color) or Color3.new(1, 1, 1)

	header.BackgroundColor3 = roleColor

	--[[local light1 = lerpColor(roleColor, Color3.new(1, 1, 1), 0.15)
	local light2 = lerpColor(roleColor, Color3.new(1, 1, 1), 0.3)
	local light3 = lerpColor(roleColor, Color3.new(1, 1, 1), 0.85)

	if header:FindFirstChild("UIGradient") then
		header.UIGradient.Color = ColorSequence.new {
			ColorSequenceKeypoint.new(0, roleColor),
			ColorSequenceKeypoint.new(0.4, light1),
			ColorSequenceKeypoint.new(0.95, light2),
			ColorSequenceKeypoint.new(1, light3),
		}
	end--]]

	if header:FindFirstChild("gamemode") then header.gamemode.Text = string.format("%s - %d", roleName:upper(), playerCount) end

	roleHeaders[roleName] = header
	return header, roleColor
end

local function pickBadgeImage(subject)
	if subject:GetAttribute("Dev") then return "rbxassetid://111274839439490" end
	if subject:GetAttribute("Mod") then return "rbxassetid://78957964972625" end
	if subject:GetAttribute("VIP") then return "rbxassetid://85292019066930" end

	local inGroup = subject:GetAttribute("InGroup")

	if typeof(inGroup) == "number" and inGroup > 1 then return "rbxassetid://18759179531" end

	return nil
end

local function createRow(player)
	if playerRows[player] then return playerRows[player] end
	local row = PlayerTemplate:Clone()
	row.Name = "Player_" .. player.Name
	row.Visible = true
	row.Parent = ScrollFrame
	playerRows[player] = row
	return row
end

local function updateRow(player)
	local row = playerRows[player] or createRow(player)
	row.username.Text = player.DisplayName or player.Name

	local stars = tonumber(player:GetAttribute("Stars"))
	row.Stats.stars.starsText.Text = stars or 0
	row.Stats.stars.ImageColor3 = StarsColors[math.floor(stars or 0)] or StarsColors[1]

	local rank = player:GetAttribute("Rank")
	row.Stats.rank.rankText.Text = rank or "C"
	row.Stats.rank.ImageColor3 = RankColors[rank] or RankColors["C"]

	row.Stats.tags.Text = tostring(player:GetAttribute("Tags") or 0)
	row.Stats.elo.Text = tostring(player:GetAttribute("ELO") or 0)

	row.ImageColor3 = getRoleConfig(player.Character and player.Character:GetAttribute("Role") or "Runner").Color

	local badge = pickBadgeImage(player)

	local playerIcon = row:FindFirstChild("playerIcon")

	if playerIcon and playerIcon.badge then
		playerIcon.badge.Visible = badge ~= nil
		if badge then playerIcon.badge.Image = badge end
	end

	local thumbnail = cachedThumbnails[player.UserId]

	if not thumbnail then
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
		end)
		if ok and content then
			cachedThumbnails[player.UserId] = content
			thumbnail = content
		end
	end

	if thumbnail and playerIcon then playerIcon.Image = thumbnail end
end

local function rebuildLeaderboard()
	for _, row in playerRows do
		if row then row:Destroy() end
	end
	playerRows = {}

	for _, header in roleHeaders do
		if header then header:Destroy() end
	end
	roleHeaders = {}

	local roleGroups = {}
	for _, player in Players:GetPlayers() do
		local role = player.Character and player.Character:GetAttribute("Role") or "None"

		roleGroups[role] = roleGroups[role] or {}
		table.insert(roleGroups[role], player)
	end

	local sortedRoles = {}
	for roleName, players in roleGroups do
		table.insert(sortedRoles, { role = roleName, players = players })
	end

	table.sort(sortedRoles, function(a, b)
		return #a.players > #b.players
	end)

	local layoutOrder = 0

	for _, group in sortedRoles do
		layoutOrder += 1
		local roleName = group.role
		local header, roleColor = ensureRoleHeader(roleName, #group.players)
		header.LayoutOrder = layoutOrder

		table.sort(group.players, function(a, b)
			return (a:GetAttribute("Tags") or 0) > (b:GetAttribute("Tags") or 0)
		end)

		for _, player in group.players do
			layoutOrder += 1
			local row = createRow(player)
			row.LayoutOrder = layoutOrder
			updateRow(player)
			if row:IsA("Frame") then row.ImageColor3 = roleColor end
		end
	end
end

local function connectCharacter(character)
	character:GetAttributeChangedSignal("Role"):Connect(rebuildLeaderboard)
	rebuildLeaderboard()
end

local function connectPlayer(player)
	player:GetAttributeChangedSignal("Rank"):Connect(rebuildLeaderboard)
	player:GetAttributeChangedSignal("ELO"):Connect(rebuildLeaderboard)
	player:GetAttributeChangedSignal("Stars"):Connect(rebuildLeaderboard)

	player.CharacterAdded:Connect(connectCharacter)

	local character = player.Character
	if character then connectCharacter(character) end
	rebuildLeaderboard()
end

local function init()
	Players.PlayerAdded:Connect(connectPlayer)
	Players.PlayerRemoving:Connect(rebuildLeaderboard)

	for _, player in Players:GetPlayers() do
		connectPlayer(player)
	end
	rebuildLeaderboard()
end

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

return {
	BootJob = Schedules.Boot.job(init),
	Update = rebuildLeaderboard,
}
