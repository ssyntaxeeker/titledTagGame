local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local AerialInterface = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.AerialInterface)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local DebugConfig = require(ReplicatedStorage.Modules.Debug.DebugConfig)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local ParkourMovementModel = require(ReplicatedStorage.Modules.Character.Parkour.ParkourMovementModel)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)
local SwingCollisionWindow = require(ReplicatedStorage.Modules.Character.Parkour.Aerial.SwingCollisionWindow)

local Assets = ReplicatedStorage.Assets

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local localPlayer = Players.LocalPlayer

return function(hitResult)
	if CooldownManager.getCooldown(localPlayer, "Swing") then return end
	if not hitResult then return end

	local character = localPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end
	if humanoid.Health <= 0 then return end

	local swingPart = hitResult.Instance
	if not swingPart:IsA("BasePart") then return end

	local swingAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.Swing)

	character:SetAttribute("Swinging", true)
	AerialInterface.swingingBar = swingPart
	AerialInterface.swingReleaseRequested = false
	CooldownManager.modifyCooldown(localPlayer, "Swing", true, ParkourMovementModel.cooldowns.swing)
	local releaseSwingCollisions = SwingCollisionWindow.acquire(character, hitResult.Position, swingPart)

	task.spawn(function()
		swingAnimation:Play(0.1, 1, 1.5)

		PlaySound("Swing", rootPart)
		PlaySoundRE:FireServer("Swing", rootPart)
	end)

	local targetPos = hitResult.Position + Vector3.new(0, -1.5, 0)
	local backOffset = rootPart.CFrame.LookVector * -1
	local desiredPos = Vector3.new(rootPart.Position.X, targetPos.Y, rootPart.Position.Z)

	rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.new(targetPos + backOffset), 0.5)
	rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.new(desiredPos), 0.5)

	local bodyPos = Instance.new("BodyPosition")
	bodyPos.MaxForce = Vector3.new(700, 9000, 700)
	bodyPos.Position = targetPos
	bodyPos.Parent = rootPart

	local velocity = rootPart.AssemblyLinearVelocity
	local swingFactor = ParkourMovementModel.swingFactor(velocity.Y)

	local elapsed = 0

	local experimental = ParkourMovementModel.isExperimentalSwingBar(swingPart)
	swingAnimation.Looped = experimental
	local loopSpeed = 1
	repeat
		elapsed += task.wait()
	until elapsed >= ParkourMovementModel.swingHoldSeconds
		or (experimental and elapsed >= 0.15 and AerialInterface.swingInputHeld)

	if experimental and elapsed >= 0.15 and AerialInterface.swingInputHeld then
		character:SetAttribute("ExperimentalSwinging", true)
		while AerialInterface.swingInputHeld
			and AerialInterface.swingingBar == swingPart
			and character.Parent ~= nil
			and humanoid.Health > 0
		do
			local dt = task.wait()
			loopSpeed += dt * 0.5
			character:SetAttribute("SwingLoopSpeed", loopSpeed)
			swingAnimation:AdjustSpeed(math.clamp(loopSpeed, 1, 3))
		end
		character:SetAttribute("ExperimentalSwinging", nil)
		character:SetAttribute("SwingLoopSpeed", nil)
	end

	task.spawn(function()
		local fmt = SettingsInterface.debug.numericalprecision and "%f" or "%.2f"
		local out = string.format(fmt, swingFactor * 100)

		local colorFactor = (swingFactor - 1 + 0.001) / 1.8

		DebugFunctions.Print(
			`{out}% vps`,
			Color3.fromHSV(
				DebugConfig.DEBUG_SWING_COLOR[1] + colorFactor / 2,
				DebugConfig.DEBUG_SWING_COLOR[2] + colorFactor,
				DebugConfig.DEBUG_SWING_COLOR[3]
			)
		)
	end)

	if bodyPos then bodyPos:Destroy() end

	local moveDir
	if humanoid.MoveDirection.Magnitude <= 0.1 or not humanoid.MoveDirection then
		moveDir = rootPart.CFrame.LookVector
	else
		moveDir = humanoid.MoveDirection
	end

	local releaseFactor = swingFactor * loopSpeed
	if experimental and loopSpeed > 1 then
		rootPart.AssemblyLinearVelocity += (moveDir + rootPart.CFrame.LookVector * 0.45) * (releaseFactor * 45)
	else
		rootPart.AssemblyLinearVelocity += moveDir * (releaseFactor * 50)
	end
	character:SetAttribute(
		"Momentum",
		(character:GetAttribute("Momentum") or 0)
			+ ParkourMovementModel.swingMomentumReward(releaseFactor)
			* (if experimental and loopSpeed > 1 then 4 / 3 else 1)
			* (character:GetAttribute("MomentumMultiplier") or 1)
	)

	character:SetAttribute("Swinging", nil)
	AerialInterface.swingingBar = nil
	AerialInterface.swingReleaseRequested = false
	AerialInterface.swingInputHeld = false
	if experimental then swingAnimation:Stop(0.1) end

	task.delay(0.12, releaseSwingCollisions)
end
