--!strict
--[[
    BotAnimator (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Lightweight animation controller for cloned client-side bots.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)

local AnimationAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations")

local BotAnimator = {}

type TrackMap = {
	Run: AnimationTrack?,
	Jump1: AnimationTrack?,
	Jump2: AnimationTrack?,
	Climb: AnimationTrack?,
	Fall: AnimationTrack?,
	Idle: AnimationTrack?,
	Crouch: AnimationTrack?,
	SlideEnter: AnimationTrack?,
	SlideIdle: AnimationTrack?,
}

local function playAnimation(track: AnimationTrack?, fade: number?)
	if track and not track.IsPlaying then track:Play(fade or 0.1) end
end

local function stopAnimation(track: AnimationTrack?, fade: number?)
	if track and track.IsPlaying then track:Stop(fade or 0.1) end
end

local function getState(character: Model, humanoid: Humanoid): string
	if humanoid:GetState() == Enum.HumanoidStateType.Climbing then return "Climb" end
	if humanoid.FloorMaterial == Enum.Material.Air then return "Fall" end
	if character:GetAttribute("Sliding") then return "Slide" end
	if character:GetAttribute("Crouching") then return "Crouch" end
	return "Grounded"
end

function BotAnimator.attach(character: Model): () -> ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart then return function() end end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animateScript = character:FindFirstChild("Animate")
	if animateScript and animateScript:IsA("LocalScript") then animateScript.Enabled = false end

	local playerAnimations = AnimationAssets:FindFirstChild("Player")
	if not playerAnimations then return function() end end
	local parkourAnimations = AnimationAssets:FindFirstChild("Parkour")

	local tracks: TrackMap = {
		Run = AnimationManager.GetTrack(animator, playerAnimations:WaitForChild("Run") :: Animation),
		Jump1 = AnimationManager.GetTrack(animator, playerAnimations:WaitForChild("Jump1") :: Animation),
		Jump2 = AnimationManager.GetTrack(animator, playerAnimations:WaitForChild("Jump2") :: Animation),
		Climb = AnimationManager.GetTrack(animator, playerAnimations:WaitForChild("Climbing") :: Animation),
		Fall = AnimationManager.GetTrack(animator, playerAnimations:WaitForChild("Fall") :: Animation),
		Idle = AnimationManager.GetTrack(animator, playerAnimations:WaitForChild("Idle") :: Animation),
		Crouch = AnimationManager.GetTrack(animator, playerAnimations:WaitForChild("Crouch") :: Animation),
		SlideEnter = if parkourAnimations then AnimationManager.GetTrack(animator, parkourAnimations:WaitForChild("SlideEnter") :: Animation) else nil,
		SlideIdle = if parkourAnimations then AnimationManager.GetTrack(animator, parkourAnimations:WaitForChild("SlideIdle") :: Animation) else nil,
	}

	local currentState = ""
	local jumpCount = 1

	playAnimation(tracks.Idle, 0.1)
	playAnimation(tracks.Run, 0.1)
	if tracks.Run then tracks.Run:AdjustWeight(0.01, 0) end

	local connection = RunService.PreAnimation:Connect(function()
		if not character.Parent or not humanoid.Parent or not rootPart.Parent then return end

		local horizontalSpeed = Vector2.new(rootPart.AssemblyLinearVelocity.X, rootPart.AssemblyLinearVelocity.Z).Magnitude
		local moving = humanoid.MoveDirection.Magnitude > 0.05
		local direction = if rootPart.CFrame:VectorToObjectSpace(rootPart.AssemblyLinearVelocity).Z > 0 then -1 else 1

		if tracks.Run and tracks.Run.IsPlaying then
			tracks.Run:AdjustSpeed(horizontalSpeed / 32 * direction)
			tracks.Run:AdjustWeight(
				if character:GetAttribute("Sliding") then 0.01 elseif moving then math.clamp(horizontalSpeed / 32, 0.01, 1) else 0.01,
				0.15
			)
		end

		if character:GetAttribute("Sliding") then
			playAnimation(tracks.SlideIdle, 0.1)
			if tracks.SlideIdle then tracks.SlideIdle:AdjustSpeed(math.clamp(horizontalSpeed / 28, 0.5, 1.4)) end
		else
			stopAnimation(tracks.SlideIdle, 0.1)
		end

		if character:GetAttribute("Crouching") then
			playAnimation(tracks.Crouch, 0.1)
			if tracks.Crouch then tracks.Crouch:AdjustSpeed(if moving then math.clamp(horizontalSpeed / 8, 0.35, 1.25) else 0) end
		else
			stopAnimation(tracks.Crouch, 0.1)
		end

		if tracks.Climb and tracks.Climb.IsPlaying then
			tracks.Climb:AdjustSpeed(if moving then math.clamp(rootPart.AssemblyLinearVelocity.Y / 16, -2, 2) else 0)
		end

		local state = getState(character, humanoid)
		if state == currentState then return end

		if currentState == "Fall" then
			stopAnimation(tracks.Fall, 0.1)
			stopAnimation(tracks.Jump1, 0.1)
			stopAnimation(tracks.Jump2, 0.1)
		elseif currentState == "Climb" then
			stopAnimation(tracks.Climb, 0.2)
		elseif currentState == "Slide" then
			stopAnimation(tracks.SlideEnter, 0.1)
			stopAnimation(tracks.SlideIdle, 0.1)
		end

		if state == "Fall" then
			if tracks.Run then tracks.Run:AdjustWeight(0.01, 0.1) end
			if jumpCount >= 2 then jumpCount = 0 end
			jumpCount += 1
			if rootPart.AssemblyLinearVelocity.Y > 0.1 then playAnimation(tracks[`Jump{jumpCount}`], 0.15) end
			playAnimation(tracks.Fall, 0.25)
		elseif state == "Climb" then
			playAnimation(tracks.Climb, 0.2)
		elseif state == "Slide" then
			if tracks.Run then tracks.Run:AdjustWeight(0.01, 0.1) end
			playAnimation(tracks.SlideEnter, 0.05)
			playAnimation(tracks.SlideIdle, 0.1)
		end

		currentState = state
	end)

	return function()
		connection:Disconnect()
		for _, track in tracks do
			if track then track:Stop(0.1) end
		end
	end
end

return BotAnimator
