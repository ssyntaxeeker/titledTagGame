local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationAssets = ReplicatedStorage.Assets.Animations
local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local localPlayer = Players.LocalPlayer

local animations = {}
local renderStepped
local currentState

local jumpCount = 1

local function playAnimation(track, fade)
	if track and not track.IsPlaying then track:Play(fade or 0.1) end
end

local function stopAnimation(track, fade)
	if track and track.IsPlaying then track:Stop(fade or 0.1) end
end

local function getState(character, humanoid)
	if humanoid:GetState() == Enum.HumanoidStateType.Climbing then return "Climb" end

	if humanoid.FloorMaterial == Enum.Material.Air then return "Fall" end

	if character:GetAttribute("Crouching") then return "Crouch" end

	return "Grounded"
end

local function updateLocomotion(character)
	local humanoid = character.Humanoid
	local rootPart = character.HumanoidRootPart

	local horizontalSpeed = Vector2.new(rootPart.AssemblyLinearVelocity.X, rootPart.AssemblyLinearVelocity.Z).Magnitude

	local moving = humanoid.MoveDirection.Magnitude > 0.05

	local direction = rootPart.CFrame:VectorToObjectSpace(rootPart.AssemblyLinearVelocity).Z > 0 and -1 or 1

	--------------------------------------------------
	-- RUN ANIMATION
	--------------------------------------------------

	if animations.Run.IsPlaying then
		local speedScale = horizontalSpeed / 32

		animations.Run:AdjustSpeed(speedScale * direction)

		local weight = if moving then math.clamp(horizontalSpeed / 32, 0, 1) else 0

		animations.Run:AdjustWeight(weight, 0.15)
	end

	--------------------------------------------------
	-- CROUCH ANIMATION
	--------------------------------------------------

	if character:GetAttribute("Crouching") then
		playAnimation(animations.Crouch, 0.1)

		if moving then
			animations.Crouch:AdjustSpeed(math.clamp(horizontalSpeed / 8, 0.35, 1.25))
		else
			animations.Crouch:AdjustSpeed(0)
		end
	else
		stopAnimation(animations.Crouch, 0.1)
	end

	--------------------------------------------------
	-- CLIMB
	--------------------------------------------------

	if animations.Climb.IsPlaying then
		if moving then
			animations.Climb:AdjustSpeed(math.clamp(rootPart.AssemblyLinearVelocity.Y / 16, -2, 2))
		else
			animations.Climb:AdjustSpeed(0)
		end
	end
end

local function updateStateAnimations(character)
	local humanoid = character.Humanoid
	local rootPart = character.HumanoidRootPart

	local state = getState(character, humanoid)

	if state == currentState then return end

	--------------------------------------------------
	-- EXIT OLD STATE
	--------------------------------------------------

	if currentState == "Fall" then
		stopAnimation(animations.Fall, 0.1)
		stopAnimation(animations.Jump1, 0.1)
		stopAnimation(animations.Jump2, 0.1)
	elseif currentState == "Climb" then
		stopAnimation(animations.Climb, 0.2)
	end

	--------------------------------------------------
	-- ENTER NEW STATE
	--------------------------------------------------

	if state == "Fall" then
		animations.Run:AdjustWeight(0, 0.1)

		if jumpCount >= 2 then jumpCount = 0 end

		jumpCount += 1

		if rootPart.AssemblyLinearVelocity.Y > 0.1 then playAnimation(animations["Jump" .. jumpCount], 0.15) end

		playAnimation(animations.Fall, 0.25)
	elseif currentState == "Fall" and state ~= "Fall" then
		stopAnimation(animations.Fall, 0.1)
		stopAnimation(animations.Jump1, 0.1)
		stopAnimation(animations.Jump2, 0.1)
	elseif state == "Climb" then
		playAnimation(animations.Climb, 0.2)
	end

	currentState = state
end

local function updateAnimations(character)
	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then return end

	if character:FindFirstChild("Animate") then character.Animate.Enabled = false end

	updateLocomotion(character)
	updateStateAnimations(character)
end

local function initCharacter(character)
	if renderStepped then renderStepped:Disconnect() end

	currentState = nil

	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")

	--------------------------------------------------
	-- LOAD ANIMS
	--------------------------------------------------

	animations.Run = AnimationManager.GetTrack(animator, AnimationAssets.Player.Run)

	animations.Jump1 = AnimationManager.GetTrack(animator, AnimationAssets.Player.Jump1)

	animations.Jump2 = AnimationManager.GetTrack(animator, AnimationAssets.Player.Jump2)

	animations.Climb = AnimationManager.GetTrack(animator, AnimationAssets.Player.Climbing)

	animations.Fall = AnimationManager.GetTrack(animator, AnimationAssets.Player.Fall)

	animations.Idle = AnimationManager.GetTrack(animator, AnimationAssets.Player.Idle)

	animations.Crouch = AnimationManager.GetTrack(animator, AnimationAssets.Player.Crouch)

	--------------------------------------------------
	-- BASE TRACKS ALWAYS PLAY
	--------------------------------------------------

	animations.Idle:Play(0)

	animations.Run:Play(0)
	animations.Run:AdjustWeight(0)

	--------------------------------------------------
	-- CLEANUP
	--------------------------------------------------

	humanoid.Died:Connect(function()
		if renderStepped then
			renderStepped:Disconnect()
			renderStepped = nil
		end
	end)

	renderStepped = RunService.PreAnimation:Connect(function()
		updateAnimations(character)
	end)
end

local function handleConnections()
	localPlayer.CharacterAdded:Connect(initCharacter)

	if localPlayer.Character then initCharacter(localPlayer.Character) end
end

return Schedules.Boot.job(handleConnections)
