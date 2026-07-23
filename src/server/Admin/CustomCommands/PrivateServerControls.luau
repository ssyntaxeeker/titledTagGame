--!strict
--[[
    PrivateServerControls (Server custom chat)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Makes the core private-server movement and role controls available through
    the custom command registry as well as Roblox TextChatCommands.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CommandRegistry = require(ServerStorage.Modules.Chat.Commands.CommandRegistry)
local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local function authorized(sender: Player): boolean
	return CommandsUtils.CheckForPermission(sender, { "Admin", "PrivateServerOwner" })
end

CommandRegistry.RegisterCommand("bring", function(sender: Player, playerName: string?)
	if not authorized(sender) then return end
	local target = CommandsUtils.AutocompletePlayer(playerName)
	if not target or not sender.Character or not target.Character then return end
	local senderRoot = sender.Character:FindFirstChild("HumanoidRootPart")
	if not senderRoot or not senderRoot:IsA("BasePart") then return end
	target.Character:PivotTo(senderRoot.CFrame)
end)

CommandRegistry.RegisterCommand("goto", function(sender: Player, playerName: string?)
	if not authorized(sender) then return end
	local target = CommandsUtils.AutocompletePlayer(playerName)
	if not target or not sender.Character or not target.Character then return end
	local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not targetRoot:IsA("BasePart") then return end
	sender.Character:PivotTo(targetRoot.CFrame)
end)

CommandRegistry.RegisterCommand("role", function(sender: Player, playerName: string?, roleName: string?)
	if not authorized(sender) or typeof(roleName) ~= "string" then return end
	local target = CommandsUtils.AutocompletePlayer(playerName)
	if not target then return end
	local resolvedRole: string? = nil
	for _, roleModule in ReplicatedStorage.Shared.Configs.Roles:GetChildren() do
		if roleModule:IsA("ModuleScript") and roleModule.Name:lower() == roleName:lower() then
			resolvedRole = roleModule.Name
			break
		end
	end
	if resolvedRole then RolesFunctions.ChangeRole(target, resolvedRole) end
end)

return 0
