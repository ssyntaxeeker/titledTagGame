local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local DebugConfig = require(ReplicatedStorage.Modules.Debug.DebugConfig)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local Assets = ReplicatedStorage.Assets

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local localPlayer = Players.LocalPlayer

return function(studs, instance)
	local character = localPlayer.Character
	if not character then return end

	studs = math.clamp(studs, 0, 2.75)

	if CooldownManager.getCooldown(localPlayer, "Vault") then return end
	CooldownManager.modifyCooldown(localPlayer, "Vault", true, 0.1)

	local rootPart = character.HumanoidRootPart
	local humanoid = character.Humanoid

	local vaultAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.Vault)
	vaultAnimation:Play()

	character:SetAttribute("Vaulting", true)

	PlaySound("Vault", rootPart, studs)
	PlaySoundRE:FireServer("Vault", rootPart, studs)

	task.spawn(function()
		local fmt = SettingsInterface.debug.numericalprecision and "%f" or "%.2f"
		local out = string.format(fmt, studs)

		DebugFunctions.Print(
			`{out} studs`,
			(studs >= 2.75 and "Rainbow") or studs > 2.25 and DebugConfig.DEBUG_PERFECT_VAULT_COLOR or DebugConfig.DEBUG_NORMAL_VAULT_COLOR
		)
	end)

	rootPart.AssemblyLinearVelocity = Vector3.new(
		rootPart.AssemblyLinearVelocity.X,
		math.clamp(studs / 1.5 * 30, 30, math.huge),
		rootPart.AssemblyLinearVelocity.Z
	) - rootPart.CFrame.LookVector * 2

	humanoid.WalkSpeed += 2
	character:SetAttribute("Momentum", character:GetAttribute("Momentum") + 2)

	if instance and (instance.Color == Color3.fromRGB(218, 133, 65) or instance.Color == Color3.fromRGB(248, 248, 248)) then return end

	task.delay(0.11, function()
		character:SetAttribute("Vaulting", nil)
	end)
end
