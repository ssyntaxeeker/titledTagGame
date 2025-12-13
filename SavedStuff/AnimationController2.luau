local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local Schedules = require(ReplicatedStorage.Shared.Schedules)

local Assets = ReplicatedStorage.Assets
local Animations = Assets.Animations.Player

local localPlayer = Players.LocalPlayer

local pose = "Standing"
local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1.0
local animTable = {}

local function configureAnimationSet(name, folder)
	animTable[name] = { count = 0, totalWeight = 0 }

	for _, anim in folder:GetChildren() do
		if not anim:IsA("Animation") then continue end

		local weight = anim:FindFirstChild("Weight") and anim.Weight.Value or 1
		animTable[name][animTable[name].count + 1] = { anim = anim, weight = weight }
		animTable[name].count += 1
		animTable[name].totalWeight += weight
	end
end

for _, folder in Animations:GetChildren() do
	configureAnimationSet(folder.Name, folder)
end

local function stopAllAnimations()
	currentAnim = ""
	currentAnimInstance = nil
	if currentAnimKeyframeHandler then currentAnimKeyframeHandler:Disconnect() end
	if currentAnimTrack then
		currentAnimTrack:Stop()
		currentAnimTrack = nil
	end
end

local function setAnimationSpeed(speed)
	if speed ~= currentAnimSpeed then
		currentAnimSpeed = speed
		if currentAnimTrack then currentAnimTrack:AdjustSpeed(currentAnimSpeed) end
	end
end

local function keyFrameReachedFunc(frameName)
	if frameName == "End" then
		local repeatAnim = currentAnim
		playAnimation(repeatAnim, 0.0)
		setAnimationSpeed(currentAnimSpeed)
	end
end

function playAnimation(animName, transitionTime)
	if not animTable[animName] or animTable[animName].count == 0 then animName = "idle" end

	local roll = math.random(1, animTable[animName].totalWeight)
	local idx = 1

	while roll > animTable[animName][idx].weight do
		roll -= animTable[animName][idx].weight
		idx += 1
	end

	local anim = animTable[animName][idx].anim

	if anim ~= currentAnimInstance then
		if currentAnimTrack then currentAnimTrack:Stop(transitionTime) end

		local animTrack = AnimationManager.GetTrack(localPlayer.Character.Humanoid.Animator, anim)
		currentAnimTrack = animTrack
		currentAnimTrack.Priority = Enum.AnimationPriority.Core
		currentAnimTrack:Play(transitionTime)
		currentAnim = animName
		currentAnimInstance = anim

		if currentAnimKeyframeHandler then currentAnimKeyframeHandler:Disconnect() end

		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:Connect(keyFrameReachedFunc)
	end
end

local jumpAnimTime = 0
local lastTick = 0

local function onRunning(speed)
	if speed > 0.01 then
		playAnimation("walk", 0.1)
		setAnimationSpeed(speed / 14.5)
		pose = "Running"
	else
		playAnimation("idle", 0.1)
		pose = "Standing"
	end
end

local function onDied()
	pose = "Dead"
end

local function onJumping()
	local jumpAnims = { "jump", "rjump1", "rjump2" }
	local selectedJump = jumpAnims[math.random(1, #jumpAnims)]
	playAnimation(selectedJump, 0.1)
	jumpAnimTime = 0.3
	pose = "Jumping"
end

local function onClimbing(speed)
	playAnimation("climb", 0.1)
	setAnimationSpeed(speed / 12.0)
	pose = "Climbing"
end

local function onFreeFall()
	if jumpAnimTime <= 0 then playAnimation("fall", 0.3) end
	pose = "FreeFall"
end

local function onSeated()
	pose = "Seated"
end

local function move(time)
	local deltaTime = time - lastTick
	lastTick = time
	if jumpAnimTime > 0 then
		jumpAnimTime -= deltaTime
	end
	if pose == "FreeFall" and jumpAnimTime <= 0 then
		playAnimation("fall", 0.3)
	elseif pose == "Seated" then
		playAnimation("sit", 0.5)
	elseif pose == "Running" then
		playAnimation("walk", 0.1)
	elseif pose == "Dead" then
		stopAllAnimations()
	end
end

local function initCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(onDied)
	humanoid.Running:Connect(onRunning)
	humanoid.Jumping:Connect(onJumping)
	humanoid.Climbing:Connect(onClimbing)
	humanoid.FreeFalling:Connect(onFreeFall)
	humanoid.Seated:Connect(onSeated)

	playAnimation("idle", 0.1)
	pose = "Standing"

	while character.Parent do
		local _, time = task.wait(0.1)
		move(time)
	end
end

local function start()
	localPlayer.CharacterAdded:Connect(initCharacter)

	local character = localPlayer.Character
	if character then initCharacter(character) end
end

return Schedules.Boot.job(start)
