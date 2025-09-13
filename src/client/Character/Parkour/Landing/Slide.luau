local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)

local Assets = ReplicatedStorage.Assets

local localPlayer = Players.LocalPlayer

local Slide = {}

local slideTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)

function Slide.Start()
	local character = localPlayer.Character
	local humanoid = character.Humanoid

	humanoid.HipHeight = 0.2

	CameraModule.LockVector = true

	local rootPart = character.HumanoidRootPart

	local SlideSound = rootPart:FindFirstChild("Slide")

	if not SlideSound then
		SlideSound = Assets.Sounds.Slide:Clone()
		SlideSound.Parent = character.HumanoidRootPart
	end

	local slideEnterAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.SlideEnter)
	local slideAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.SlideIdle)
	slideEnterAnimation.Priority = Enum.AnimationPriority.Action3
	slideAnimation.Priority = Enum.AnimationPriority.Action2

	slideEnterAnimation:Play(0.1)
	slideAnimation:Play(0.1)

	character:SetAttribute("Sliding", true)
	humanoid.JumpPower = 25

	SlideSound:Resume()
	TweenService:Create(SlideSound, slideTweenInfo, { Volume = 0.3 }):Play()
end

function Slide.Stop()
	local character = localPlayer.Character
	local humanoid = character.Humanoid

	character:SetAttribute("Sliding", nil)

	local rootPart = character.HumanoidRootPart

	local SlideSound = rootPart:FindFirstChild("Slide")

	local slideAnimation = AnimationManager.GetTrack(humanoid.Animator, Assets.Animations.Parkour.SlideIdle)

	slideAnimation:Stop(0.1)

	humanoid.HipHeight = 0
	humanoid.WalkSpeed = 28
	humanoid.JumpPower = character:GetAttribute("MaxJumpPower") or 28

	CameraModule.LockVector = false

	SlideSound:Pause()
end

return Slide
