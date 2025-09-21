local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local ChangeMap = require(ServerStorage.Modules.Maps.ChangeMap)
local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)

local MapAssets = ReplicatedStorage.Assets.Maps

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
	"Playtester",
}

local function getMapModel(name)
	if not name then return nil end
	name = name:lower()

	for _, obj in MapAssets:GetChildren() do
		if obj:IsA("Folder") and obj.Name:lower() == name then return obj end
	end

	return nil
end

return TextChatService.TextChatCommands.ChangeMap.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	if not RunService:IsStudio() and not CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand) then return end

	local mapModel = getMapModel(parameters[1])
	if not mapModel then return end

	ChangeMap(mapModel)
end)
