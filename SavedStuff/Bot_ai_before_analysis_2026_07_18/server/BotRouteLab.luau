--!strict
--[[
    BotRouteLab (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Owns replicated route-test start/goal markers and authoritative cycling.
    Clients evaluate these markers with the shared affordance pathfinder.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local Net = require(ReplicatedStorage.Packages.Net)

local RouteLabCount = Net:RemoteEvent("BotRouteLabCount")

local routeFolder: Folder? = nil
local connections: { RBXScriptConnection } = {}

local function trustedPlayersPresent(): boolean
	for _, player in Players:GetPlayers() do
		if BotAccess.userIds[player.UserId] == true then return true end
	end
	return false
end

local function clearConnections()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

local function surfacePosition(map: Instance, position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.IgnoreWater = true
	local result = Workspace:Raycast(position + Vector3.yAxis * 100, -Vector3.yAxis * 220, params)
	return if result then result.Position + Vector3.yAxis * 2.75 else position
end

local function marker(folder: Folder, name: string, position: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * 2.5
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = 0.15
	part.Anchored = true
	part.CanCollide = false
	part.Parent = folder
	local drag = Instance.new("DragDetector")
	drag.Parent = part
	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(150, 28)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	billboard.Parent = part
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.Text = name
	text.TextColor3 = color
	text.TextSize = 14
	text.TextStrokeTransparency = 0.2
	text.Parent = billboard
	return part
end

local function createLab()
	if not trustedPlayersPresent() then return end
	local map = Workspace:FindFirstChild("Map")
	if not map then return end
	clearConnections()
	if routeFolder then routeFolder:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "BotRouteLab"
	folder:SetAttribute("RouteIndex", 1)
	folder:SetAttribute("RouteCount", 0)
	folder:SetAttribute("Revision", 1)
	folder.Parent = Workspace
	routeFolder = folder
	local center: Vector3
	local size: Vector3
	if map:IsA("Model") then
		local cframe, bounds = map:GetBoundingBox()
		center = cframe.Position
		size = bounds
	elseif map:IsA("BasePart") then
		center = map.Position
		size = map.Size
	else
		local firstPart = map:FindFirstChildWhichIsA("BasePart", true)
		center = if firstPart then firstPart.Position else Vector3.zero
		size = Vector3.new(80, 20, 80)
	end
	local separation = math.clamp(math.max(size.X, size.Z) * 0.2, 18, 55)
	local start = marker(folder, "Start", surfacePosition(map, center - Vector3.xAxis * separation), Color3.fromRGB(45, 255, 100))
	local goal = marker(folder, "Goal", surfacePosition(map, center + Vector3.xAxis * separation), Color3.fromRGB(255, 65, 65))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Cycle Route"
	prompt.ObjectText = "Route Lab"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = goal
	connections[#connections + 1] = prompt.Triggered:Connect(function(player)
		if BotAccess.userIds[player.UserId] ~= true then return end
		local count = folder:GetAttribute("RouteCount")
		local routeCount = if typeof(count) == "number" then math.max(1, count) else 1
		local current = folder:GetAttribute("RouteIndex")
		local routeIndex = if typeof(current) == "number" then current else 1
		folder:SetAttribute("RouteIndex", routeIndex % routeCount + 1)
	end)
	local function changed()
		local revision = folder:GetAttribute("Revision")
		folder:SetAttribute("Revision", (if typeof(revision) == "number" then revision else 0) + 1)
	end
	connections[#connections + 1] = start:GetPropertyChangedSignal("Position"):Connect(changed)
	connections[#connections + 1] = goal:GetPropertyChangedSignal("Position"):Connect(changed)
end

Players.PlayerAdded:Connect(function(player)
	if BotAccess.userIds[player.UserId] == true then task.defer(createLab) end
end)
Players.PlayerRemoving:Connect(function()
	task.defer(function()
		if trustedPlayersPresent() then return end
		clearConnections()
		if routeFolder then routeFolder:Destroy() end
		routeFolder = nil
	end)
end)
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Map" then task.defer(createLab) end
end)
task.defer(createLab)

RouteLabCount.OnServerEvent:Connect(function(player, count)
	if BotAccess.userIds[player.UserId] ~= true or typeof(count) ~= "number" then return end
	local folder = Workspace:FindFirstChild("BotRouteLab")
	if not folder then return end
	folder:SetAttribute("RouteCount", math.clamp(math.floor(count), 0, 4))
	folder:SetAttribute("RouteIndex", 1)
end)

return 0
