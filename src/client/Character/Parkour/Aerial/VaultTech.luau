local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local DebugConfig = require(ReplicatedStorage.Modules.Debug.DebugConfig)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local Assets = ReplicatedStorage.Assets

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local localPlayer = Players.LocalPlayer

return function(studs)
	local character = localPlayer.Character
	if not character then return end

	local rootPart = character.HumanoidRootPart
	local humanoid = character.Humanoid

	local vaultAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.Vault)
	vaultAnimation:Play()

	PlaySound("Vault", rootPart, studs)
	PlaySoundRE:FireServer("Vault", rootPart, studs)

	task.spawn(function()
		if SettingsInterface.debug.showValues ~= true then return end

		DebugFunctions.Print(
			`{string.format("%.2f", studs)} studs`,
			(studs > 2.75 and "Rainbow") or studs > 2.25 and DebugConfig.DEBUG_PERFECT_VAULT_COLOR or DebugConfig.DEBUG_NORMAL_VAULT_COLOR
		)
	end)

	rootPart.AssemblyLinearVelocity = Vector3.new(
		rootPart.AssemblyLinearVelocity.X,
		math.clamp(studs / 1.5 * 30, 30, math.huge),
		rootPart.AssemblyLinearVelocity.Z
	) - rootPart.CFrame.LookVector * 2

	character.Humanoid.WalkSpeed += 3 * (character:GetAttribute("VaultMomentumMultiplier") or 0.45)
end
