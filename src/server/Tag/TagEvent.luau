local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterUtils = require(ReplicatedStorage.Vendor.CharacterUtils)
local Net = require(ReplicatedStorage.Packages.Net)
local RolesFunctions = require(ServerStorage.Modules.GameLogic.Roles.RolesFunctions)

local RoleConfigsStorage = ReplicatedStorage.Shared.Configs.Roles

local TagRE = Net:RemoteEvent("Tag")
local PlaySoundRE = Net:RemoteEvent("PlaySound")

TagRE.OnServerEvent:Connect(function(player, target)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	if not target or not target:IsA("Instance") then return end

	if (rootPart.Position - target.Position).Magnitude > 20 then return end

	local targetHumanoid = CharacterUtils.CheckIfInstanceIsPartOfCharacter(target)
	if targetHumanoid then
		if workspace:GetAttribute("TimeLeft") == 0 then return end

		local targetCharacter = targetHumanoid.Parent
		local targetRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
		if not targetRootPart then return end

		local direction = (targetRootPart.Position - rootPart.Position).Unit
		local attackerVelocity = rootPart.AssemblyLinearVelocity.Magnitude
		local speedFactor = math.clamp(attackerVelocity / 32, 0, 3)

		local baseForward = 48
		local knockbackMultiplier = character:GetAttribute("KnockbackMultiplier")
		local forwardImpulse = direction * (baseForward + speedFactor * 20) * (knockbackMultiplier or 1)
		local upImpulse = Vector3.new(0, 11 + speedFactor * 5, 0) * ((knockbackMultiplier and knockbackMultiplier / 2) or 0.5)

		local randomSide = rootPart.CFrame.RightVector * (math.random() - 0.5) * 15
		local finalVelocity = forwardImpulse + upImpulse + randomSide

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = finalVelocity
		bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bodyVelocity.P = 1e4
		bodyVelocity.Parent = targetRootPart
		Debris:AddItem(bodyVelocity, 0.07)

		PlaySoundRE:FireAllClients("Hit", targetRootPart)

		local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
		if targetPlayer then
			local modeConfig = ReplicatedStorage.Shared.Configs.Modes:FindFirstChild(workspace:GetAttribute("Gamemode"))
			if not modeConfig then return end
			modeConfig = require(modeConfig)
			if not modeConfig.allowTagging then return end

			local playerRole, targetPlayerRole = character:GetAttribute("Role"), targetCharacter:GetAttribute("Role")
			local playerRoleConfig = require(RoleConfigsStorage[playerRole])

			if playerRoleConfig.canTagRoles and table.find(playerRoleConfig.canTagRoles, targetPlayerRole) then
				RolesFunctions.ChangeRole(player, playerRoleConfig.onTagBecomes)
				RolesFunctions.ChangeRole(targetPlayer, playerRoleConfig.onTagGives)
			end
		end
	end
end)

return 0
