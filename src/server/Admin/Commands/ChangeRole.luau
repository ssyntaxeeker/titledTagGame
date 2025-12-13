local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local canUseCommand = {
	"Admin",
	"PrivateServerOwner",
}

return TextChatService.TextChatCommands.ChangeRole.Triggered:Connect(function(source, command)
	local parameters = CommandsUtils.ParseCommand(command)
	if not parameters then return end

	local player = CommandsUtils.AutocompletePlayer(parameters[1])
	if not player then return end

	local permission = CommandsUtils.CheckForPermission(Players:GetPlayerByUserId(source.UserId), canUseCommand)
	if not RunService:IsStudio() and not permission then return end

	if not parameters[2] then return end

	local role

	for _, roleModule in ReplicatedStorage.Shared.Configs.Roles:GetChildren() do
		if roleModule.Name:lower() == parameters[2]:lower() then
			role = roleModule.Name

			break
		end
	end

	RolesFunctions.ChangeRole(player, role)
end)
