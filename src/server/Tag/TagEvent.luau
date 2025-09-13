local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterUtils = require(ReplicatedStorage.Vendor.CharacterUtils)
local NTB = require(ServerStorage.Modules.Tag.NTB)
local Net = require(ReplicatedStorage.Packages.Net)
local Profiles = require(ServerStorage.Modules.Data.Profiles)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local RoleConfigsStorage = ReplicatedStorage.Shared.Configs.Roles

local TagRE = Net:RemoteEvent("Tag")
local PlaySoundRE = Net:RemoteEvent("PlaySound")
local ApplyKnockbackRE = Net:RemoteEvent("ApplyKnockback")

TagRE.OnServerEvent:Connect(function(player, target)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	if not target or not target:IsA("Instance") then return end

	if (rootPart.Position - target.Position).Magnitude > 25 then return end

	local targetHumanoid = CharacterUtils.CheckIfInstanceIsPartOfCharacter(target)
	if targetHumanoid then
		local targetCharacter = targetHumanoid.Parent
		local targetRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
		if not targetRootPart then return end
		if targetHumanoid.Health <= 0 then return end

		local durability = targetCharacter:GetAttribute("NTBDurability")

		local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)

		if targetPlayer then
			if not durability or durability == 0 then
				PlaySoundRE:FireAllClients("Hit", targetRootPart)
				ApplyKnockbackRE:FireClient(targetPlayer, character)
			else
				PlaySoundRE:FireAllClients("NTBHit", targetRootPart)
				ApplyKnockbackRE:FireClient(targetPlayer, character, "NTB")
			end

			if workspace:GetAttribute("TimeLeft") == 0 then return end

			local modeConfig = ReplicatedStorage.Shared.Configs.Modes:FindFirstChild(workspace:GetAttribute("Gamemode"))
			if not modeConfig then return end

			modeConfig = require(modeConfig)
			if not modeConfig.allowTagging then return end

			local playerRole, targetPlayerRole = character:GetAttribute("Role"), targetCharacter:GetAttribute("Role")
			local playerRoleConfig = require(RoleConfigsStorage[playerRole])

			if playerRoleConfig.canTagRoles and table.find(playerRoleConfig.canTagRoles, targetPlayerRole) then
				if durability ~= 0 and durability ~= nil then
					NTB.Hit(targetPlayer)

					if durability - 1 == 0 then PlaySoundRE:FireAllClients("NTBHitBreak", targetRootPart) end
					return
				end

				local playerProxy = Profiles.ReturnProxy(player)
				playerProxy.Tags += 1

				RolesFunctions.ChangeRole(player, playerRoleConfig.onTagBecomes)
				RolesFunctions.ChangeRole(targetPlayer, playerRoleConfig.onTagGives)

				NTB.Hit(player)
				NTB.Hit(targetPlayer)
			end
		end
	end
end)

return 0
