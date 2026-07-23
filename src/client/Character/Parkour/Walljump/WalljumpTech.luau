--!strict
--[[
    WalljumpTech (Client)
    =====================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Executes accepted Walljumps and owns their cooldown, one-use-per-airtime
    lock, animation, sound, camera feedback, and landing cleanup.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CameraShake = require(ReplicatedStorage.Modules.Camera.CameraShake)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local WalljumpConfig = require(script.Parent.WalljumpConfig)
local WalljumpModel = require(script.Parent.WalljumpModel)

local PlaySoundRE = Net:RemoteEvent("PlaySound")
local localPlayer = Players.LocalPlayer
local WalljumpTech = {}

function WalljumpTech.try(character: Model): boolean
	if CooldownManager.getCooldown(localPlayer, "Walljump") then return false end
	if character:GetAttribute("WalljumpUsedSinceGrounded") == true then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[WalljumpTech.try] character has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[WalljumpTech.try] character has no HumanoidRootPart")
	local velocity = rootPart.AssemblyLinearVelocity
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	if grounded and not WalljumpModel.isGroundEligible(velocity) then return false end

	local ignore = { character }
	local debugFolder = workspace:FindFirstChild("Debug")
	if debugFolder then table.insert(ignore, debugFolder) end
	local probe = WalljumpModel.probe(rootPart.CFrame, ignore)
	if not probe then return false end
	local wallPart = probe.result.Instance
	assert(wallPart:IsA("BasePart"), "[WalljumpTech.try] probe hit a non-part")

	local animationAsset = ReplicatedStorage.Assets.Animations.Parkour:FindFirstChild("Walljump")
	assert(animationAsset and animationAsset:IsA("Animation"), "[WalljumpTech.try] Animations.Parkour.Walljump is missing")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	assert(animator, "[WalljumpTech.try] Humanoid has no Animator")
	local animation = AnimationManager.GetTrack(animator, animationAsset)
	assert(animation, "[WalljumpTech.try] failed to load Walljump animation")
	local resultVelocity, incomingVerticalSpeed = WalljumpModel.velocity(
		velocity,
		probe.result.Normal,
		wallPart.AssemblyLinearVelocity
	)

	CooldownManager.modifyCooldown(localPlayer, "Walljump", true, WalljumpConfig.cooldown)
	character:SetAttribute("WalljumpUsedSinceGrounded", true)
	character:SetAttribute("Walljumping", true)
	character:SetAttribute("LastWalljumpAt", os.clock())
	local landedConnection: RBXScriptConnection?
	landedConnection = humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		if humanoid.FloorMaterial == Enum.Material.Air then return end
		character:SetAttribute("WalljumpUsedSinceGrounded", nil)
		if landedConnection then landedConnection:Disconnect() end
	end)
	if grounded then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
	rootPart.AssemblyLinearVelocity = resultVelocity

	animation.Priority = Enum.AnimationPriority.Action2
	animation.Looped = false
	animation:Play(0.05)
	PlaySound("WallJump", wallPart, probe.result.Position)
	PlaySoundRE:FireServer("WallJump", wallPart, probe.result.Position)
	if SettingsInterface.gameplay.cameraShake == true then
		CameraShake.new():Shake(
			WalljumpConfig.cameraShakeDuration,
			WalljumpConfig.cameraShakeIntensity,
			0.35
		)
	end
	task.spawn(function()
		DebugFunctions.VisualizeRaycast(probe.origin, probe.direction, Color3.fromRGB(0, 255, 170))
		local fmt = if SettingsInterface.debug.numericalprecision then "%f" else "%.2f"
		local debugVerticalSpeed = string.format(fmt, incomingVerticalSpeed)
		DebugFunctions.Print(
			`Walljump {debugVerticalSpeed}y`,
			if incomingVerticalSpeed > WalljumpConfig.fastDebugVerticalSpeed
				then Color3.fromRGB(255, 140, 0)
				else Color3.fromRGB(255, 255, 255)
		)
	end)
	task.delay(WalljumpConfig.stateSeconds, function()
		if character.Parent then character:SetAttribute("Walljumping", nil) end
	end)
	return true
end

return table.freeze(WalljumpTech)
