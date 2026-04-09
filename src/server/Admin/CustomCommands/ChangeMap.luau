local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local CommandRegistry = require(ServerStorage.Modules.Chat.Commands.CommandRegistry)
local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)

local MapAssets = ReplicatedStorage.Assets.Maps

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
}

local function getMapModel(name)
	if not name then return nil end
	name = name:lower()

	for _, obj in MapAssets:GetChildren() do
		if obj:IsA("Folder") and obj.Name:lower() == name then return obj end
	end

	return nil
end

return CommandRegistry.RegisterCommand("map", function(sender, mapName)
	if not mapName then return end

	local permission = CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(sender.UserId), canUseCommand)
	if not RunService:IsStudio() and not permission then return end

	local mapModel = getMapModel(mapName)
	if not mapModel then return end

	ChangeMap(mapModel)
end)
