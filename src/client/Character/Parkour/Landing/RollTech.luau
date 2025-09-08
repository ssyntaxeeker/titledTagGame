local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)
local DebugConfig = require(ReplicatedStorage.Modules.Debug.DebugConfig)
local DebugFunctions = require(ReplicatedStorage.Modules.Debug.DebugFunctions)
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
	local walkSpeed = 40 + 17 * math.exp(-0.0225 * ms)

	if not character:GetAttribute("Rolling") then previousWalkSpeed = humanoid.WalkSpeed end

	rollIndex += 1
	humanoid.WalkSpeed = walkSpeed

	local rollAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.Roll)
	local currentRollIndex = rollIndex

	local rollboostTiming = math.clamp(1.3 + ((0.1 - ms / 1000) * 3.5) ^ 0.85 / (ms > 100 and 1 or 1.4), 0.5, 2.5)

	task.delay(math.clamp(rollboostTiming / 10, 0.05, 1), function()
		humanoid.JumpPower = character:GetAttribute("RollboostJumpPower") or 33.6

		task.delay(0.3, function()
			if currentRollIndex ~= rollIndex then return end

			character:SetAttribute("Rolling", false)
			humanoid.WalkSpeed = previousWalkSpeed
			humanoid.JumpPower = character:GetAttribute("MaxJumpPower") or 28
		end)
	end)

	local rootPart = character.HumanoidRootPart

	task.spawn(function()
		if SettingsInterface.debug.showValues ~= true then return end

		DebugFunctions.Print(
			`{string.format("%.2f", ms)} ms`,
			(ms < 8 and "Rainbow") or (ms < 100 and DebugConfig.DEBUG_PERFECT_ROLL_COLOR) or DebugConfig.DEBUG_NORMAL_ROLL_COLOR
		)
	end)

	character:SetAttribute("Rolling", true)
	PlaySound("Roll", rootPart, ms)
	PlaySoundRE:FireServer("Roll", rootPart, ms)
	rollAnimation:Play()
	rollAnimation:AdjustSpeed(ms > 100 and 1 or 1.4)
end

local function setupConnections(character)
	if humanoidConnection then humanoidConnection:Disconnect() end

	humanoidConnection = character.Humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
		local newMaterial = character.Humanoid.FloorMaterial
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
				-- SHAKE
			end
		end
	end)
end

local function initListening()
	local character = localPlayer.Character
	if character then setupConnections(character) end

	localPlayer.CharacterAdded:Connect(setupConnections)
end

return Schedules.Boot.job(initListening)
