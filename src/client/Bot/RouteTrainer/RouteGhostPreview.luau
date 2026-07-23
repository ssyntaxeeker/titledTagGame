--!strict
--[[
    RouteGhostPreview (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Replays authored attempts through a non-colliding animated world ghost.
    This module owns and replaces its active preview model and playback task.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerConfig)
local Types = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerTypes)

type RAttempt = Types.RAttempt

local RouteGhostPreview = {}
local generation = 0
local activeGhost: Model? = nil

local ANIMATION_NAMES = table.freeze({
	Run = "Run",
	Jump = "Jump1",
	Vault = "Vault",
	Swing = "Swing",
	Walljump = "Walljump",
	Wallrun = "WallrunRight",
	Zipline = "Zipline",
	Rail = "Rail",
	Rope = "Rope",
	Crouch = "Crouch",
	Slide = "SlideIdle",
	SlideBoost = "SlideIdle",
	Tramp = "Vault",
	Roll = "Roll",
	RollBoost = "Roll",
	Drop = "Fall",
})

local function stop()
	generation += 1
	if activeGhost then activeGhost:Destroy() end
	activeGhost = nil
end

local function createGhost(): (Model, BasePart, Animator, CFrame)
	local character = Players.LocalPlayer.Character
	assert(character, "[RouteGhostPreview.createGhost] local player has no character")
	local wasArchivable = character.Archivable
	character.Archivable = true
	local ghost = character:Clone()
	character.Archivable = wasArchivable
	ghost.Name = "RoutePreviewGhost"
	for _, descendant in ghost:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Tool") or descendant:IsA("Sound") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Transparency = math.max(descendant.Transparency, Config.ghostTransparency)
		end
	end
	local humanoid = ghost:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "[RouteGhostPreview.createGhost] cloned character has no Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local root = ghost:FindFirstChild("HumanoidRootPart")
	assert(root and root:IsA("BasePart"), "[RouteGhostPreview.createGhost] cloned character has no root")
	root.Anchored = true
	ghost.PrimaryPart = root
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(80, 205, 255)
	highlight.FillTransparency = 0.65
	highlight.OutlineColor = Color3.fromRGB(210, 245, 255)
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = ghost
	local rootToPivot = root.CFrame:ToObjectSpace(ghost:GetPivot())
	ghost.Parent = workspace
	return ghost, root, animator, rootToPivot
end

local function playAction(animator: Animator, action: string, activeTrack: AnimationTrack?): AnimationTrack?
	local animationName = ANIMATION_NAMES[action]
	if not animationName then return activeTrack end
	local asset = ReplicatedStorage.Assets.Animations:FindFirstChild(animationName, true)
	if not asset or not asset:IsA("Animation") then return activeTrack end
	if activeTrack then activeTrack:Stop(0.08) end
	local track = animator:LoadAnimation(asset)
	track:Play(0.08)
	return track
end

function RouteGhostPreview.play(attempt: RAttempt): (boolean, string)
	if #attempt.points < 2 then return false, "Attempt has no previewable movement." end
	stop()
	local previewGeneration = generation
	local ghost, _, animator, rootToPivot = createGhost()
	activeGhost = ghost
	task.spawn(function()
		local activeTrack: AnimationTrack? = nil
		local previousAction = ""
		for index = 1, #attempt.points - 1 do
			if generation ~= previewGeneration or not ghost.Parent then return end
			local first = attempt.points[index]
			local second = attempt.points[index + 1]
			local action = attempt.actions[index] or "Run"
			if action ~= previousAction then activeTrack = playAction(animator, action, activeTrack) end
			previousAction = action
			local firstPosition = Vector3.new(first[1], first[2], first[3])
			local secondPosition = Vector3.new(second[1], second[2], second[3])
			local firstLook = Vector3.new(first[5], first[6], first[7])
			local secondLook = Vector3.new(second[5], second[6], second[7])
			local segmentSeconds = math.max((second[4] - first[4]) / Config.ghostPlaybackSpeed, 1 / 120)
			local elapsed = 0
			while elapsed < segmentSeconds do
				if generation ~= previewGeneration or not ghost.Parent then return end
				elapsed += RunService.Heartbeat:Wait()
				local alpha = math.clamp(elapsed / segmentSeconds, 0, 1)
				local position = firstPosition:Lerp(secondPosition, alpha)
				local look = firstLook:Lerp(secondLook, alpha)
				if look.Magnitude < 0.01 then look = Vector3.zAxis end
				ghost:PivotTo(CFrame.lookAt(position, position + look.Unit) * rootToPivot)
			end
		end
		if activeTrack then activeTrack:Stop(0.1) end
		task.wait(0.6)
		if generation == previewGeneration then stop() end
	end)
	return true, "Previewing attempt in the world."
end

function RouteGhostPreview.stop()
	stop()
end

return table.freeze(RouteGhostPreview)
