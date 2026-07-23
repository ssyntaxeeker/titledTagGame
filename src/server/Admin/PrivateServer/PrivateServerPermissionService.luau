--!strict
--[[
    PrivateServerPermissionService (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/19

    Owns command delegates for the lifetime of the current private server.
    Grants are intentionally not persisted between server instances.
]]

local PrivateServerPermissionService = {}
local delegates: { [number]: boolean } = {}
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Whitelist = require(ReplicatedStorage.Shared.Configs.Whitelist)

function PrivateServerPermissionService.isPrivateServer(): boolean
	return game.PrivateServerId ~= ""
end

function PrivateServerPermissionService.isOwner(player: Player): boolean
	if PrivateServerPermissionService.isPrivateServer() then return player.UserId == game.PrivateServerOwnerId end
	if not RunService:IsStudio() then return false end
	return table.find(Whitelist.Admin, tostring(player.UserId)) ~= nil or table.find(Whitelist.Admin, player.Name) ~= nil
end

function PrivateServerPermissionService.hasCommandPermission(player: Player): boolean
	return PrivateServerPermissionService.isOwner(player) or delegates[player.UserId] == true
end

function PrivateServerPermissionService.grant(owner: Player, target: Player): boolean
	assert(PrivateServerPermissionService.isOwner(owner), "[PrivateServerPermissionService.grant] caller is not the private-server owner")
	if target == owner or delegates[target.UserId] then return false end
	delegates[target.UserId] = true
	target:SetAttribute("PrivateServerCommandPermission", true)
	return true
end

function PrivateServerPermissionService.revoke(owner: Player, target: Player): boolean
	assert(PrivateServerPermissionService.isOwner(owner), "[PrivateServerPermissionService.revoke] caller is not the private-server owner")
	if not delegates[target.UserId] then return false end
	delegates[target.UserId] = nil
	target:SetAttribute("PrivateServerCommandPermission", nil)
	return true
end

function PrivateServerPermissionService.getDelegates(): { number }
	local userIds = {}
	for userId in delegates do table.insert(userIds, userId) end
	table.sort(userIds)
	return userIds
end

return table.freeze(PrivateServerPermissionService)
