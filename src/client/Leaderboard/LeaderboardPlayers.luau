local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local LeaderboardFunctions = require(script.Parent.LeaderboardFunctions)

local _, _, ScrollFrame = LeaderboardFunctions.GetUI()
local UIListLayout = ScrollFrame:WaitForChild("UIListLayout")
local PlayerTemplate = UIListLayout:WaitForChild("PlayerTemplate")
local RoleTemplate = UIListLayout:WaitForChild("RoleTemplate")

local TweenInfoHover = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local playerRows = {}
local playerConnections = {}
local roleHeaders = {}
local roleOrderMap = {}
local nextRoleBase = 1

local function safeTween(target, info, props)
	local ok, t = pcall(function()
		return TweenService:Create(target, info, props)
	end)
	if not ok or not t then return end
	t:Play()
	return t
end

local function lerpColor(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function formatTagsNumber(n)
	n = math.floor(n or 0)
	local s = tostring(n)
	while #s < 4 do
		s = "0" .. s
	end
	return s
end

local function getRoleNameForSubject(subject)
	local character
	if subject:IsA("Player") then
		character = subject.Character
	else
		character = subject
	end
	if not character then return nil end
	local roleName = character:GetAttribute("Role")
	if not roleName or roleName == "" then return nil end
	return roleName
end

local function getRoleConfig(roleName)
	if not roleName then return nil end
	local rolesFolder = ReplicatedStorage:FindFirstChild("Shared")
		and ReplicatedStorage.Shared:FindFirstChild("Configs")
		and ReplicatedStorage.Shared.Configs:FindFirstChild("Roles")
	if not rolesFolder then return nil end
	local moduleObj = rolesFolder:FindFirstChild(roleName)
	if not moduleObj then return nil end
	local ok, config = pcall(require, moduleObj)
	if not ok or type(config) ~= "table" then return nil end
	return config
end

local function ensureRoleHeader(roleName)
	if not roleName then return nil end
	if roleHeaders[roleName] then return roleHeaders[roleName] end

	local header = RoleTemplate:Clone()
	header.Name = "Role_" .. roleName
	header.Visible = true
	header.Parent = ScrollFrame

	local base = roleOrderMap[roleName] or nextRoleBase
	if not roleOrderMap[roleName] then
		roleOrderMap[roleName] = base
		nextRoleBase = nextRoleBase + 1000
	end

	header.LayoutOrder = roleOrderMap[roleName]
	local config = getRoleConfig(roleName)
	local roleColor = (config and config.Color) or Color3.new(1, 1, 1)
	local light1 = lerpColor(roleColor, Color3.new(1, 1, 1), 0.15)
	local light2 = lerpColor(roleColor, Color3.new(1, 1, 1), 0.3)
	local light3 = lerpColor(roleColor, Color3.new(1, 1, 1), 0.85)
	if header:FindFirstChild("UIGradient") then
		header.UIGradient.Color = ColorSequence.new {
			ColorSequenceKeypoint.new(0, roleColor),
			ColorSequenceKeypoint.new(0.4, light1),
			ColorSequenceKeypoint.new(0.95, light2),
			ColorSequenceKeypoint.new(1, light3),
		}
	end
	local label = header:FindFirstChild("gamemodename")
	local text = roleName .. "s"

	if config ~= nil and typeof(config.Plural) == "string" then text = config.Plural end
	if label then label.Text = text end
	roleHeaders[roleName] = header
	return header
end

local function removeRoleHeaderIfEmpty(roleName)
	if not roleName or not roleHeaders[roleName] then return end
	for _, row in pairs(playerRows) do
		local rrole = getRoleNameForSubject(row._subject)
		if rrole == roleName then return end
	end
	roleHeaders[roleName]:Destroy()
	roleHeaders[roleName] = nil
end

local function applyHover(row, hover)
	if not row then return end
	if hover then
		safeTween(row.NameFrame.displayname, TweenInfoHover, { TextTransparency = 1 })
		if row.NameFrame.displayname:FindFirstChild("UIStroke") then
			safeTween(row.NameFrame.displayname.UIStroke, TweenInfoHover, { Transparency = 1 })
		end
		safeTween(row.NameFrame.level, TweenInfoHover, { TextTransparency = 1 })
	else
		safeTween(row.NameFrame.displayname, TweenInfoHover, { TextTransparency = 0 })
		if row.NameFrame.displayname:FindFirstChild("UIStroke") then
			safeTween(row.NameFrame.displayname.UIStroke, TweenInfoHover, { Transparency = 0 })
		end
		safeTween(row.NameFrame.level, TweenInfoHover, { TextTransparency = 0 })
	end
end

local function createRow(subject)
	local row = PlayerTemplate:Clone()
	row.Visible = false
	row.Name = "Player_" .. (subject.Name or "Unknown")
	row.Parent = ScrollFrame

	playerRows[subject] = row
	if row.NameFrame and row.NameFrame.displayname then
		row.NameFrame.displayname.MouseEnter:Connect(function()
			applyHover(row, true)
		end)
		row.NameFrame.displayname.MouseLeave:Connect(function()
			applyHover(row, false)
		end)
	end
	return row
end

local function setPlayerThumbnail(row, subject)
	if not subject or not subject:IsA("Player") then return end
	local userId = subject.UserId
	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size48x48
	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
	end)
	if ok and content then
		if row.playericon and row.playericon:IsA("ImageLabel") then row.playericon.Image = content end
	end
end

