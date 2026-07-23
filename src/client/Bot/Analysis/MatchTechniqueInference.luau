--!strict
--[[
    MatchTechniqueInference (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Infers known and novel movement techniques from replicated character
    motion, animation evidence, character state, and nearby map geometry.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisConfig)
local Types = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisTypes)
local Net = require(ReplicatedStorage.Packages.Net)

type RFrame = Types.RFrame
type RGeometry = Types.RGeometry
type Technique = Types.Technique

type RSequenceState = {
	sliding: boolean,
	slideStartedAt: number,
	slideStoppedAt: number,
	wallLook: Vector3?,
	flickedAt: number,
	returnedAt: number,
	jumpedAt: number,
}

local MatchTechniqueInference = {}
local lastAnimationPoll: { [Player]: number } = {}
local animationText: { [Player]: string } = {}
local remoteEvidence: { [Model]: { action: Technique, time: number, value: number? } } = {}
local affordanceCache: { [Instance]: { [string]: { boolean } } } = {}
local raycastParamsCache: { [Instance]: RaycastParams } = {}
local sequenceStates: { [Player]: RSequenceState } = {}

Net:RemoteEvent("PlaySound").OnClientEvent:Connect(function(soundName: any, root: any, value: any)
	if typeof(soundName) ~= "string" or not root or not root:IsA("BasePart") then return end
	local character = root.Parent
	if not character or not character:IsA("Model") then return end
	local action: Technique?
	if soundName == "Vault" then action = "Vault"
	elseif soundName == "Roll" then action = "Roll"
	elseif soundName == "Swing" then action = "Swing"
	elseif soundName == "WallJump" then action = "Walljump"
	elseif soundName == "Trampoline" then action = "Trampoline"
	end
	if action then remoteEvidence[character] = { action = action, time = os.clock(), value = tonumber(value) } end
end)


local function raycastParams(map: Instance): RaycastParams
	local cached = raycastParamsCache[map]
	if cached then return cached end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.IgnoreWater = true
	raycastParamsCache[map] = params
	return params
end

local function animationEvidence(player: Player, humanoid: Humanoid): string
	local now = os.clock()
	if now - (lastAnimationPoll[player] or 0) < Config.animationPollInterval then
		return animationText[player] or ""
	end
	lastAnimationPoll[player] = now
	local names = {}
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			local animation = track.Animation
			names[#names + 1] = string.lower(`{track.Name} {if animation then animation.Name else ""}`)
		end
	end
	local text = table.concat(names, " ")
	animationText[player] = text
	return text
end

local function nearbyAffordances(position: Vector3, map: Instance): (boolean, boolean)
	local mapCache = affordanceCache[map]
	if not mapCache then
		mapCache = {}
		affordanceCache[map] = mapCache
	end
	local key = `{math.floor(position.X / Config.cellSize)}:{math.floor(position.Y / Config.cellSize)}:{math.floor(position.Z / Config.cellSize)}`
	local cached = mapCache[key]
	if cached then return cached[1], cached[2] end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.MaxParts = 40
	local swingBar = false
	local trampoline = false
	for _, instance in Workspace:GetPartBoundsInRadius(position, Config.nearbyTechRadius, params) do
		local parent = instance.Parent
		swingBar = swingBar
			or CollectionService:HasTag(instance, "SwingBar")
			or instance:GetAttribute("SwingBar") == true
			or (parent ~= nil and parent:GetAttribute("SwingBar") == true)
		trampoline = trampoline or CollectionService:HasTag(instance, "Trampoline")
		if swingBar and trampoline then break end
	end
	mapCache[key] = { swingBar, trampoline }
	return swingBar, trampoline
end

local function geometry(root: BasePart, map: Instance): RGeometry
	local params = raycastParams(map)
	local floor = Workspace:Raycast(root.Position + Vector3.yAxis, -Vector3.yAxis * (Config.groundProbeDistance + 1), params)
	local roof = Workspace:Raycast(root.Position, Vector3.yAxis * 20, params)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local wall = if look.Magnitude > 0.01
		then Workspace:Raycast(root.Position, look.Unit * Config.wallProbeDistance, params)
		else nil
	local floorY = if floor then floor.Position.Y else root.Position.Y - 2.75
	local wallHeight = 0
	if wall then
		local wallTopProbe = Workspace:Raycast(
			wall.Position + Vector3.yAxis * 18 - wall.Normal * 0.2,
			-Vector3.yAxis * 20,
			params
		)
		if wallTopProbe then wallHeight = wallTopProbe.Position.Y - floorY end
	end
	local nearSwingBar, nearTrampoline = nearbyAffordances(root.Position, map)
	return {
		floorY = floorY,
		headroom = if roof then roof.Distance else 20,
		wallDistance = if wall then wall.Distance else Config.wallProbeDistance,
		wallHeight = wallHeight,
		nearSwingBar = nearSwingBar,
		nearTrampoline = nearTrampoline,
	}
end

function MatchTechniqueInference.sample(player: Player, previous: RFrame?, map: Instance): RFrame?
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then return nil end
	local now = os.clock()
	local velocity = root.AssemblyLinearVelocity
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local animations = animationEvidence(player, humanoid)
	local action: Technique = "Run"
	local techValue: number? = nil
	local isLocal = player == Players.LocalPlayer
	local sliding = (isLocal and character:GetAttribute("Sliding") == true) or string.find(animations, "slide", 1, true) ~= nil
	local rolling = (isLocal and character:GetAttribute("Rolling") == true) or string.find(animations, "roll", 1, true) ~= nil
	local vaulting = (isLocal and character:GetAttribute("Vaulting") == true) or string.find(animations, "vault", 1, true) ~= nil
	local swinging = (isLocal and character:GetAttribute("Swinging") == true) or string.find(animations, "swing", 1, true) ~= nil
	local wallrunning = (isLocal and character:GetAttribute("Wallrunning") == true)
		or string.find(animations, "wallrun", 1, true) ~= nil
	local walljumping = (isLocal and character:GetAttribute("Walljumping") == true)
		or string.find(animations, "walljump", 1, true) ~= nil
	local ziplining = (isLocal and character:GetAttribute("Ziplining") == true)
		or string.find(animations, "zipline", 1, true) ~= nil
	local railGrinding = (isLocal and character:GetAttribute("RailGrinding") == true)
		or string.find(animations, "rail", 1, true) ~= nil
	local ropeSwinging = (isLocal and character:GetAttribute("RopeSwinging") == true)
	local inWindforce = isLocal and character:GetAttribute("InWindzone") == true
	local crouching = (isLocal and character:GetAttribute("Crouching") == true)
		or string.find(animations, "crouch", 1, true) ~= nil
	local info = geometry(root, map)
	local evidence = remoteEvidence[character]
	local sequence = sequenceStates[player]
	if not sequence then
		sequence = {
			sliding = false,
			slideStartedAt = 0,
			slideStoppedAt = 0,
			wallLook = nil,
			flickedAt = 0,
			returnedAt = 0,
			jumpedAt = 0,
		}
		sequenceStates[player] = sequence
	end
	if sliding and not sequence.sliding then sequence.slideStartedAt = now end
	if not sliding and sequence.sliding then sequence.slideStoppedAt = now end
	sequence.sliding = sliding
	if isLocal then
		sequence.slideStartedAt = tonumber(character:GetAttribute("LastSlideStartedAt")) or sequence.slideStartedAt
		sequence.slideStoppedAt = tonumber(character:GetAttribute("LastSlideStoppedAt")) or sequence.slideStoppedAt
	end

	local launched = previous ~= nil and previous.grounded and not grounded and velocity.Y > 1
	if launched then sequence.jumpedAt = now end
	if previous then
		local previousLook = previous.look * Vector3.new(1, 0, 1)
		local currentLook = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if previousLook.Magnitude > 0.01 and currentLook.Magnitude > 0.01 then
			previousLook = previousLook.Unit
			currentLook = currentLook.Unit
			if previous.geometry.wallDistance <= Config.trampWallDistance
				and Vector3.new(previous.velocity.X, 0, previous.velocity.Z).Magnitude >= Config.trampMinimumSpeed
				and previousLook:Dot(currentLook) <= Config.trampFlickDot
			then
				sequence.wallLook = previousLook
				sequence.flickedAt = now
			elseif sequence.wallLook
				and now - sequence.flickedAt <= Config.techSequenceWindow
				and sequence.wallLook:Dot(currentLook) >= Config.trampReturnDot
			then
				sequence.returnedAt = now
			end
		end
	end
	local recentWalljumpAt = if isLocal then tonumber(character:GetAttribute("LastWalljumpAt")) or 0 else 0
	local walljumpEvidence = walljumping
		or recentWalljumpAt > 0 and now - recentWalljumpAt <= 0.3
		or evidence ~= nil and evidence.action == "Walljump" and now - evidence.time <= 0.25
	local vaultEvidence = vaulting
		or evidence ~= nil and evidence.action == "Vault" and now - evidence.time <= 0.25
	local trampDetected = vaultEvidence
		and now - sequence.returnedAt <= Config.techSequenceWindow
		and now - sequence.jumpedAt <= Config.techSequenceWindow
	local slideDuration = sequence.slideStoppedAt - sequence.slideStartedAt
	local slideBoostDetected = launched
		and sequence.slideStoppedAt >= sequence.slideStartedAt
		and slideDuration >= 0.04
		and slideDuration <= Config.slideBoostMaximumSlideSeconds
		and now - sequence.slideStoppedAt <= Config.slideBoostMaximumCancelToJump

	if slideBoostDetected or (previous and previous.action == "Slide" and now - previous.time <= 0.5 and velocity.Y > 2) then
		action = "SlideBoost"
	elseif previous and previous.action == "Roll" and now - previous.time <= 0.5 and velocity.Y > 2 then
		action = "RollBoost"
	elseif walljumpEvidence then
		action = "Walljump"
		techValue = if evidence and evidence.action == "Walljump" then evidence.value else math.abs(if previous then previous.velocity.Y else velocity.Y)
	elseif trampDetected then
		action = "Tramp"
		sequence.wallLook = nil
		sequence.flickedAt = 0
		sequence.returnedAt = 0
		sequence.jumpedAt = 0
	elseif evidence and now - evidence.time <= 0.25 then
		action = evidence.action
		techValue = evidence.value
	elseif swinging then
		action = "Swing"
	elseif wallrunning then
		action = "Wallrun"
	elseif ziplining then
		action = "Zipline"
	elseif railGrinding then
		action = "Rail"
	elseif ropeSwinging then
		action = "Rope"
	elseif vaulting then
		action = "Vault"
	elseif rolling then
		action = "Roll"
	elseif sliding then
		action = "Slide"
	elseif inWindforce then
		action = "Windforce"
	elseif crouching then
		action = "Crouch"
	elseif info.nearTrampoline and previous and velocity.Y - previous.velocity.Y >= 35 then
		action = "Trampoline"
	elseif previous and previous.grounded and velocity.Y > 1 then
		action = "Jump"
	elseif not grounded and velocity.Y < -10 then
		action = "Drop"
	elseif previous then
		local dt = math.max(now - previous.time, 1 / 120)
		local expectedVelocity = previous.velocity - Vector3.yAxis * Workspace.Gravity * dt
		local unexplainedAcceleration = (velocity - expectedVelocity).Magnitude / dt
		local verticalImpulse = velocity.Y - expectedVelocity.Y
		local previousFlat = Vector3.new(previous.velocity.X, 0, previous.velocity.Z)
		local currentFlat = Vector3.new(velocity.X, 0, velocity.Z)
		local groundedSpeedBurst = (currentFlat - previousFlat).Magnitude >= 12
		if (not grounded and (unexplainedAcceleration >= Config.unknownAcceleration
			or math.abs(verticalImpulse) >= Config.unknownVerticalImpulse))
			or (grounded and groundedSpeedBurst)
		then
			action = "UnknownTech"
		end
	end

	return {
		time = now,
		position = root.Position,
		velocity = velocity,
		moveDirection = humanoid.MoveDirection,
		look = root.CFrame.LookVector,
		walkSpeed = humanoid.WalkSpeed,
		grounded = grounded,
		action = action,
		techValue = techValue,
		geometry = info,
	}
end

function MatchTechniqueInference.clear(player: Player)
	lastAnimationPoll[player] = nil
	animationText[player] = nil
	sequenceStates[player] = nil
	if player.Character then remoteEvidence[player.Character] = nil end
end

return table.freeze(MatchTechniqueInference)
