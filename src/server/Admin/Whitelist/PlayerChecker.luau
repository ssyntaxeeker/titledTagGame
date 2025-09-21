local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local CommandsUtils = require(ServerStorage.Modules.Admin.Commands.CommandsUtils)
local Net = require(ReplicatedStorage.Packages.Net)
local Whitelist = require(ReplicatedStorage.Shared.Configs.Whitelist)

local ToggleChatRE = Net:RemoteEvent("ToggleChat")

local checkerProperties = { whitelist = 0 }

Players.PlayerAdded:Connect(function(player)
	if
		not CommandsUtils.CheckForPermission(player, { "Playtester", "Admin" }) and (checkerProperties.whitelist == 1 and not RunService:IsStudio())
	then
		print("Kicked " .. player.Name)
		player:Kick("[WHITELIST ON] You are not allowed here yet (Tester+ only)")
	else
		local userRole = CommandsUtils.GetPlayerPermission(player, Whitelist)

		if userRole == "Playtester" then
			player:SetAttribute("VIP", true)
		elseif userRole == "Moderator" then
			player:SetAttribute("Mod", true)
		elseif userRole == "Admin" then
			player:SetAttribute("Dev", true)
		end
	end

	if not CommandsUtils.CheckForPermission(player, { "Admin", "Playtester", "PrivateServerOwner", "ChatPerms" }) then
		ToggleChatRE:FireClient(player, false)
	end
end)

return checkerProperties
