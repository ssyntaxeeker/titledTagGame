local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CameraShake = require(ReplicatedStorage.Modules.Camera.CameraShake)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local DebugConfig = require(ReplicatedStorage.Modules.Debug.DebugConfig)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
local MovementInterface = require(ReplicatedStorage.Modules.Character.Movement.MovementInterface)
local Net = require(ReplicatedStorage.Packages.Net)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local RollInterface = require(ReplicatedStorage.Modules.Character.Parkour.Landing.RollInterface)
local Schedules = require(ReplicatedStorage.Shared.Schedules)
local SettingsInterface = require(ReplicatedStorage.Modules.Settings.SettingsInterface)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local PlaySoundRE = Net:RemoteEvent("PlaySound")

local humanoidConnection

local previousMaterial = Enum.Material.Air
local previousWalkSpeed = 32

local rollIndex = 0

local function roll(character, ms)
	if CooldownManager.getCooldown(localPlayer, "Roll") then return end
	CooldownManager.modifyCooldown(localPlayer, "Roll", true, 0.05)

	local humanoid = character.Humanoid
	local rootPart = character.HumanoidRootPart

	local seconds = ms / 1000
	local perfect = seconds < 0.1

	local speedMult = perfect and (1.3 + ((0.1 - seconds) * 3.5) ^ 0.85) or 1.3

	if not character:GetAttribute("Rolling") then previousWalkSpeed = humanoid.WalkSpeed end

	MovementInterface.LockedMoveDirection = (rootPart.CFrame.RightVector * MovementInterface.MoveVector.X)
		+ (rootPart.CFrame.LookVector * MovementInterface.MoveVector.Z)
	MovementInterface.LockMoveVector = true

	RollInterface.lastPressed = nil
	rollIndex += 1

	local currentRollIndex = rollIndex

	character:SetAttribute("Rolling", true)

	humanoid.WalkSpeed *= speedMult

	local rollAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.Roll)

	task.spawn(function()
		local fmt = SettingsInterface.debug.numericalprecision and "%f" or "%.2f"
		local out = string.format(fmt, ms)

		DebugFunctions.Print(
			`{out} ms`,
			(ms <= 10 and "Rainbow") or (perfect and DebugConfig.DEBUG_PERFECT_ROLL_COLOR) or DebugConfig.DEBUG_NORMAL_ROLL_COLOR
		)
	end)

	PlaySound("Roll", rootPart, ms)
	PlaySoundRE:FireServer("Roll", rootPart, ms)

	rollAnimation:Play()
	rollAnimation:AdjustSpeed(perfect and speedMult or 1)

	if perfect then
		PlaySound("PerfectRoll", rootPart, ms)
		PlaySoundRE:FireServer("PerfectRoll", rootPart, ms)
	end

	task.delay(0.15, function()
		if currentRollIndex ~= rollIndex then return end

		humanoid.JumpPower *= 1.3
		MovementInterface.LockMoveVector = false

		task.delay(perfect and 0.2 or 0.35, function()
			if currentRollIndex ~= rollIndex then return end

			character:SetAttribute("Rolling", false)
			humanoid.WalkSpeed = previousWalkSpeed
			humanoid.JumpPower = character:GetAttribute("MaxJumpPower") or 28
		end)
	end)
end

local function setupConnections(character)
	if humanoidConnection then humanoidConnection:Disconnect() end

	local humanoid = character:WaitForChild("Humanoid")

	humanoidConnection = humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		local newMaterial = humanoid.FloorMaterial
		local rootPart = character.HumanoidRootPart

		if previousMaterial == Enum.Material.Air and newMaterial ~= Enum.Material.Air and not character:GetAttribute("Sliding") then
			local ALVelocityY = rootPart.AssemblyLinearVelocity.Y

			local seconds = RollInterface.lastPressed and os.clock() - RollInterface.lastPressed

			if ALVelocityY > -40 then return end

			if seconds and seconds < 0.7 then
				roll(character, seconds * 1000)
			else
				PlaySound("Land", rootPart, ALVelocityY)
				PlaySoundRE:FireServer("Land", rootPart, ALVelocityY)
				if SettingsInterface.gameplay.cameraShake == true then CameraShake.new():Shake(0.3, ALVelocityY / 120, 0.2) end
			end
		end
	end)
end

local function initListening()
	local character = localPlayer.Character

	localPlayer.CharacterAdded:Connect(setupConnections)
	if character then setupConnections(character) end
end

return Schedules.Boot.job(initListening)
