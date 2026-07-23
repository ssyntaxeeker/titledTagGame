--!strict
--[[
    RolesFunctions (Server)
    =======================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Registers roles, applies only the latest request, and overlays active-mode
    movement tuning after the role's base stats.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FrozenCharacterService = require(ServerStorage.Modules.GameLogic.Roles.FrozenCharacterService)
local RolesInterface = require(ServerStorage.Modules.GameLogic.Roles.RolesInterface)

local RolesFunctions = {}
local registeredRoles: { [string]: (Player) -> () } = {}
local roleVersions: { [Player]: number } = {}

local function applyRole(player: Player, roleName: string, version: number)
	local character = player.Character
	if not character then
		character = player.CharacterAdded:Wait()
	end
	if player.Parent == nil or roleVersions[player] ~= version then return end

	local callback = registeredRoles[roleName]
	assert(callback, `[RolesFunctions.applyRole] role {roleName} was unregistered`)
	FrozenCharacterService.thaw(character)
	character:SetAttribute("Role", roleName)
	character:SetAttribute("MomentumMultiplier", 1)
	character:SetAttribute("MaximumMomentum", nil)
	callback(player)

	local modeName = workspace:GetAttribute("Gamemode")
	local modeModule = if type(modeName) == "string"
		then ReplicatedStorage.Shared.Configs.Modes:FindFirstChild(modeName)
		else nil
	if modeModule and modeModule:IsA("ModuleScript") then
		local modeConfig = require(modeModule)
		if type(modeConfig.momentumMultiplier) == "number" then
			character:SetAttribute("MomentumMultiplier", modeConfig.momentumMultiplier)
		end
		if type(modeConfig.vaultMomentumMultiplier) == "number" then
			character:SetAttribute("VaultMomentumMultiplier", modeConfig.vaultMomentumMultiplier)
		end
		if type(modeConfig.maximumMomentum) == "number" then
			assert(modeConfig.maximumMomentum >= 0, `[RolesFunctions.applyRole] {modeName} maximumMomentum must be non-negative`)
			character:SetAttribute("MaximumMomentum", modeConfig.maximumMomentum)
		end
	end
	RolesInterface.onRoleChange:Fire(player, roleName)
end

function RolesFunctions.ChangeRole(player: Player, roleName: string): boolean
	if not registeredRoles[roleName] then
		warn(`[RolesFunctions.ChangeRole] role {roleName} is not registered`)
		return false
	end

	local version = (roleVersions[player] or 0) + 1
	roleVersions[player] = version
	if player.Character then
		applyRole(player, roleName, version)
	else
		task.spawn(applyRole, player, roleName, version)
	end
	return true
end

function RolesFunctions.RegisterRole(roleName: string, callback: (Player) -> ()): number
	assert(registeredRoles[roleName] == nil, `[RolesFunctions.RegisterRole] {roleName} is already registered`)
	registeredRoles[roleName] = callback
	return 0
end

return RolesFunctions
