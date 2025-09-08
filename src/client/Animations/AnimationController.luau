local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationAssets = ReplicatedStorage.Assets.Animations
local AnimationManager = require(script.Parent.AnimationManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer
local animations: { [any]: any } = {}
local renderStepped
local currentState = nil

local function playAnimation(animation, time)
	if animation and not animation.IsPlaying then animation:Play(time or 0.1) end
end

local function stopAnimation(animation, time)
	if animation and animation.IsPlaying then animation:Stop(time or 0.1) end
end

local function getCharacterState(humanoid)
	local floorMaterial = humanoid.FloorMaterial
	local moveDir = humanoid.MoveDirection

	if humanoid:GetState() == Enum.HumanoidStateType.Climbing then return "Climb" end

	if floorMaterial == Enum.Material.Air then return "Fall" end

	local isCrouching = humanoid.Parent:GetAttribute("Crouching")

	if moveDir.Magnitude > 0 then
		if isCrouching then return "CrouchWalk" end

		if humanoid.WalkSpeed > 23 then
			return "Run"
		else
			return "Walk"
		end
	end

	if isCrouching then return "CrouchIdle" end

	return "Idle"
end

local jumpCount = 1

local function updateAnimations(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local humanoid = character.Humanoid

	local maxRunSpeed = character:GetAttribute("MaxRunSpeed") or 32

	local movementDirZ = rootPart.CFrame:VectorToObjectSpace(rootPart.AssemblyLinearVelocity).Z / humanoid.WalkSpeed

	local speed = (0.2 + (1 - 0.2) * (math.clamp((humanoid.WalkSpeed - 16) / (maxRunSpeed - 16), 0, 1) ^ 1.5)) * ((movementDirZ > 0.1) and -1 or 1)
	local state = getCharacterState(humanoid)

	animations.Walk:AdjustSpeed(math.clamp(speed * 3.2, -0.9, 0.9))
	animations.Run:AdjustSpeed(speed)

	if humanoid.MoveDirection.Magnitude > 0.1 then
		animations.Climb:AdjustSpeed(1)
	else
		animations.Climb:AdjustSpeed(0)
	end

	if state ~= currentState then
		if currentState then
			local prevAnim = animations[currentState]
			stopAnimation(prevAnim, 0.1)
		end

		if state == "Run" then
			playAnimation(animations.Run, 0.4)
		elseif state == "CrouchWalk" then
			playAnimation(animations.CrouchWalk, 0.4)
		elseif state == "Walk" then
			playAnimation(animations.Walk, 0.2)
		elseif state == "Climb" then
			playAnimation(animations.Climb, 0.1)
		elseif state == "Fall" then
			if jumpCount % 2 == 0 then jumpCount = 0 end
			jumpCount += 1

			if rootPart.AssemblyLinearVelocity.Y > 0.1 then playAnimation(animations[`Jump{jumpCount}`]) end
			playAnimation(animations.Fall, 0.1)
		elseif state == "CrouchIdle" then
			playAnimation(animations.CrouchIdle, 0.1)
		elseif state == "Idle" then
			playAnimation(animations.Idle, 0.1)
		end

		currentState = state
	end
end

local function initCharacter(character)
	if renderStepped then renderStepped:Disconnect() end
	currentState = nil

	local humanoid = character.Humanoid

	animations.Walk = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Player.Walk)
	animations.CrouchWalk = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Player.CrouchWalk)
	animations.Run = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Player.Run)
	animations.Jump1 = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Player.Jump1)
	animations.Jump2 = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Player.Jump2)
	animations.Climb = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Player.Climbing)
	animations.Fall = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Player.Fall)
	animations.Idle = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Player.Idle)
	animations.CrouchIdle = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Player.CrouchIdle)

	animations.Vault = AnimationManager.GetTrack(humanoid.Animator, AnimationAssets.Parkour.Vault)

	humanoid.Died:Connect(function()
		if renderStepped then
			renderStepped:Disconnect()
			renderStepped = nil
		end
	end)

	renderStepped = RunService.RenderStepped:Connect(function()
		if character:FindFirstChild("Animate") then character.Animate.Enabled = false end

		updateAnimations(character)
	end)
end

local function handleConnections()
	if localPlayer.Character then initCharacter(localPlayer.Character) end
	localPlayer.CharacterAdded:Connect(initCharacter)
end

return Schedules.Boot.job(handleConnections)