local function pickBadgeImage(subject)
	local img
	local inGroup = subject.GetAttribute and subject:GetAttribute("InGroup")

	if inGroup and type(inGroup) == "number" and inGroup > 1 then img = "rbxassetid://18759179531" end
	if subject.GetAttribute and subject:GetAttribute("VIP") then img = "rbxassetid://18772350480" end
	if subject.GetAttribute and (subject:GetAttribute("Mod") or subject:GetAttribute("Admin")) then img = "rbxassetid://18759169432" end
	if subject.GetAttribute and subject:GetAttribute("Dev") then img = "rbxassetid://12318465145" end

	return img
end

local function ensureAllRows()
	for _, player in Players:GetPlayers() do
		if not playerRows[player] and player.Character then createRow(player) end
	end
end

local function recomputeAllRoles()
	ensureAllRows()

	local roleGroups = {}

	for player, row in playerRows do
		local char = player.Character
		local role = (char and char:GetAttribute("Role"))
		if not role then continue end

		if not roleGroups[role] then roleGroups[role] = {} end
		table.insert(roleGroups[role], row)
	end

	for roleName, header in roleHeaders do
		if not roleGroups[roleName] or #roleGroups[roleName] == 0 then
			header:Destroy()
			roleHeaders[roleName] = nil
		end
	end

	local layoutOrder = 0
	for roleName, rows in roleGroups do
		local header = ensureRoleHeader(roleName)
		header.gamemodename.Text = (getRoleConfig(roleName).Plural or (roleName .. "s")):upper() .. " - " .. tostring(#rows)
		roleHeaders[roleName] = header
		layoutOrder = layoutOrder + 1
		header.LayoutOrder = layoutOrder

		for _, row in rows do
			layoutOrder = layoutOrder + 1
			row.LayoutOrder = layoutOrder
			row.ImageColor3 = getRoleConfig(roleName).Color or Color3.new(1, 1, 1)
		end
	end
end

local function updateRow(player)
	if not playerRows[player] then createRow(player) end
	local row = playerRows[player]
	row.Visible = true

	if row.Stats and row.Stats.username then row.Stats.username.Text = "@" .. (player.Name or "Unknown") end

	local displayName = player.DisplayName or player.Name or "Unknown"
	local premium = (player.MembershipType == Enum.MembershipType.Premium) and (utf8.char(57345) .. " ") or ""
	if row.NameFrame and row.NameFrame.displayname then row.NameFrame.displayname.Text = premium .. displayName end

	local leaderstats = player:FindFirstChild("leaderstats")
	local rankObj = leaderstats and leaderstats:FindFirstChild("rank")
	local tagsObj = leaderstats and leaderstats:FindFirstChild("tags")

	if row.NameFrame and row.NameFrame.level then row.NameFrame.level.Text = rankObj and ("rank " .. tostring(rankObj.Value)) or "" end

	if row.Stats and row.Stats.tags then
		row.Stats.tags.Visible = tagsObj and true or false
		if tagsObj then row.Stats.tags.Text = formatTagsNumber(tagsObj.Value) end
	end

	local badge = pickBadgeImage(player)
	if row.playericon and row.playericon.icon then
		row.playericon.icon.Visible = badge ~= nil
		if badge then row.playericon.icon.Image = badge end
	end

	if row.playericon then setPlayerThumbnail(row, player) end

	recomputeAllRoles()
end

local function removePlayer(player)
	if playerRows[player] then
		playerRows[player]:Destroy()
		playerRows[player] = nil
	end
	if playerConnections[player] then
		for i = 1, #playerConnections[player] do
			local c = playerConnections[player][i]
			if c and c.Disconnect then c:Disconnect() end
		end
		playerConnections[player] = nil
	end
end

local function connect(player)
	if playerRows[player] then return end

	local conns = {}
	playerConnections[player] = conns

	local function bindCharacter(character)
		if not character then return end
		updateRow(player)

		local roleConn = character:GetAttributeChangedSignal("Role"):Connect(function()
			updateRow(player)
		end)
		table.insert(conns, roleConn)
	end

	table.insert(
		conns,
		player.CharacterAdded:Connect(function(char)
			bindCharacter(char)
		end)
	)

	if player.Character then bindCharacter(player.Character) end

	local leaderstats = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 15)
	if leaderstats then
		local rank = leaderstats:FindFirstChild("rank")
		local tags = leaderstats:FindFirstChild("tags")

		if rank then table.insert(
			conns,
			rank.Changed:Connect(function()
				updateRow(player)
			end)
		) end

		if tags then
			table.insert(
				conns,
				tags.Changed:Connect(function()
					updateRow(player)
				end)
			)
			table.insert(
				conns,
				tags:GetAttributeChangedSignal("TagStreak"):Connect(function()
					updateRow(player)
				end)
			)
		end
	end

	table.insert(
		conns,
		player.AncestryChanged:Connect(function()
			if not player:IsDescendantOf(workspace) then removePlayer(player) end
		end)
	)

	updateRow(player)
end

local function disconnect(player)
	if playerConnections[player] then
		for _, conn in ipairs(playerConnections[player]) do
			if conn and conn.Disconnect then conn:Disconnect() end
		end
		playerConnections[player] = nil
	end
	removePlayer(player)
end

local function updateList()
	for p, _ in pairs(playerRows) do
		if not p or (p:IsA("Instance") and not p.Parent) then removePlayer(p) end
	end
	for roleName, _ in pairs(roleHeaders) do
		removeRoleHeaderIfEmpty(roleName)
	end
end

for _, player in Players:GetPlayers() do
	connect(player)
end

Players.PlayerAdded:Connect(connect)
Players.PlayerRemoving:Connect(disconnect)

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

return {
	UpdateRow = updateRow,
	Connect = connect,
	Disconnect = disconnect,
	UpdateList = updateList,
}
