local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterUtils = require(ReplicatedStorage.Vendor.CharacterUtils)
local MatchmakingInterface = require(ServerStorage.Modules.Matchmaking.MatchmakingInterface)
local NTB = require(ServerStorage.Modules.Tag.NTB)
local Net = require(ReplicatedStorage.Packages.Net)
local Profiles = require(ServerStorage.Modules.Data.Profiles)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local RoleConfigsStorage = ReplicatedStorage.Shared.Configs.Roles

local TagRE = Net:RemoteEvent("Tag")
local PlaySoundRE = Net:RemoteEvent("PlaySound")
local ApplyKnockbackRE = Net:RemoteEvent("ApplyKnockback")

local mapRayParams = RaycastParams.new()
mapRayParams.FilterType = Enum.RaycastFilterType.Include

TagRE.OnServerEvent:Connect(function(player, target)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	if not target or not target:IsA("Instance") then return end
	if (rootPart.Position - target.Position).Magnitude > 27 then return end
	if character.Humanoid.Health <= 0 then return end

	local targetHumanoid = CharacterUtils.CheckIfInstanceIsPartOfCharacter(target)
	if targetHumanoid then
		local targetCharacter = targetHumanoid.Parent
		local targetRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
		if not targetRootPart then return end
		if targetHumanoid.Health <= 0 then return end
		if targetCharacter:GetAttribute("Role") == "Dead" then return end

		local durability = targetCharacter:GetAttribute("NTBDurability")

		local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)

		if not durability or durability == 0 then
			PlaySoundRE:FireAllClients("TagHit", targetRootPart)
			if targetPlayer then ApplyKnockbackRE:FireClient(targetPlayer, character) end
		else
			PlaySoundRE:FireAllClients("NTBHit", targetRootPart)
		end

		if workspace:GetAttribute("TimeLeft") == 0 then return end

		local modeConfig = ReplicatedStorage.Shared.Configs.Modes:FindFirstChild(workspace:GetAttribute("Gamemode"))
		if not modeConfig then return end

		modeConfig = require(modeConfig)
		if not modeConfig.allowTagging then return end

		local playerRole, targetPlayerRole = character:GetAttribute("Role"), targetCharacter:GetAttribute("Role")
		local playerRoleConfig = require(RoleConfigsStorage[playerRole])

		if durability ~= 0 and durability ~= nil then
			if targetPlayer then NTB.Hit(targetPlayer) end
			if durability - 1 == 0 then PlaySoundRE:FireAllClients("NTBHitBreak", targetRootPart) end

			return
		end

		if not modeConfig.allowDamage and playerRoleConfig.canTagRoles and table.find(playerRoleConfig.canTagRoles, targetPlayerRole) then
			local playerProxy = Profiles.ReturnProxy(player)
			playerProxy.Tags += 1

			RolesFunctions.ChangeRole(player, playerRoleConfig.onTagBecomes)
			if targetPlayer then RolesFunctions.ChangeRole(targetPlayer, playerRoleConfig.onTagGives) end

			NTB.Hit(player)
			if targetPlayer then NTB.Hit(targetPlayer) end
		elseif modeConfig.allowDamage then
			targetHumanoid.Health -= modeConfig.allowDamage

			if targetHumanoid.Health <= 0 then
				local playerProxy = Profiles.ReturnProxy(player)
				playerProxy.Tags += 1

				if workspace:GetAttribute("Gamemode") == "InfFFA" then character.Humanoid.Health = character.Humanoid.MaxHealth end

				if ReplicatedStorage:GetAttribute("Ranked") then MatchmakingInterface.killedSignal:Fire(player) end
			end

			NTB.Hit(player)
			if targetPlayer then NTB.Hit(targetPlayer) end
		end
	end
end)

return 0
