local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local Net = require(ReplicatedStorage.Packages.Net)

local Assets = ReplicatedStorage.Assets
local BuildMapRE = Net:RemoteEvent("BuildMap")

-- List of read-only or server-only properties to skip
local READ_ONLY_PROPERTIES = {
	"AssemblyMass",
	"AssemblyLinearVelocity",
	"AssemblyAngularVelocity",
	"PivotOffset",
	"Rotation",
	"PrimaryPart",
	"Mass",
	"Size",
	"Position",
	"Orientation",
}

-- Safely set property
local function safeSetProperty(inst, propName, value)
	if table.find(READ_ONLY_PROPERTIES, propName) then return end
	if inst[propName] == nil then return end
	pcall(function()
		inst[propName] = value
	end)
end

-- Convert serialized value back to Roblox type
local function deserializeValue(value, propName)
	if typeof(value) ~= "table" then return value end
	if propName == "Size" then
		return Vector3.new(value.x, value.y, value.z)
	elseif propName == "CFrame" and value.position then
		local pos = Vector3.new(value.position.x, value.position.y, value.position.z)
		local look = Vector3.new(value.lookVector.x, value.lookVector.y, value.lookVector.z)
		local up = Vector3.new(value.upVector.x, value.upVector.y, value.upVector.z)
		local right = look:Cross(up).Unit
		local correctedUp = right:Cross(look).Unit
		return CFrame.fromMatrix(pos, right, correctedUp, -look)
	elseif propName == "Color" then
		return Color3.new(value.r, value.g, value.b)
	elseif propName == "Material" then
		return Enum.Material[value] or Enum.Material.Plastic
	else
		return value
	end
end

-- Recursively build instances
local function buildInstance(data, parent)
	local inst = Instance.new(data.ClassName)
	inst.Name = data.Name
	inst.Parent = parent

	for propName, value in pairs(data.Properties) do
		safeSetProperty(inst, propName, deserializeValue(value, propName))
	end

	for _, childData in ipairs(data.Children) do
		buildInstance(childData, inst)
	end

	-- Set PrimaryPart if model
	if inst:IsA("Model") and data.Properties.PrimaryPart then
		local primary = inst:FindFirstChild(data.Properties.PrimaryPart)
		if primary then inst.PrimaryPart = primary end
	end

	return inst
end

-- Handle incoming remote event
BuildMapRE.OnServerEvent:Connect(function(player, mapName, mapData)
	if not CommandsUtils.CheckForPermission(player, { "Admin" }) then
		warn(player.Name .. " tried building map without permission")
		return
	end

	if Assets.Maps:FindFirstChild(mapName) then return end

	if typeof(mapData) == "string" then mapData = HttpService:JSONDecode(mapData) end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = mapName
	mapFolder.Parent = Assets.Maps

	for _, data in ipairs(mapData) do
		buildInstance(data, mapFolder)
	end

	print("Map built successfully:", mapName)
end)

return 0
