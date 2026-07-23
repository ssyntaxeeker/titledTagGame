--!strict
--[[
    BotRuntime (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Runtime presentation helpers for local training bots: role visuals,
    animation tracks, and movement sounds. Split from BotTrainer to keep the
    trainer module below Luau's local register limit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationManager = require(ReplicatedStorage.Modules.Animations.AnimationManager)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)
local SteppingSounds = require(ReplicatedStorage.Modules.StepsSound.SteppingSounds)

local Assets = ReplicatedStorage.Assets
local RoleConfigsStorage = ReplicatedStorage.Shared.Configs.Roles

local BotRuntime = {}

local botAnimationTracks: { [Model]: { [string]: AnimationTrack } } = {}
local botLastStepTimes: { [Model]: number } = {}
local botLastFloorMaterials: { [Model]: Enum.Material } = {}
local botLastFallVelocities: { [Model]: number } = {}

local function getRoleConfig(roleName: string): { [string]: any }?
	local roleModule = RoleConfigsStorage:FindFirstChild(roleName)
	if not roleModule or not roleModule:IsA("ModuleScript") then return nil end

	return require(roleModule)
end

local function isRoleColoredPart(partName: string): boolean
	return partName == "Torso"
		or partName == "UpperTorso"
		or partName == "LowerTorso"
		or partName == "Left Leg"
		or partName == "Right Leg"
		or partName == "LeftUpperLeg"
		or partName == "LeftLowerLeg"
		or partName == "LeftFoot"
		or partName == "RightUpperLeg"
		or partName == "RightLowerLeg"
		or partName == "RightFoot"
end

local function playTrack(track: AnimationTrack?, fadeTime: number?)
	if track and not track.IsPlaying then track:Play(fadeTime or 0.12) end
end

local function stopTrack(track: AnimationTrack?, fadeTime: number?)
	if track and track.IsPlaying then track:Stop(fadeTime or 0.12) end
end

local function getBotAnimator(humanoid: Humanoid): Animator?
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then return animator end

	local newAnimator = Instance.new("Animator")
	newAnimator.Parent = humanoid
	return newAnimator
end

function BotRuntime.applyRoleVisuals(bot: Model, roleName: string)
	local roleConfig = getRoleConfig(roleName)
	local roleColor = if roleConfig and typeof(roleConfig.Color) == "Color3" then roleConfig.Color else Color3.fromRGB(220, 220, 220)

	bot:SetAttribute("Role", roleName)
	bot.Name = `Training{roleName}Bot`
	for _, descendant in bot:GetDescendants() do
		if descendant:IsA("BasePart") and isRoleColoredPart(descendant.Name) then
			descendant.Color = roleColor
		elseif descendant:IsA("BodyColors") then
			descendant.LeftLegColor3 = roleColor
			descendant.RightLegColor3 = roleColor
			descendant.TorsoColor3 = roleColor
		end
	end

	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = `Training {roleName}`
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
end

function BotRuntime.updateNtbVisuals(bot: Model)
	local durability = bot:GetAttribute("NTBDurability")
	durability = if typeof(durability) == "number" then durability else 0
	local roleConfig = getRoleConfig(if typeof(bot:GetAttribute("Role")) == "string" then bot:GetAttribute("Role") :: string else "Runner")
	local color = if roleConfig and typeof(roleConfig.NoTagBackColor) == "Color3"
		then roleConfig.NoTagBackColor
		elseif roleConfig and typeof(roleConfig.Color) == "Color3" then roleConfig.Color
		else Color3.fromRGB(255, 80, 80)

	for _, child in bot:GetChildren() do
		if not child:IsA("BasePart") or child.Name == "HumanoidRootPart" then continue end

		local box = child:FindFirstChild("NTBBreakHighlight")
		if durability > 0 then
			if not box then
				local newBox = Instance.new("SelectionBox")
				newBox.Name = "NTBBreakHighlight"
				newBox.Adornee = child
				newBox.LineThickness = 0.07
				newBox.Transparency = 0.15
				newBox.Parent = child
				box = newBox
			end
			if box:IsA("SelectionBox") then box.Color3 = color end
		elseif box then
			box:Destroy()
		end
	end
end

function BotRuntime.initAnimations(bot: Model, humanoid: Humanoid)
	local animator = getBotAnimator(humanoid)
	if not animator then return end

	local animations = Assets:FindFirstChild("Animations")
	if not animations then return end

	local playerAnimations = animations:FindFirstChild("Player")
	local parkourAnimations = animations:FindFirstChild("Parkour")
	if not playerAnimations or not parkourAnimations then return end

	local tracks: { [string]: AnimationTrack } = {}

	local function loadTrack(name: string, folder: Instance)
		local animation = folder:FindFirstChild(name)
		if not animation or not animation:IsA("Animation") then return end

		local track = AnimationManager.GetTrack(animator, animation)
		if track then tracks[name] = track end
	end

	for _, name in { "Idle", "Run", "Fall", "Jump1", "Jump2", "Crouch" } do
		loadTrack(name, playerAnimations)
	end

	for _, name in { "Vault", "Swing", "Roll", "SlideEnter", "SlideIdle" } do
		loadTrack(name, parkourAnimations)
	end

	botAnimationTracks[bot] = tracks

	playTrack(tracks.Idle, 0)
	playTrack(tracks.Run, 0)
	if tracks.Run then tracks.Run:AdjustWeight(0.01, 0) end
end

function BotRuntime.updateAnimations(bot: Model?, humanoid: Humanoid?, rootPart: BasePart?)
	if not bot or not humanoid or not rootPart then return end

	local tracks = botAnimationTracks[bot]
	if not tracks then return end

	local horizontalSpeed = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude
	local moving = humanoid.MoveDirection.Magnitude > 0.05 or horizontalSpeed > 1
	local airborne = humanoid.FloorMaterial == Enum.Material.Air

	playTrack(tracks.Idle, 0.15)
	playTrack(tracks.Run, 0.15)

	if tracks.Run then
		tracks.Run:AdjustWeight(if moving and not airborne then math.clamp(horizontalSpeed / 32, 0.05, 1) else 0.01, 0.12)
		tracks.Run:AdjustSpeed(math.clamp(horizontalSpeed / 32, 0.1, 2.5))
	end

	if airborne then
		playTrack(tracks.Fall, 0.18)
	else
		stopTrack(tracks.Fall, 0.1)
	end

	if bot:GetAttribute("Sliding") then
		playTrack(tracks.SlideIdle, 0.08)
	else
		stopTrack(tracks.SlideIdle, 0.1)
	end
end

function BotRuntime.playActionAnimation(bot: Model?, actionName: string)
	if not bot then return end

	local tracks = botAnimationTracks[bot]
	if not tracks then return end

	local track = tracks[actionName]
	if not track then return end

	track:Play(0.08)
end

function BotRuntime.initMovementState(bot: Model, humanoid: Humanoid)
	botLastFloorMaterials[bot] = humanoid.FloorMaterial
	botLastFallVelocities[bot] = 0
end

function BotRuntime.updateMovementSounds(bot: Model?, humanoid: Humanoid?, rootPart: BasePart?, horizontalSpeed: number)
	if not bot or not humanoid or not rootPart then return end
	if not bot.Parent or not humanoid.Parent or not rootPart.Parent then return end

	local previousFloorMaterial = botLastFloorMaterials[bot] or humanoid.FloorMaterial
	local currentFloorMaterial = humanoid.FloorMaterial
	local previousFallVelocity = botLastFallVelocities[bot] or rootPart.AssemblyLinearVelocity.Y

	if previousFloorMaterial == Enum.Material.Air and currentFloorMaterial ~= Enum.Material.Air and previousFallVelocity < -18 then
		PlaySound("Land", rootPart, previousFallVelocity)
	end

	botLastFloorMaterials[bot] = currentFloorMaterial
	botLastFallVelocities[bot] = rootPart.AssemblyLinearVelocity.Y

	if bot:GetAttribute("Sliding") or bot:GetAttribute("Vaulting") or bot:GetAttribute("Swinging") or bot:GetAttribute("Rolling") then return end
	if humanoid.FloorMaterial == Enum.Material.Air then return end
	if horizontalSpeed < 4 then return end

	local now = os.clock()
	local stepDelay = math.clamp(0.34 - horizontalSpeed / 170, 0.12, 0.3)
	if botLastStepTimes[bot] and now - botLastStepTimes[bot] < stepDelay then return end
	botLastStepTimes[bot] = now

	local stepSoundMaterial = SteppingSounds[humanoid.FloorMaterial] or SteppingSounds.Default
	local soundInfo = stepSoundMaterial[math.random(1, #stepSoundMaterial)]
	local soundAssets = Assets:FindFirstChild("Sounds")
	if not soundAssets then return end

	local stepTemplate = soundAssets:FindFirstChild("StepSound")
	if not stepTemplate or not stepTemplate:IsA("Sound") then return end

	local stepSound = stepTemplate:Clone()
	stepSound.SoundId = soundInfo.Id
	stepSound.Parent = rootPart
	stepSound:Play()
	task.delay(stepSound.TimeLength + 0.1, function()
		stepSound:Destroy()
	end)
end

return BotRuntime
