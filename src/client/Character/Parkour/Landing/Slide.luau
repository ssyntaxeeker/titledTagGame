--!strict
--[[
    Slide (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Owns the gameplay-relevant slide lifecycle for player characters and
    local training bots. Player-only camera and cooldown behavior remains in
    the no-argument wrappers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local CameraModule = require(ReplicatedStorage.Modules.Camera.CameraModule)
local CooldownManager = require(ReplicatedStorage.Vendor.CooldownManager)

local Assets = ReplicatedStorage.Assets
local localPlayer = Players.LocalPlayer
local slideTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
local slideFadeTweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Linear)

local Slide = {}

function Slide.CanStart(character: Model): (boolean, string?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false, "character has no humanoid" end
	if humanoid.FloorMaterial == Enum.Material.Air then return false, "character is airborne" end
	if humanoid.MoveDirection.Magnitude <= 0 then return false, "character is not moving" end
	if humanoid.WalkSpeed <= 24 then return false, "walk speed is too low" end
	if character:GetAttribute("Rolling") then return false, "character is rolling" end
	if character:GetAttribute("Sliding") then return false, "character is already sliding" end
	return true, nil
end

function Slide.StartForCharacter(character: Model): (boolean, string?)
	local canStart, reason = Slide.CanStart(character)
	if not canStart then return false, reason end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[Slide.StartForCharacter] character has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[Slide.StartForCharacter] character has no HumanoidRootPart")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	assert(animator, "[Slide.StartForCharacter] Humanoid has no Animator")

	humanoid.HipHeight = 0.2
	local slideSound = rootPart:FindFirstChild("Slide")
	if not slideSound then
		slideSound = Assets.Sounds.Slide:Clone()
		slideSound.Parent = rootPart
	end
	assert(slideSound:IsA("Sound"), "[Slide.StartForCharacter] Slide must be a Sound")

	local slideEnterAnimation = AnimationManager.GetTrack(animator, Assets.Animations.Parkour.SlideEnter)
	local slideAnimation = AnimationManager.GetTrack(animator, Assets.Animations.Parkour.SlideIdle)
	slideEnterAnimation.Priority = Enum.AnimationPriority.Action3
	slideAnimation.Priority = Enum.AnimationPriority.Action2
	slideEnterAnimation:Play(0.1)
	slideAnimation:Play(0.1)

	character:SetAttribute("Sliding", true)
	character:SetAttribute("SlideStartedAt", os.clock())
	character:SetAttribute("LastSlideStartedAt", os.clock())
	character:SetAttribute("SlideAirborneAt", nil)
	character:SetAttribute("SlideSlopeSpeed", 1)
	character:SetAttribute("SlideSlopeAcceleration", 1.5)
	slideSound:Resume()
	TweenService:Create(slideSound, slideTweenInfo, { Volume = 1 }):Play()
	return true, nil
end

function Slide.StopForCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[Slide.StopForCharacter] character has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[Slide.StopForCharacter] character has no HumanoidRootPart")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	assert(animator, "[Slide.StopForCharacter] Humanoid has no Animator")

	character:SetAttribute("LastSlideStoppedAt", os.clock())
	character:SetAttribute("Sliding", nil)
	character:SetAttribute("SlideStartedAt", nil)
	character:SetAttribute("SlideAirborneAt", nil)
	local slideAnimation = AnimationManager.GetTrack(animator, Assets.Animations.Parkour.SlideIdle)
	slideAnimation:Stop(0.1)
	humanoid.HipHeight = 0

	local slideSound = rootPart:FindFirstChild("Slide")
	if slideSound and slideSound:IsA("Sound") then
		local fade = TweenService:Create(slideSound, slideFadeTweenInfo, { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			if not character:GetAttribute("Sliding") and slideSound.Volume <= 0.01 then slideSound:Pause() end
		end)
	end
end

function Slide.Start(): boolean
	if CooldownManager.getCooldown(localPlayer, "Slide") == true then return false end
	local character = localPlayer.Character
	if not character then return false end
	local started = Slide.StartForCharacter(character)
	if not started then return false end
	CooldownManager.modifyCooldown(localPlayer, "Slide", true, 0.5)
	CameraModule.LockVector = true
	return true
end

function Slide.Stop()
	local character = localPlayer.Character
	assert(character, "[Slide.Stop] local player has no character")
	Slide.StopForCharacter(character)
	CameraModule.LockVector = false
end

return table.freeze(Slide)
