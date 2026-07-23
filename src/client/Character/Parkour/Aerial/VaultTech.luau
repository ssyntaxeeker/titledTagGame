local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local CustomizationInterface = require(ReplicatedStorage.Modules.Customization.CustomizationInterface)
local DebugConfig = require(ReplicatedStorage.Modules.Debug.DebugConfig)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local ParkourMovementModel = require(ReplicatedStorage.Modules.Character.Parkour.ParkourMovementModel)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local VaultClearanceModel = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.VaultClearanceModel)

local Assets = ReplicatedStorage.Assets

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local localPlayer = Players.LocalPlayer

return function(studs, instance)
	local character = localPlayer.Character
	if not character then return end

	local surfaceStuds = ParkourMovementModel.vaultStuds(studs)
	studs = surfaceStuds

	studs = CustomizationInterface.staticVault or studs

	if CooldownManager.getCooldown(localPlayer, "Vault") then return end
	CooldownManager.modifyCooldown(localPlayer, "Vault", true, ParkourMovementModel.cooldowns.vault)

	local rootPart = character.HumanoidRootPart
	local humanoid = character.Humanoid

	local vaultAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.Vault)
	vaultAnimation:Play()

	character:SetAttribute("Vaulting", true)

	PlaySound("Vault", rootPart, studs)
	PlaySoundRE:FireServer("Vault", rootPart, studs)
	local vaultVelocity = ParkourMovementModel.vaultVelocity(rootPart.AssemblyLinearVelocity, rootPart.CFrame.LookVector, studs)
	vaultVelocity = VaultClearanceModel.adjustVelocity(character, instance, vaultVelocity, rootPart.CFrame.LookVector)

	task.spawn(function()
		local fmt = SettingsInterface.debug.numericalprecision and "%f" or "%.2f"
		local out = string.format(fmt, studs)

		DebugFunctions.Print(
			`{out} studs`,
			(studs >= 2.745 and "Rainbow") or studs > 2.25 and DebugConfig.DEBUG_PERFECT_VAULT_COLOR or DebugConfig.DEBUG_NORMAL_VAULT_COLOR
		)
	end)

	rootPart.AssemblyLinearVelocity = vaultVelocity

	local now = os.clock()
	local lastVaultAt = character:GetAttribute("LastVaultAt")
	local vaultMultiplier = character:GetAttribute("VaultMomentumMultiplier") or 1
	local reward = ParkourMovementModel.vaultMomentumReward(
		if typeof(lastVaultAt) == "number" then lastVaultAt else nil,
		now,
		vaultMultiplier
	)
	character:SetAttribute("Momentum", (character:GetAttribute("Momentum") or 0) + reward)
	character:SetAttribute("LastVaultAt", now)
	if instance and (instance.Color == Color3.fromRGB(218, 133, 65) or instance.Color == Color3.fromRGB(248, 248, 248)) then return end

	task.delay(ParkourMovementModel.vaultStateSeconds, function()
		character:SetAttribute("Vaulting", nil)
	end)
end
