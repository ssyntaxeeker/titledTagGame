--!strict
--[[
    BotTag (Server)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Validates client-local training bot tag requests against the real round
    role rules, then applies the resulting role change to the requesting
    player. The bot itself is client-owned, so the server returns the role the
    client should put back on that local bot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local NTB = require(ServerStorage.Modules.Tag.NTB)
local Net = require(ReplicatedStorage.Packages.Net)
local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local Profiles = require(ServerStorage.Modules.Data.Profiles)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local RoleConfigsStorage = ReplicatedStorage.Shared.Configs.Roles
local BotTagRF = Net:RemoteFunction("BotTag")
local PlaySoundRE = Net:RemoteEvent("PlaySound")
local ApplyKnockbackRE = Net:RemoteEvent("ApplyKnockback")

local function getModeConfig(): { [string]: any }?
	local modeConfigModule = ReplicatedStorage.Shared.Configs.Modes:FindFirstChild(workspace:GetAttribute("Gamemode"))
	if not modeConfigModule or not modeConfigModule:IsA("ModuleScript") then return nil end

	return require(modeConfigModule)
end

local function getRoleConfig(roleName: string): { [string]: any }?
	local roleConfigModule = RoleConfigsStorage:FindFirstChild(roleName)
	if not roleConfigModule or not roleConfigModule:IsA("ModuleScript") then return nil end

	return require(roleConfigModule)
end

local function handlePlayerTaggedBot(player: Player, botRoleName: any, botPosition: any): { [string]: any }
	if typeof(botRoleName) ~= "string" then return { success = false, reason = "bad bot role" } end
	if typeof(botPosition) ~= "Vector3" then return { success = false, reason = "bad bot position" } end

	local character = player.Character
	if not character then return { success = false, reason = "no character" } end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then return { success = false, reason = "no character root" } end
	if humanoid.Health <= 0 then return { success = false, reason = "dead" } end
	if (rootPart.Position - botPosition).Magnitude > 10 then return { success = false, reason = "too far" } end

	if workspace:GetAttribute("TimeLeft") == 0 then return { success = false, reason = "round over" } end

	local modeConfig = getModeConfig()
	if not modeConfig or not modeConfig.allowTagging or modeConfig.allowDamage then return { success = false, reason = "mode blocks bot tag" } end

	local playerRole = character:GetAttribute("Role")
	if typeof(playerRole) ~= "string" then return { success = false, reason = "player has no role" } end

	local roleConfig = getRoleConfig(playerRole)
	if not roleConfig then return { success = false, reason = "no role" } end
	if typeof(roleConfig.canTagRoles) ~= "table" or not table.find(roleConfig.canTagRoles, botRoleName) then
		return { success = false, reason = "player role cannot tag bot" }
	end
	if typeof(roleConfig.onTagGives) ~= "string" or typeof(roleConfig.onTagBecomes) ~= "string" then
		return { success = false, reason = "role has no tag swap" }
	end

	local playerProxy = Profiles.ReturnProxy(player)
	playerProxy.Tags += 1
	RolesFunctions.ChangeRole(player, roleConfig.onTagBecomes)
	NTB.Hit(player)

	return {
		success = true,
		botRole = roleConfig.onTagGives,
		playerRole = roleConfig.onTagBecomes,
	}
end

BotTagRF.OnServerInvoke = function(player: Player, botRoleName: any, target: any, botPosition: any): { [string]: any }
	if BotAccess.userIds[player.UserId] ~= true then return { success = false, reason = "not authorized" } end
	if botRoleName == "PlayerTaggedBot" then return handlePlayerTaggedBot(player, target, botPosition) end

	if typeof(botRoleName) ~= "string" then return { success = false, reason = "bad role" } end
	if typeof(botPosition) ~= "Vector3" then return { success = false, reason = "bad bot position" } end
	if typeof(target) ~= "Instance" or not target:IsA("BasePart") then return { success = false, reason = "bad target" } end

	local character = player.Character
	if not character or not target:IsDescendantOf(character) then return { success = false, reason = "not own character" } end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") then return { success = false, reason = "no character root" } end
	if humanoid.Health <= 0 then return { success = false, reason = "dead" } end
	if character:GetAttribute("Role") == "Dead" then return { success = false, reason = "dead role" } end
	if (rootPart.Position - botPosition).Magnitude > 22 then return { success = false, reason = "too far" } end

	if workspace:GetAttribute("TimeLeft") == 0 then return { success = false, reason = "round over" } end

	local modeConfig = getModeConfig()
	if not modeConfig then return { success = false, reason = "no mode" } end
	if not modeConfig.allowTagging or modeConfig.allowDamage then return { success = false, reason = "mode blocks bot tag" } end

	local roleConfig = getRoleConfig(botRoleName)
	if not roleConfig then return { success = false, reason = "no role" } end
	local targetRole = character:GetAttribute("Role")
	if typeof(targetRole) ~= "string" then return { success = false, reason = "target has no role" } end
	if typeof(roleConfig.canTagRoles) ~= "table" or not table.find(roleConfig.canTagRoles, targetRole) then
		return { success = false, reason = "role cannot tag target" }
	end
	if typeof(roleConfig.onTagGives) ~= "string" or typeof(roleConfig.onTagBecomes) ~= "string" then
		return { success = false, reason = "role has no tag swap" }
	end

	local durability = character:GetAttribute("NTBDurability")
	if durability ~= 0 and durability ~= nil then
		NTB.Hit(player)
		PlaySoundRE:FireAllClients("NTBHit", rootPart)
		return { success = false, reason = "ntb" }
	end

	PlaySoundRE:FireAllClients("TagHit", rootPart)
	ApplyKnockbackRE:FireClient(player, botPosition, "BotTag")
	RolesFunctions.ChangeRole(player, roleConfig.onTagGives)
	NTB.Hit(player)

	return {
		success = true,
		botRole = roleConfig.onTagBecomes,
		targetRole = roleConfig.onTagGives,
	}
end

return 0
