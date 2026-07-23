--!strict
--[[
    BotTrainer (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/15

    Local-only training sandbox for a tagger NPC. The trainer builds a walkable
    map graph, drives a client NPC toward the local player, and records simple
    route/action scores so fixed-map behavior improves over repeated chases.
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BotPolicyNetwork = require(ReplicatedStorage.Modules.Bot.BotPolicyNetwork)
local BotRankBias = require(ReplicatedStorage.Modules.Bot.BotRankBias)
local BotRuntime = require(ReplicatedStorage.Modules.Bot.BotRuntime)
local BotTechHints = require(ReplicatedStorage.Modules.Bot.BotTechHints)
local BotTrainerBootstrap = require(ReplicatedStorage.Modules.Bot.BotTrainerBootstrap)
local Config = require(ReplicatedStorage.Modules.Bot.BotTrainerConfig)
local KnockbackVelocity = require(ReplicatedStorage.Modules.FX.KnockbackVelocity)
local PlaySound = require(ReplicatedStorage.Modules.FX.PlaySound)

local BotTagRF = require(ReplicatedStorage.Packages.Net):RemoteFunction("BotTag")

type GraphNode = {
	id: number,
	position: Vector3,
	partName: string,
	links: { number },
	linkTechs: { [number]: string },
	score: number,
	visits: number,
	barrierPenalty: number,
	deadEndPenalty: number,
	wallPenalty: number,
	openDirections: number,
}

type DirectionScore = {
	score: number,
	visits: number,
}

type LearnParams = {
	progressWeight: number,
	exploreWeight: number,
	runnerDistanceWeight: number,
	orbitWeight: number,
	verticalRollWeight: number,
	routeOptionWeight: number,
	backtrackWeight: number,
	localVaultWeight: number,
}

type LocalVaultInfo = {
	part: BasePart,
	position: Vector3,
	direction: Vector3,
	heightDelta: number,
	approachDistance: number,
	techKey: string,
	key: string,
}

type LocalGeometryCacheEntry = {
	candidates: { LocalVaultInfo },
}

type TechAttemptInfo = {
	key: string,
	routeKey: string,
	geometryKey: string?,
	startPosition: Vector3,
	targetPosition: Vector3,
	startDistance: number,
	startHeight: number,
	startTime: number,
	moveDirection: Vector3,
}

type PlayerActionInfo = {
	lastInputName: string,
	lastInputTime: number,
	lastParkourName: string,
	lastParkourTime: number,
	airborne: boolean,
	fallVelocity: number,
	speed: number,
}

type TargetMode = "Player" | "AI"
type SelectedAI = "Tagger" | "Runner"
type SaveRoleName = "tagger" | "runner"

type RoutePointInfo = {
	position: Vector3,
	action: string,
	partName: string?,
	studs: number?,
}

type RouteInfo = {
	id: string,
	name: string,
	points: { RoutePointInfo },
	maxTime: number,
	maxVaults: number,
	maxSwings: number,
	maxRolls: number,
	bestTime: number?,
	successes: number,
	failures: number,
}

type SelfTaughtRouteCandidate = {
	key: string,
	techKey: string,
	startPosition: Vector3,
	techPosition: Vector3,
	endPosition: Vector3,
	successes: number,
	failures: number,
	bestReward: number,
	lastUsedTime: number,
}

type BotState = {
	bot: Model?,
	humanoid: Humanoid?,
	rootPart: BasePart?,
	runnerBot: Model?,
	runnerHumanoid: Humanoid?,
	runnerRootPart: BasePart?,
	training: boolean,
	taggerEnabled: boolean,
	runnerEnabled: boolean,
	targetMode: TargetMode,
	selectedAI: SelectedAI,
	taggerBotRoleName: string,
	runnerBotRoleName: string,
	trainingSpeedMultiplier: number,
	taggerSpeedMultiplier: number,
	runnerSpeedMultiplier: number,
	uiScale: number,
	learnParams: LearnParams,
	useGraph: boolean,
	autoVault: boolean,
	autoCreateRoutes: boolean,
	debug: boolean,
	visualizeDebug: boolean,
	visualizeGraphDebug: boolean,
	graph: { GraphNode },
	nodeByKey: { [string]: { number } },
	directionScores: { [number]: DirectionScore },
	runnerDirectionScores: { [number]: DirectionScore },
	techScores: { [string]: DirectionScore },
	routeTechNotes: { [string]: DirectionScore },
	geometryScores: { [string]: DirectionScore },
	policyWeights: { [string]: number },
	playerModelScores: { [string]: DirectionScore },
	selfTaughtRouteCandidates: { [string]: SelfTaughtRouteCandidate },
	cutoffScores: { [string]: DirectionScore },
	activeTechAttempt: TechAttemptInfo?,
	lastTechTryTime: number,
	techExperimentCursor: number,
	lastVisualizationTime: number,
	graphRevision: number,
	visualizedGraphRevision: number,
	reactionTargetPosition: Vector3?,
	reactionTargetVelocity: Vector3,
	lastReactionSampleTime: number,
	lastCutoffKey: string?,
	path: { number },
	pathCursor: number,
	lastPathTime: number,
	pathFailureUntil: number,
	pathRequestBusy: boolean,
	pathRequestSerial: number,
	chaseStartTime: number,
	lastPosition: Vector3?,
	lastDistance: number?,
	lastChaseProgressDistance: number?,
	lastRewardTime: number,
	lastChaseProgressCheckTime: number,
	lastChaseReplanTime: number,
	lastTagTime: number,
	lastVaultCheckTime: number,
	lastSteeringCheckTime: number,
	steeredMoveDirection: Vector3,
	lastSidewaysCheckTime: number,
	sidewaysMoveDirection: Vector3,
	lastFaceDirection: Vector3,
	lastGraphDecisionTime: number,
	graphMoveTarget: Vector3?,
	graphMoveTech: string?,
	graphMoveTargetSetTime: number,
	runnerLastSteeringCheckTime: number,
	runnerSteeredMoveDirection: Vector3,
	runnerLastSidewaysCheckTime: number,
	runnerSidewaysMoveDirection: Vector3,
	runnerLastFaceDirection: Vector3,
	runnerLastGraphDecisionTime: number,
	runnerGraphMoveTarget: Vector3?,
	runnerGraphMoveTech: string?,
	runnerLastPosition: Vector3?,
	runnerStuckSeconds: number,
	runnerLastEscapeGoalId: number?,
	runnerEscapeGoalRepeat: number,
	runnerLapSign: number,
	runnerLastLapSwitchTime: number,
	runnerRoute: RouteInfo?,
	runnerRouteCursor: number,
	runnerRouteLastProgressTime: number,
	runnerRouteBestDistance: number,
	runnerLastDistance: number?,
	runnerLastRewardTime: number,
	runnerPath: { number },
	runnerPathCursor: number,
	runnerLastPathTime: number,
	runnerPathFailureUntil: number,
	runnerPathRequestBusy: boolean,
	runnerPathRequestSerial: number,
	lastParkourActionTime: number,
	lastBasicJumpTime: number,
	lastRollActionTime: number,
	lastRollSetupTime: number,
	lastRollPressTime: number?,
	lastFloorMaterial: Enum.Material,
	lastSlideTime: number,
	lastSlideCancelTime: number,
	lastTrampVaultTime: number,
	slideBoostInProgress: boolean,
	slideBoostCancelDelay: number,
	slideBoostJumpDelay: number,
	slideBoostKey: string?,
	slideBoostStartY: number,
	slideBoostScores: { [string]: DirectionScore },
	lastFallVelocity: number,
	actionInfo: PlayerActionInfo,
	trainingData: { [string]: any }?,
	currentVersionIds: { [SaveRoleName]: string? },
	selectedVersionIndexes: { [SaveRoleName]: number },
	lastAutoSaveTime: number,
	predictionLeadTime: number,
	lastPredictionError: number?,
	routes: { RouteInfo },
	routeCooldowns: { [string]: number },
	recordingRoute: boolean,
	playerRouteRecording: boolean,
	guidedTraining: boolean,
	guidedDestination: Vector3?,
	guidedDestinationIndex: number,
	guidedDestinationStartTime: number,
	guidedCompletions: number,
	lastGuidedNoDestinationLogTime: number,
	guidedRecentDestinations: { Vector3 },
	guidedTransitionBusy: boolean,
	lastGuidedSampleTime: number,
	lastPlayerRouteSampleTime: number,
	lastPlayerRouteSamplePosition: Vector3?,
	lastPlayerRouteActionName: string,
	playerRouteStartPosition: Vector3?,
	playerRouteStartedMoving: boolean,
	activeRoute: RouteInfo?,
	activeRoutePractice: boolean,
	activeRouteCursor: number,
	activeRouteStartTime: number,
	routeAttemptVaults: number,
	routeAttemptSwings: number,
	routeAttemptRolls: number,
	routeActionAttemptCursor: number,
	routeActionAttemptName: string?,
	lastRouteActionAttemptTime: number,
	lastRouteRecoveryJumpTime: number,
	routeVaultMissCursor: number,
	routeVaultMisses: number,
	routeVaultApproachSide: number,
	lastRouteVaultMissTime: number,
	routePreVaultJumpCursor: number,
	lastRoutePreVaultJumpTime: number,
	routeLastProgressTime: number,
	routeBestDistance: number,
	routeResetCount: number,
	editorOpen: boolean,
	editorCompact: boolean,
	teachCoachEnabled: boolean,
	teachCoachStep: number,
	editorSelectedRouteIndex: number,
	editorSelectedPointIndex: number,
	editorSelectedAction: string,
	editorTab: string,
	editorDraggingPointIndex: number?,
	editorDragDepth: number,
	editorDragOffset: Vector3,
	successes: number,
	attempts: number,
	stuckSeconds: number,
	graphStep: number,
	nodeCap: number,
}

local localPlayer = Players.LocalPlayer

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.MaxParts = 80

local state: BotState = {
	bot = nil,
	humanoid = nil,
	rootPart = nil,
	runnerBot = nil,
	runnerHumanoid = nil,
	runnerRootPart = nil,
	training = false,
	taggerEnabled = true,
	runnerEnabled = false,
	targetMode = "Player",
	selectedAI = "Tagger",
	taggerBotRoleName = "Tagger",
	runnerBotRoleName = "Runner",
	trainingSpeedMultiplier = 1,
	taggerSpeedMultiplier = 1,
	runnerSpeedMultiplier = 1,
	uiScale = 1,
	learnParams = {
		progressWeight = 1,
		exploreWeight = 1,
		runnerDistanceWeight = 1,
		orbitWeight = 1,
		verticalRollWeight = 1,
		routeOptionWeight = 1,
		backtrackWeight = 1,
		localVaultWeight = 1,
	},
	useGraph = true,
	autoVault = true,
	autoCreateRoutes = false,
	debug = false,
	visualizeDebug = false,
	visualizeGraphDebug = false,
	graph = {},
	nodeByKey = {},
	directionScores = {},
	runnerDirectionScores = {},
	techScores = {},
	routeTechNotes = {},
	geometryScores = {},
	policyWeights = {},
	playerModelScores = {},
	selfTaughtRouteCandidates = {},
	cutoffScores = {},
	activeTechAttempt = nil,
	lastTechTryTime = 0,
	techExperimentCursor = 1,
	lastVisualizationTime = 0,
	graphRevision = 0,
	visualizedGraphRevision = -1,
	reactionTargetPosition = nil,
	reactionTargetVelocity = Vector3.zero,
	lastReactionSampleTime = 0,
	lastCutoffKey = nil,
	path = {},
	pathCursor = 1,
	lastPathTime = 0,
	pathFailureUntil = 0,
	pathRequestBusy = false,
	pathRequestSerial = 0,
	chaseStartTime = 0,
	lastPosition = nil,
	lastDistance = nil,
	lastChaseProgressDistance = nil,
	lastRewardTime = 0,
	lastChaseProgressCheckTime = 0,
	lastChaseReplanTime = 0,
	lastTagTime = 0,
	lastVaultCheckTime = 0,
	lastSteeringCheckTime = 0,
	steeredMoveDirection = Vector3.zero,
	lastSidewaysCheckTime = 0,
	sidewaysMoveDirection = Vector3.zero,
	lastFaceDirection = Vector3.zero,
	lastGraphDecisionTime = 0,
	graphMoveTarget = nil,
	graphMoveTech = nil,
	graphMoveTargetSetTime = 0,
	runnerLastGraphDecisionTime = 0,
	runnerGraphMoveTarget = nil,
	runnerGraphMoveTech = nil,
	runnerLastPosition = nil,
	runnerStuckSeconds = 0,
	runnerLastEscapeGoalId = nil,
	runnerEscapeGoalRepeat = 0,
	runnerLapSign = 1,
	runnerLastLapSwitchTime = 0,
	runnerRoute = nil,
	runnerRouteCursor = 1,
	runnerRouteLastProgressTime = 0,
	runnerRouteBestDistance = math.huge,
	runnerLastDistance = nil,
	runnerLastRewardTime = 0,
	runnerPath = {},
	runnerPathCursor = 1,
	runnerLastPathTime = 0,
	runnerPathFailureUntil = 0,
	runnerPathRequestBusy = false,
	runnerPathRequestSerial = 0,
	runnerLastSteeringCheckTime = 0,
	runnerSteeredMoveDirection = Vector3.zero,
	runnerLastSidewaysCheckTime = 0,
	runnerSidewaysMoveDirection = Vector3.zero,
	runnerLastFaceDirection = Vector3.zero,
	lastParkourActionTime = 0,
	lastBasicJumpTime = 0,
	lastRollActionTime = 0,
	lastRollSetupTime = 0,
	lastRollPressTime = nil,
	lastFloorMaterial = Enum.Material.Air,
		lastSlideTime = 0,
		lastSlideCancelTime = 0,
		lastTrampVaultTime = 0,
		slideBoostInProgress = false,
	slideBoostCancelDelay = 0.52,
	slideBoostJumpDelay = 0.12,
	slideBoostKey = nil,
	slideBoostStartY = 0,
	slideBoostScores = {},
	lastFallVelocity = 0,
	actionInfo = {
		lastInputName = "None",
		lastInputTime = 0,
		lastParkourName = "None",
		lastParkourTime = 0,
		airborne = false,
		fallVelocity = 0,
		speed = 0,
	},
	trainingData = nil,
	currentVersionIds = {
		tagger = nil,
		runner = nil,
	},
	selectedVersionIndexes = {
		tagger = 1,
		runner = 1,
	},
	lastAutoSaveTime = 0,
	predictionLeadTime = 0.38,
	lastPredictionError = nil,
	routes = {},
	routeCooldowns = {},
	recordingRoute = false,
	playerRouteRecording = false,
	guidedTraining = false,
	guidedDestination = nil,
	guidedDestinationIndex = 0,
	guidedDestinationStartTime = 0,
	guidedCompletions = 0,
	lastGuidedNoDestinationLogTime = 0,
	guidedRecentDestinations = {},
	guidedTransitionBusy = false,
	lastGuidedSampleTime = 0,
	lastPlayerRouteSampleTime = 0,
	lastPlayerRouteSamplePosition = nil,
	lastPlayerRouteActionName = "Move",
	playerRouteStartPosition = nil,
	playerRouteStartedMoving = false,
	activeRoute = nil,
	activeRoutePractice = false,
	activeRouteCursor = 1,
	activeRouteStartTime = 0,
	routeAttemptVaults = 0,
	routeAttemptSwings = 0,
	routeAttemptRolls = 0,
	routeActionAttemptCursor = 0,
	routeActionAttemptName = nil,
	lastRouteActionAttemptTime = 0,
	lastRouteRecoveryJumpTime = 0,
	routeVaultMissCursor = 0,
	routeVaultMisses = 0,
	routeVaultApproachSide = 1,
	lastRouteVaultMissTime = 0,
	routePreVaultJumpCursor = 0,
	lastRoutePreVaultJumpTime = 0,
	routeLastProgressTime = 0,
	routeBestDistance = math.huge,
	routeResetCount = 0,
	editorOpen = false,
	editorCompact = false,
	teachCoachEnabled = false,
	teachCoachStep = 1,
	editorSelectedRouteIndex = 1,
	editorSelectedPointIndex = 1,
	editorSelectedAction = "Move",
	editorTab = "Routes",
	editorDraggingPointIndex = nil,
	editorDragDepth = 0,
	editorDragOffset = Vector3.zero,
	successes = 0,
	attempts = 0,
	stuckSeconds = 0,
	graphStep = 4,
	nodeCap = 10000,
}

local heartbeatConnection: RBXScriptConnection?
local aiUpdateAccumulator = 0
local trainerUi: any = nil
local graphBuildBusy = false
local logLines: { string } = {}
local spawnRunnerBot: () -> ()
local routeEditor: any = nil
local COACH_ACTIONS = table.freeze({ "Jump", "Vault", "TimedHighVault", "SlideBoost", "Swing", "Roll", "RollBoost" })
local botRollPressTimes: { [Model]: number } = {}
local botRollFallVelocities: { [Model]: number } = {}
local botRollFloorMaterials: { [Model]: Enum.Material } = {}
local routeMarkerFolder: Folder? = nil
local pathDebugFolder: Folder? = nil
local graphDebugFolder: Folder? = nil
local guidedMarkerFolder: Folder? = nil
local swingBarParts: { BasePart } = {}
local localGeometryCache: { [string]: LocalGeometryCacheEntry } = {}
local trampolineBounceTimes: { [Instance]: number } = {}
local refreshRouteMarkers: () -> ()
local resetActiveRouteToStart: (string) -> ()
local rewardRouteVault: (BasePart, Vector3) -> ()
local pushLog: (string) -> ()
local isBarrierInstance: (Instance) -> boolean
local getBarrierPenalty: (Vector3) -> number
local getVaultTechForHeight: (number, number?) -> string?
local setEditorOpen: (boolean) -> ()
local teachTechHint: (string?) -> ()
local teachClimbableWall: () -> ()
local getFloorHit: (Vector3, number?, number?) -> RaycastResult?
local getFloorY: (Vector3) -> number
local getFloorHeightDelta: (Vector3, Vector3) -> number
local getClearDistance: (BasePart, Vector3) -> number
local findPath: (number, number) -> { number }

local function turnBotToward(rootPart: BasePart, desiredDirection: Vector3, previousDirection: Vector3, dt: number): Vector3
	local flatDesired = Vector3.new(desiredDirection.X, 0, desiredDirection.Z)
	if flatDesired.Magnitude < 0.05 then return previousDirection end

	local desired = flatDesired.Unit
	local current = if previousDirection.Magnitude > 0.05 then previousDirection.Unit else rootPart.CFrame.LookVector
	local flatCurrent = Vector3.new(current.X, 0, current.Z)
	current = if flatCurrent.Magnitude > 0.05 then flatCurrent.Unit else desired

	local blend = math.clamp(dt * 12, 0.18, 0.55)
	local blended = current:Lerp(desired, blend)
	local faceDirection = if blended.Magnitude > 0.05 then blended.Unit else desired
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + faceDirection)
	return faceDirection
end

local function getRoleConfig(roleName: string): { [string]: any }?
	local roleModule = ReplicatedStorage.Shared.Configs.Roles:FindFirstChild(roleName)
	if not roleModule or not roleModule:IsA("ModuleScript") then return nil end

	return require(roleModule)
end

local function isTaggerRole(roleName: string): boolean
	return roleName == "Tagger" or roleName == "Peasant"
end

local function isRunnerRole(roleName: string): boolean
	return roleName == "Runner" or roleName == "Crown"
end

local function getBotRole(bot: Model?): string
	if not bot then return "Runner" end

	local role = bot:GetAttribute("Role")
	return if typeof(role) == "string" then role else "Runner"
end

local botNtbVersions: { [Model]: number } = {}

local function hitBotNtb(bot: Model, rootPart: BasePart): boolean
	local currentDurability = bot:GetAttribute("NTBDurability")
	currentDurability = if typeof(currentDurability) == "number" then currentDurability else 0

	if currentDurability > 0 then
		bot:SetAttribute("NTBDurability", currentDurability - 1)
		PlaySound(if currentDurability - 1 == 0 then "NTBHitBreak" else "NTBHit", rootPart)
		return true
	end

	bot:SetAttribute("NTBDurability", 3)
	botNtbVersions[bot] = (botNtbVersions[bot] or 0) + 1
	local version = botNtbVersions[bot]
	task.delay(3, function()
		if bot.Parent and botNtbVersions[bot] == version then bot:SetAttribute("NTBDurability", 0) end
	end)
	return false
end

local function grantBotNtb(bot: Model)
	bot:SetAttribute("NTBDurability", 3)
	botNtbVersions[bot] = (botNtbVersions[bot] or 0) + 1
	local version = botNtbVersions[bot]
	task.delay(3, function()
		if bot.Parent and botNtbVersions[bot] == version then bot:SetAttribute("NTBDurability", 0) end
	end)
end

local function reconcileBotRoleSlots()
	local botRole = getBotRole(state.bot)
	local runnerRole = getBotRole(state.runnerBot)
	if state.bot and isRunnerRole(botRole) and state.runnerBot and isTaggerRole(runnerRole) then
		state.bot, state.runnerBot = state.runnerBot, state.bot
		state.humanoid, state.runnerHumanoid = state.runnerHumanoid, state.humanoid
		state.rootPart, state.runnerRootPart = state.runnerRootPart, state.rootPart
	elseif state.bot and isRunnerRole(botRole) and not state.runnerBot then
		state.runnerBot = state.bot
		state.runnerHumanoid = state.humanoid
		state.runnerRootPart = state.rootPart
		state.bot = nil
		state.humanoid = nil
		state.rootPart = nil
	elseif state.runnerBot and isTaggerRole(runnerRole) and not state.bot then
		state.bot = state.runnerBot
		state.humanoid = state.runnerHumanoid
		state.rootPart = state.runnerRootPart
		state.runnerBot = nil
		state.runnerHumanoid = nil
		state.runnerRootPart = nil
	end
end

local function refreshBotRoleVisuals()
	if state.bot then BotRuntime.applyRoleVisuals(state.bot, getBotRole(state.bot)) end
	if state.runnerBot then BotRuntime.applyRoleVisuals(state.runnerBot, getBotRole(state.runnerBot)) end
end

local function assignBotToRoleSlot(bot: Model, humanoid: Humanoid?, rootPart: BasePart?, roleName: string)
	BotRuntime.applyRoleVisuals(bot, roleName)
	humanoid = humanoid or bot:FindFirstChildOfClass("Humanoid")
	local foundRoot = rootPart or bot:FindFirstChild("HumanoidRootPart") or bot.PrimaryPart
	rootPart = if foundRoot and foundRoot:IsA("BasePart") then foundRoot else nil

	if isTaggerRole(roleName) then
		state.bot = bot
		state.humanoid = humanoid
		state.rootPart = rootPart
		if state.runnerBot == bot then
			state.runnerBot = nil
			state.runnerHumanoid = nil
			state.runnerRootPart = nil
		end
	elseif isRunnerRole(roleName) then
		state.runnerEnabled = true
		state.runnerBot = bot
		state.runnerHumanoid = humanoid
		state.runnerRootPart = rootPart
		if state.bot == bot then
			state.bot = nil
			state.humanoid = nil
			state.rootPart = nil
		end
	end

	reconcileBotRoleSlots()
	refreshBotRoleVisuals()
end

local function restartTaggerAfterTag()
	if not state.training then return end

	state.chaseStartTime = os.clock() + Config.TAG_RESTART_DELAY_SECONDS
	state.lastDistance = nil
	state.lastChaseProgressDistance = nil
	state.lastRewardTime = 0
	state.lastChaseProgressCheckTime = 0
	state.lastChaseReplanTime = 0
	state.lastPosition = if state.rootPart then state.rootPart.Position else nil
	state.reactionTargetPosition = nil
	state.reactionTargetVelocity = Vector3.zero
	state.lastReactionSampleTime = 0
	state.lastCutoffKey = nil
	state.graphMoveTarget = nil
	state.graphMoveTech = nil
	table.clear(state.path)
	state.pathCursor = 1
	state.lastPathTime = 0
	state.pathFailureUntil = 0
	state.pathRequestBusy = false
	state.pathRequestSerial += 1
end

local function invalidateTaggerPathRequest()
	state.pathRequestBusy = false
	state.pathRequestSerial += 1
end

local function invalidateRunnerPathRequest()
	state.runnerPathRequestBusy = false
	state.runnerPathRequestSerial += 1
end

local function getLocalBotTaggedEvent(): BindableEvent
	local existing = ReplicatedStorage:FindFirstChild("LocalBotTagged")
	if existing and existing:IsA("BindableEvent") then return existing end

	local event = Instance.new("BindableEvent")
	event.Name = "LocalBotTagged"
	event.Parent = ReplicatedStorage
	return event
end
local dragSelectedRoutePointToMouse: () -> ()
local tryBotJump: (BasePart, Humanoid, number, Vector3?, string?, boolean?) -> boolean

local function getIgnoreList(): { Instance }
	local ignore = {}

	local character = localPlayer.Character
	if character then table.insert(ignore, character) end

	if state.bot then table.insert(ignore, state.bot) end
	if state.runnerBot then table.insert(ignore, state.runnerBot) end
	if routeMarkerFolder then table.insert(ignore, routeMarkerFolder) end
	if pathDebugFolder then table.insert(ignore, pathDebugFolder) end
	if graphDebugFolder then table.insert(ignore, graphDebugFolder) end
	if guidedMarkerFolder then table.insert(ignore, guidedMarkerFolder) end

	return ignore
end

local function rememberPlayerAction(actionName: string)
	state.actionInfo.lastParkourName = actionName
	state.actionInfo.lastParkourTime = os.clock()
end

local function recordPlayerRouteSample(rootPart: BasePart, actionName: string, force: boolean?)
	if not state.playerRouteRecording or not routeEditor then return end

	local now = os.clock()
	local previousPosition = state.lastPlayerRouteSamplePosition
	local moved = if previousPosition then (rootPart.Position - previousPosition).Magnitude else math.huge
	local startPosition = state.playerRouteStartPosition or rootPart.Position
	local movedFromStart = (rootPart.Position - startPosition).Magnitude
	local isMoveAction = actionName == "Move"
	local isStartOrEnd = actionName == "Start" or actionName == "End"
	if isMoveAction then
		if state.actionInfo.airborne then return end
		if not state.playerRouteStartedMoving then
			if movedFromStart < 5.5 then return end
			state.playerRouteStartedMoving = true
		end
	elseif not isStartOrEnd then
		state.playerRouteStartedMoving = true
	end

	local actionChanged = actionName ~= state.lastPlayerRouteActionName
	if not force and moved < 8 and not actionChanged and now - state.lastPlayerRouteSampleTime < 0.65 then return end

	routeEditor.addRoutePointAt(rootPart.Position, actionName, nil, nil)
	state.lastPlayerRouteSampleTime = now
	state.lastPlayerRouteSamplePosition = rootPart.Position
	state.lastPlayerRouteActionName = actionName
end

local function bindPlayerActionTracking()
	getLocalBotTaggedEvent().Event:Connect(function(bot: Instance, newRoleName: any)
		if not bot:IsA("Model") or typeof(newRoleName) ~= "string" then return end
		if bot ~= state.bot and bot ~= state.runnerBot then return end

		local rootPart = bot:FindFirstChild("HumanoidRootPart") or bot.PrimaryPart
		local humanoid = bot:FindFirstChildOfClass("Humanoid")
		assignBotToRoleSlot(bot, humanoid, if rootPart and rootPart:IsA("BasePart") then rootPart else nil, newRoleName)
		if rootPart and rootPart:IsA("BasePart") then PlaySound("TagHit", rootPart) end
		pushLog(`Bot tagged by player. New role: {newRoleName}.`)
	end)

	UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if state.editorOpen and inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			local mouse = localPlayer:GetMouse()
			local target = mouse.Target
			local pointIndex = target and target:GetAttribute("BotRoutePointIndex")
			if typeof(pointIndex) == "number" then
				local route = state.routes[state.editorSelectedRouteIndex] or state.routes[#state.routes]
				local point = route and route.points[pointIndex]
				local camera = workspace.CurrentCamera
				if point and camera then
					local mouseLocation = UserInputService:GetMouseLocation()
					local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
					local depth = (point.position - ray.Origin):Dot(ray.Direction)

					state.editorSelectedPointIndex = pointIndex
					state.editorDraggingPointIndex = pointIndex
					state.editorDragDepth = math.max(4, depth)
					state.editorDragOffset = point.position - (ray.Origin + ray.Direction * state.editorDragDepth)
					refreshRouteMarkers()
				end
				return
			end
		end
		if gameProcessed then return end

		if inputObject.KeyCode == Enum.KeyCode.F6 then
			state.editorCompact = not state.editorCompact
			if trainerUi then trainerUi:refreshControlButtons() end
			return
		elseif inputObject.KeyCode == Enum.KeyCode.F7 then
			setEditorOpen(not state.editorOpen)
			return
		elseif inputObject.KeyCode == Enum.KeyCode.F8 then
			state.editorTab = if state.editorTab == "Memory" then "Routes" else "Memory"
			if trainerUi then trainerUi:refreshControlButtons() end
			return
		end

			if state.editorCompact and state.teachCoachEnabled then
				if inputObject.KeyCode == Enum.KeyCode.RightBracket or inputObject.KeyCode == Enum.KeyCode.E then
					state.teachCoachStep = math.clamp(state.teachCoachStep + 1, 1, 6)
					if trainerUi then trainerUi:refreshControlButtons() end
					return
				elseif inputObject.KeyCode == Enum.KeyCode.LeftBracket or inputObject.KeyCode == Enum.KeyCode.Q then
					state.teachCoachStep = math.clamp(state.teachCoachStep - 1, 1, 6)
					if trainerUi then trainerUi:refreshControlButtons() end
					return
				elseif inputObject.KeyCode == Enum.KeyCode.T then
					teachTechHint(state.editorSelectedAction)
					return
				elseif inputObject.KeyCode == Enum.KeyCode.B then
					teachClimbableWall()
					if trainerUi then trainerUi:refreshControlButtons() end
					return
				elseif inputObject.KeyCode == Enum.KeyCode.N then
				if routeEditor then routeEditor.addRoutePointFromView(state.editorSelectedAction) end
				return
			elseif inputObject.KeyCode == Enum.KeyCode.R then
				if routeEditor then
					if state.recordingRoute then
						routeEditor.stopRouteRecording()
						pushLog("Coach: stopped route recording.")
					else
						routeEditor.beginPlayerRouteRecording()
						pushLog("Coach: recording your movement.")
					end
				end
				if trainerUi then trainerUi:refreshControlButtons() end
				return
			elseif inputObject.KeyCode == Enum.KeyCode.C then
				local currentIndex = table.find(COACH_ACTIONS, state.editorSelectedAction) or 0
				state.editorSelectedAction = COACH_ACTIONS[(currentIndex % #COACH_ACTIONS) + 1]
				if routeEditor then routeEditor.setSelectedRoutePointAction(state.editorSelectedAction) end
				if trainerUi then trainerUi:refreshControlButtons() end
				pushLog(`Coach action: {state.editorSelectedAction}.`)
				return
			end
		end

		local key = if inputObject.KeyCode ~= Enum.KeyCode.Unknown then inputObject.KeyCode.Name else inputObject.UserInputType.Name
		state.actionInfo.lastInputName = key
		state.actionInfo.lastInputTime = os.clock()
	end)

	UserInputService.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			state.editorDraggingPointIndex = nil
			state.editorDragDepth = 0
			state.editorDragOffset = Vector3.zero
		end
	end)

	UserInputService.InputChanged:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseMovement then dragSelectedRoutePointToMouse() end
	end)

	local function trackCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

			local function watchAttribute(attributeName: string, actionName: string)
				character:GetAttributeChangedSignal(attributeName):Connect(function()
					if character:GetAttribute(attributeName) then
						rememberPlayerAction(actionName)
						recordPlayerRouteSample(rootPart, actionName, true)
					end
				end)
			end

			character:GetAttributeChangedSignal("Sliding"):Connect(function()
				if character:GetAttribute("Sliding") then
					rememberPlayerAction("Slide")
					recordPlayerRouteSample(rootPart, "Slide", true)
				else
					rememberPlayerAction("SlideCancel")
					recordPlayerRouteSample(rootPart, "SlideCancel", true)
				end
			end)
			watchAttribute("Rolling", "Roll")
			watchAttribute("Vaulting", "Vault")
			watchAttribute("Swinging", "Swing")

			UserInputService.JumpRequest:Connect(function()
				if not character.Parent then return end
				local recentSlideCancel = state.actionInfo.lastParkourName == "SlideCancel" and os.clock() - state.actionInfo.lastParkourTime <= 0.35
				if humanoid.FloorMaterial == Enum.Material.Air and not recentSlideCancel then return end

				rememberPlayerAction("Jump")
				recordPlayerRouteSample(rootPart, "Jump", true)
			end)

		humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(function()
			state.actionInfo.airborne = humanoid.FloorMaterial == Enum.Material.Air
		end)

		RunService.Heartbeat:Connect(function()
			if not character.Parent then return end

			local velocity = rootPart.AssemblyLinearVelocity
			state.actionInfo.airborne = humanoid.FloorMaterial == Enum.Material.Air
			state.actionInfo.fallVelocity = math.min(0, velocity.Y)
			state.actionInfo.speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			if state.playerRouteRecording and humanoid.FloorMaterial ~= Enum.Material.Air and state.actionInfo.speed > 2.5 then
				recordPlayerRouteSample(rootPart, "Move", false)
			end
		end)
	end

	localPlayer.CharacterAdded:Connect(trackCharacter)
	if localPlayer.Character then trackCharacter(localPlayer.Character) end
end

pushLog = function(message: string)
	table.insert(logLines, 1, `{os.date("%H:%M:%S")}  {message}`)
	while #logLines > 9 do
		table.remove(logLines)
	end

	if trainerUi then trainerUi:setLog(table.concat(logLines, "\n")) end
end

local function getSelectedEnabled(): boolean
	return if state.selectedAI == "Tagger" then state.taggerEnabled else state.runnerEnabled
end

local function setSelectedEnabled(enabled: boolean)
	if state.selectedAI == "Tagger" then
		state.taggerEnabled = enabled
	else
		state.runnerEnabled = enabled
		if enabled and not state.runnerBot then spawnRunnerBot() end
	end
end

local function getSelectedSpeedMultiplier(): number
	return if state.selectedAI == "Tagger" then state.taggerSpeedMultiplier else state.runnerSpeedMultiplier
end

local function setSelectedSpeedMultiplier(speedMultiplier: number)
	if state.selectedAI == "Tagger" then
		state.taggerSpeedMultiplier = speedMultiplier
	else
		state.runnerSpeedMultiplier = speedMultiplier
	end
end

local function getSelectedRoleName(): SaveRoleName
	return if state.selectedAI == "Tagger" then "tagger" else "runner"
end

local persistence: any = nil

local function refreshControlButtons()
	if trainerUi then trainerUi:refreshControlButtons() end
end

local function getBotsFolder(): Folder
	local botsFolder = workspace:FindFirstChild("Bots")
	if botsFolder and botsFolder:IsA("Folder") then return botsFolder end

	local newFolder = Instance.new("Folder")
	newFolder.Name = "Bots"
	newFolder.Parent = workspace
	return newFolder
end

local function getRouteMarkerFolder(): Folder
	if routeMarkerFolder and routeMarkerFolder.Parent then return routeMarkerFolder end

	local existingFolder = workspace:FindFirstChild("BotRouteMarkers")
	if existingFolder and existingFolder:IsA("Folder") then
		routeMarkerFolder = existingFolder
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = "BotRouteMarkers"
	folder.Parent = workspace
	routeMarkerFolder = folder
	return folder
end

local function getPathDebugFolder(): Folder
	if pathDebugFolder and pathDebugFolder.Parent then return pathDebugFolder end

	local existingFolder = workspace:FindFirstChild("BotPathDebug")
	if existingFolder and existingFolder:IsA("Folder") then
		pathDebugFolder = existingFolder
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = "BotPathDebug"
	folder.Parent = workspace
	pathDebugFolder = folder
	return folder
end

local function getGraphDebugFolder(): Folder
	if graphDebugFolder and graphDebugFolder.Parent then return graphDebugFolder end

	local existingFolder = workspace:FindFirstChild("BotGraphDebug")
	if existingFolder and existingFolder:IsA("Folder") then
		graphDebugFolder = existingFolder
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = "BotGraphDebug"
	folder.Parent = workspace
	graphDebugFolder = folder
	return folder
end

local function getGuidedMarkerFolder(): Folder
	if guidedMarkerFolder and guidedMarkerFolder.Parent then return guidedMarkerFolder end

	local existingFolder = workspace:FindFirstChild("BotGuidedTraining")
	if existingFolder and existingFolder:IsA("Folder") then
		guidedMarkerFolder = existingFolder
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = "BotGuidedTraining"
	folder.Parent = workspace
	guidedMarkerFolder = folder
	return folder
end

local function refreshGuidedMarker()
	local folder = getGuidedMarkerFolder()
	folder:ClearAllChildren()
	if not state.guidedTraining or not state.guidedDestination then return end

	local marker = Instance.new("Part")
	marker.Name = "GuidedDestination"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(1.2, 140, 1.2)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 220, 85)
	marker.Transparency = 0.15
	marker.Position = state.guidedDestination + Vector3.yAxis * 68
	marker.Parent = folder

	local base = Instance.new("Part")
	base.Name = "GuidedDestinationBase"
	base.Shape = Enum.PartType.Ball
	base.Size = Vector3.new(3.25, 3.25, 3.25)
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.CanQuery = false
	base.Material = Enum.Material.Neon
	base.Color = Color3.fromRGB(255, 220, 85)
	base.Transparency = 0.08
	base.Position = state.guidedDestination
	base.Parent = folder

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(190, 54)
	label.StudsOffset = Vector3.new(0, 2.8, 0)
	label.AlwaysOnTop = true
	label.Parent = base

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.Text = `Guided #{state.guidedDestinationIndex}\nRun here`
	text.TextColor3 = Color3.fromRGB(255, 250, 220)
	text.TextStrokeTransparency = 0.25
	text.TextSize = 14
	text.Parent = label
end

local function getActionColor(actionName: string): Color3
	if actionName == "Start" then return Color3.fromRGB(94, 210, 255) end
	if actionName == "End" then return Color3.fromRGB(255, 222, 92) end
	if actionName == "Vault" then return Color3.fromRGB(124, 255, 155) end
	if actionName == "Swing" then return Color3.fromRGB(255, 125, 217) end
	if actionName == "Roll" then return Color3.fromRGB(255, 152, 92) end

	return Color3.fromRGB(210, 220, 235)
end

local function getTechColor(actionName: string): Color3
	if string.find(actionName, "Vault") then return Color3.fromRGB(110, 255, 150) end
	if string.find(actionName, "Swing") then return Color3.fromRGB(255, 110, 220) end
	if string.find(actionName, "Roll") then return Color3.fromRGB(255, 155, 80) end
	if string.find(actionName, "Slide") then return Color3.fromRGB(100, 185, 255) end
	if string.find(actionName, "Jump") then return Color3.fromRGB(255, 235, 100) end
	return Color3.fromRGB(200, 215, 235)
end

local function addDebugNode(parent: Instance, position: Vector3, labelText: string, color: Color3)
	local marker = Instance.new("Part")
	marker.Name = `Node_{labelText:gsub("%W+", "")}`
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(1.1, 1.1, 1.1)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Material = Enum.Material.Neon
	marker.Color = color
	marker.Position = position
	marker.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(130, 34)
	billboard.StudsOffset = Vector3.new(0, 1.65, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = marker

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.Text = labelText
	text.TextColor3 = Color3.fromRGB(250, 252, 255)
	text.TextSize = 12
	text.TextStrokeTransparency = 0.3
	text.Parent = billboard
end

local function addDebugLine(parent: Instance, fromPosition: Vector3, toPosition: Vector3, color: Color3)
	local delta = toPosition - fromPosition
	if delta.Magnitude < 0.1 then return end

	local line = Instance.new("Part")
	line.Name = "PathLine"
	line.Anchored = true
	line.CanCollide = false
	line.CanTouch = false
	line.CanQuery = false
	line.Material = Enum.Material.Neon
	line.Color = color
	line.Transparency = 0.2
	line.Size = Vector3.new(0.18, 0.18, delta.Magnitude)
	line.CFrame = CFrame.lookAt(fromPosition:Lerp(toPosition, 0.5), toPosition)
	line.Parent = parent
end

refreshRouteMarkers = function()
	local folder = getRouteMarkerFolder()
	folder:ClearAllChildren()
	if not state.editorOpen then return end

	local route = state.routes[state.editorSelectedRouteIndex] or state.routes[#state.routes]
	if not route then return end

	for index, point in route.points do
		local marker = Instance.new("Part")
		marker.Name = `RoutePoint_{index}_{point.action}`
		marker.Shape = Enum.PartType.Ball
		marker.Size = if index == state.editorSelectedPointIndex then Vector3.new(1.35, 1.35, 1.35) else Vector3.new(0.9, 0.9, 0.9)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = true
		marker.Material = Enum.Material.Neon
		marker.Color = getActionColor(point.action)
		marker.Position = point.position
		marker:SetAttribute("BotRoutePointIndex", index)
		marker.Parent = folder

		local label = Instance.new("BillboardGui")
		label.Name = "Label"
		label.Size = UDim2.fromOffset(150, 44)
		label.StudsOffset = Vector3.new(0, 1.6, 0)
		label.AlwaysOnTop = true
		label.Parent = marker

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.fromRGB(245, 248, 255)
		text.TextStrokeTransparency = 0.35
		text.TextSize = 13
		text.Text = `{index}. {point.action}`
		text.Parent = label
	end
end

local function removeScripts(instance: Instance)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		elseif descendant:IsA("Shirt") or descendant:IsA("Pants") or descendant:IsA("ShirtGraphic") then
			descendant:Destroy()
		end
	end
end

local function setCharacterCollision(model: Model, canCollide: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = canCollide and descendant.Name ~= "HumanoidRootPart"
			descendant.Massless = descendant.Name ~= "HumanoidRootPart"
		end
	end
end

local function makeFallbackBot(spawnCFrame: CFrame, botName: string, bodyColor: Color3): Model
	local bot = Instance.new("Model")
	bot.Name = botName

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Transparency = 1
	rootPart.CFrame = spawnCFrame
	rootPart.Parent = bot

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = bodyColor
	torso.CFrame = spawnCFrame
	torso.Parent = bot

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.25, 1.25, 1.25)
	head.Color = Color3.fromRGB(255, 220, 180)
	head.CFrame = spawnCFrame * CFrame.new(0, 1.65, 0)
	head.Parent = bot

	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "RootJoint"
	rootJoint.Part0 = rootPart
	rootJoint.Part1 = torso
	rootJoint.Parent = rootPart

	local neck = Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = torso
	neck.Part1 = head
	neck.C0 = CFrame.new(0, 1.25, 0)
	neck.Parent = torso

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.WalkSpeed = 32
	humanoid.JumpPower = 28
	humanoid.Parent = bot

	bot.PrimaryPart = rootPart
	return bot
end

local function getSpawnCFrame(offset: Vector3): CFrame
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then return rootPart.CFrame * CFrame.new(offset) end

	return CFrame.new(0, 12, 0)
end

local function createBot(botName: string, roleName: string, spawnOffset: Vector3): (Model, Humanoid, BasePart)
	local botsFolder = getBotsFolder()
	local previousBot = botsFolder:FindFirstChild(botName)
	if not previousBot then
		for _, child in botsFolder:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("TrainingBotSpawnName") == botName then
				previousBot = child
				break
			end
		end
	end
	if previousBot and previousBot:IsA("Model") then botNtbVersions[previousBot] = nil end
	if previousBot then previousBot:Destroy() end

	local roleConfig = getRoleConfig(roleName)
	local bodyColor = if roleConfig and typeof(roleConfig.Color) == "Color3" then roleConfig.Color else Color3.fromRGB(220, 220, 220)
	local sourceCharacter = localPlayer.Character
	local bot: Model
	if sourceCharacter then
		local originalArchivable = sourceCharacter.Archivable
		sourceCharacter.Archivable = true
		local clone = sourceCharacter:Clone()
		sourceCharacter.Archivable = originalArchivable

		if clone then
			bot = clone
			bot.Name = botName
			removeScripts(bot)
			bot:PivotTo(getSpawnCFrame(spawnOffset))
		else
			bot = makeFallbackBot(getSpawnCFrame(spawnOffset), botName, bodyColor)
		end
	else
		bot = makeFallbackBot(getSpawnCFrame(spawnOffset), botName, bodyColor)
	end

	bot:SetAttribute("Momentum", 0)
	bot:SetAttribute("Friction", 0)
	bot:SetAttribute("TrainingBotSpawnName", botName)
	bot:SetAttribute("MinRunSpeed", 16)
	bot:SetAttribute("MaxRunSpeed", 32)
	bot:SetAttribute("NTBDurability", 0)
	bot.Parent = botsFolder

	setCharacterCollision(bot, true)
	BotRuntime.applyRoleVisuals(bot, roleName)
	BotRuntime.updateNtbVisuals(bot)
	bot:GetAttributeChangedSignal("NTBDurability"):Connect(function()
		BotRuntime.updateNtbVisuals(bot)
	end)

	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	local rootPart = bot:FindFirstChild("HumanoidRootPart")
	assert(humanoid, "[BotTrainer] Spawned bot has no Humanoid")
	assert(rootPart and rootPart:IsA("BasePart"), "[BotTrainer] Spawned bot has no HumanoidRootPart")

	humanoid.WalkSpeed = 32
	humanoid.JumpPower = 28
	BotRuntime.initAnimations(bot, humanoid)
	BotRuntime.initMovementState(bot, humanoid)
	botRollFloorMaterials[bot] = humanoid.FloorMaterial
	botRollFallVelocities[bot] = 0
	botRollPressTimes[bot] = nil

	return bot, humanoid, rootPart
end

local function spawnBot()
	local bot, humanoid, rootPart = createBot(Config.BOT_NAME, state.taggerBotRoleName, Vector3.new(0, 0, -18))

	state.bot = bot
	state.humanoid = humanoid
	state.rootPart = rootPart
	state.path = {}
	state.pathCursor = 1
	state.lastPathTime = 0
	state.pathFailureUntil = 0
	state.pathRequestBusy = false
	state.pathRequestSerial += 1
	state.lastGraphDecisionTime = 0
	state.graphMoveTarget = nil
	state.graphMoveTech = nil
	state.graphMoveTargetSetTime = 0
	state.lastPosition = rootPart.Position
	state.lastDistance = nil
	state.lastChaseProgressDistance = nil
	state.lastChaseProgressCheckTime = 0
	state.lastChaseReplanTime = 0
	state.reactionTargetPosition = nil
	state.reactionTargetVelocity = Vector3.zero
	state.lastReactionSampleTime = 0
	state.lastCutoffKey = nil
	state.stuckSeconds = 0
	state.lastSteeringCheckTime = 0
	state.steeredMoveDirection = Vector3.zero
	state.lastParkourActionTime = 0
	state.lastRollPressTime = nil
	state.lastFloorMaterial = humanoid.FloorMaterial
	if state.training then state.chaseStartTime = os.clock() + Config.CHASE_START_DELAY_SECONDS end

	pushLog(`Spawned local training bot as {getBotRole(bot)}.`)
end

function spawnRunnerBot()
	local bot, humanoid, rootPart = createBot(Config.RUNNER_BOT_NAME, state.runnerBotRoleName, Vector3.new(12, 0, -18))

	state.runnerBot = bot
	state.runnerHumanoid = humanoid
	state.runnerRootPart = rootPart
	state.runnerLastSteeringCheckTime = 0
	state.runnerSteeredMoveDirection = Vector3.zero
	state.runnerLastGraphDecisionTime = 0
	state.runnerGraphMoveTarget = nil
	state.runnerGraphMoveTech = nil
	state.runnerLastPosition = rootPart.Position
	state.runnerStuckSeconds = 0
	state.runnerLastEscapeGoalId = nil
	state.runnerEscapeGoalRepeat = 0
	state.runnerLapSign = if math.random() < 0.5 then -1 else 1
	state.runnerLastLapSwitchTime = 0
	state.runnerRoute = nil
	state.runnerRouteCursor = 1
	state.runnerRouteLastProgressTime = 0
	state.runnerRouteBestDistance = math.huge
	state.runnerLastDistance = nil
	state.runnerLastRewardTime = 0
	table.clear(state.runnerPath)
	state.runnerPathCursor = 1
	state.runnerLastPathTime = 0
	state.runnerPathFailureUntil = 0
	state.runnerPathRequestBusy = false
	state.runnerPathRequestSerial += 1

	pushLog(`Spawned local training bot as {getBotRole(bot)}.`)
end

local function getTargetRoot(): BasePart?
	local character = localPlayer.Character
	if not character then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then return rootPart end

	return nil
end

local function getTaggerTargetRoot(): BasePart?
	if state.targetMode == "AI" then return state.runnerRootPart end

	return getTargetRoot()
end

local function getRunnerThreatRoot(): BasePart?
	if state.targetMode == "AI" then return state.rootPart end

	return getTargetRoot()
end

local isSwingBarNear: (Vector3, Vector3) -> boolean

local function graphBucketKey(position: Vector3, spacing: number, offsetX: number, offsetY: number, offsetZ: number): string
	return `{math.floor(position.X / spacing) + offsetX}:{math.floor(position.Y / spacing) + offsetY}:{math.floor(position.Z / spacing) + offsetZ}`
end

local function getGraphSpacing(): number
	return math.max(2.5, state.graphStep * Config.GRAPH_NODE_MIN_SPACING_RATIO)
end

local function collectGraphNodeIdsNear(position: Vector3, radius: number): { number }
	local spacing = getGraphSpacing()
	local bucketRadius = math.max(1, math.ceil(radius / spacing))
	local verticalBucketRadius = math.min(bucketRadius, 6)
	local nodeIds = {}
	local seen: { [number]: boolean } = {}

	for x = -bucketRadius, bucketRadius do
		for y = -verticalBucketRadius, verticalBucketRadius do
			for z = -bucketRadius, bucketRadius do
				local nearbyIds = state.nodeByKey[graphBucketKey(position, spacing, x, y, z)]
				if not nearbyIds then continue end

				for _, nodeId in nearbyIds do
					if seen[nodeId] then continue end

					local node = state.graph[nodeId]
					if not node then continue end
					if (node.position - position).Magnitude > radius then continue end

					seen[nodeId] = true
					table.insert(nodeIds, nodeId)
				end
			end
		end
	end

	return nodeIds
end

local function canStandAt(position: Vector3, ignore: { Instance }): (boolean, Vector3?, string?)
	raycastParams.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -8, 0), raycastParams)
	if not result or result.Normal.Y < 0.68 then
		result = workspace:Raycast(position + Vector3.new(0, 32, 0), Vector3.new(0, -80, 0), raycastParams)
	end
	if not result then return false, nil, nil end
	if result.Normal.Y < 0.68 then return false, nil, nil end

	local standPosition = result.Position + Vector3.new(0, 3, 0)
	local headResult = workspace:Raycast(standPosition, Vector3.new(0, 2.6, 0), raycastParams)
	if headResult then return false, nil, nil end

	return true, standPosition, result.Instance:GetFullName()
end

local function getMapBounds(): (Vector3?, Vector3?)
	local map = workspace:FindFirstChild("Map")
	if not map then return nil, nil end

	local minPosition = Vector3.new(math.huge, math.huge, math.huge)
	local maxPosition = Vector3.new(-math.huge, -math.huge, -math.huge)
	local foundPart = false

	for _, descendant in map:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		if isBarrierInstance(descendant) then continue end
		if not descendant.CanCollide then continue end
		if descendant.Transparency >= 1 then continue end

		foundPart = true
		local halfSize = descendant.Size * 0.5
		local position = descendant.Position
		minPosition = Vector3.new(
			math.min(minPosition.X, position.X - halfSize.X),
			math.min(minPosition.Y, position.Y - halfSize.Y),
			math.min(minPosition.Z, position.Z - halfSize.Z)
		)
		maxPosition = Vector3.new(
			math.max(maxPosition.X, position.X + halfSize.X),
			math.max(maxPosition.Y, position.Y + halfSize.Y),
			math.max(maxPosition.Z, position.Z + halfSize.Z)
		)
	end

	if not foundPart then return nil, nil end
	return minPosition, maxPosition
end

local function raycastGuidedMapFloor(probePosition: Vector3, minPosition: Vector3, maxPosition: Vector3): RaycastResult?
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	params.IgnoreWater = true

	local origin = Vector3.new(probePosition.X, maxPosition.Y + 80, probePosition.Z)
	local result = workspace:Raycast(origin, Vector3.yAxis * -(maxPosition.Y - minPosition.Y + 180), params)
	if not result then return nil end
	if result.Normal.Y < 0.64 then return nil end
	if isBarrierInstance(result.Instance) then return nil end

	return result
end

local function getGraphTraversalTech(fromPosition: Vector3, toPosition: Vector3): string
	local delta = toPosition - fromPosition
	local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local verticalDelta = delta.Y

	if isSwingBarNear(fromPosition, toPosition) and verticalDelta <= 3 and flatDistance >= state.graphStep * 0.8 then return "Swing" end
	if verticalDelta > 2 and verticalDelta <= Config.GROUND_VAULT_REACH_STUDS + 1 then return "Vault" end
	if verticalDelta > Config.GROUND_VAULT_REACH_STUDS + 1 and verticalDelta <= Config.HIGH_VAULT_MAX_STUDS + 0.75 then return "HighVault" end
	if verticalDelta < -7 then return "Drop" end
	return "Move"
end

local function hasTraversalLine(fromPosition: Vector3, toPosition: Vector3, ignore: { Instance }): boolean
	losParams.FilterDescendantsInstances = ignore

	local delta = toPosition - fromPosition
	local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if flatDistance > state.graphStep * 2.2 then return false end
	if math.abs(delta.Y) > 10 then return false end

	local origin = fromPosition + Vector3.new(0, 1.5, 0)
	local result = workspace:Raycast(origin, delta, losParams)
	if not result then return true end

	local hitDistance = (result.Position - origin).Magnitude
	if hitDistance > delta.Magnitude - 2 then return true end
	if delta.Y < -5 then return true end
	if isSwingBarNear(fromPosition, toPosition) then return true end
	if delta.Y > 2 and delta.Y <= 10 and result.Instance:GetAttribute("NoClimb") ~= true then return true end

	return false
end

local function getWallInfo(position: Vector3, ignore: { Instance }): (number, number)
	losParams.FilterDescendantsInstances = ignore

	local origin = position + Vector3.yAxis * 1.6
	local directions = {
		Vector3.xAxis,
		-Vector3.xAxis,
		Vector3.zAxis,
		-Vector3.zAxis,
		Vector3.new(1, 0, 1).Unit,
		Vector3.new(-1, 0, 1).Unit,
		Vector3.new(1, 0, -1).Unit,
		Vector3.new(-1, 0, -1).Unit,
	}
	local openDirections = 0
	local wallPenalty = 0

	for _, direction in directions do
		local result = workspace:Raycast(origin, direction * 11, losParams)
		if not result or not result.Instance.CanCollide or isBarrierInstance(result.Instance) then
			openDirections += 1
			continue
		end

		local distance = (result.Position - origin).Magnitude
		if distance >= 7 then
			openDirections += 1
		else
			wallPenalty += (7 - distance) / 7
		end
	end

	if openDirections <= 1 then
		wallPenalty += 2
	end
	if openDirections == 2 then
		wallPenalty += 0.75
	end

	return math.clamp(wallPenalty / #directions, 0, 1), openDirections
end

local function addGraphNode(position: Vector3, partName: string)
	if #state.graph >= state.nodeCap then return end

	local spacing = getGraphSpacing()
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				local nearbyIds = state.nodeByKey[graphBucketKey(position, spacing, x, y, z)]
				if not nearbyIds then continue end

				for _, nodeId in nearbyIds do
					local existingNode = state.graph[nodeId]
					if not existingNode then continue end

					local delta = existingNode.position - position
					local flatDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
					if flatDistance < spacing and math.abs(delta.Y) < 4 then return end
				end
			end
		end
	end

	local wallPenalty, openDirections = getWallInfo(position, getIgnoreList())
	local node: GraphNode = {
		id = #state.graph + 1,
		position = position,
		partName = partName,
		links = {},
		linkTechs = {},
		score = 0,
		visits = 0,
		barrierPenalty = getBarrierPenalty(position),
		deadEndPenalty = 0,
		wallPenalty = wallPenalty,
		openDirections = openDirections,
	}

	state.graph[node.id] = node
	local key = graphBucketKey(position, spacing, 0, 0, 0)
	local bucket = state.nodeByKey[key]
	if not bucket then
		bucket = {}
		state.nodeByKey[key] = bucket
	end
	table.insert(bucket, node.id)
end

local function buildGraph()
	if graphBuildBusy then return end
	graphBuildBusy = true

	table.clear(state.graph)
	table.clear(state.nodeByKey)
	table.clear(state.path)
	table.clear(swingBarParts)
	table.clear(localGeometryCache)
	state.pathCursor = 1
	state.lastPathTime = 0
	state.pathFailureUntil = 0
	invalidateTaggerPathRequest()
	invalidateRunnerPathRequest()

	local map = workspace:FindFirstChild("Map")
	if not map then
		pushLog("No workspace.Map found. Load a map before building.")
		graphBuildBusy = false
		return
	end

	local ignore = getIgnoreList()
	local scannedParts = 0
	local graphParts = {}

	for _, descendant in map:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		if isBarrierInstance(descendant) then continue end
		if descendant:GetAttribute("SwingBar") == true or CollectionService:HasTag(descendant, "SwingBar") then
			table.insert(swingBarParts, descendant)
		end
		if not descendant.CanCollide then continue end
		if descendant.Transparency >= 1 then continue end

		table.insert(graphParts, descendant)
	end

	table.sort(graphParts, function(a: BasePart, b: BasePart): boolean
		return a.Size.X * a.Size.Z > b.Size.X * b.Size.Z
	end)

	for _, part in graphParts do
		if #state.graph >= state.nodeCap then break end

		local sample = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2 + 1, 0))
		local canStand, standPosition, partName = canStandAt(sample, ignore)
		if canStand and standPosition and partName then addGraphNode(standPosition, partName) end
	end

	for _, descendant in graphParts do
		if #state.graph >= state.nodeCap then break end

		scannedParts += 1

		local size = descendant.Size
		local usableX = math.max(0, size.X - 4)
		local usableZ = math.max(0, size.Z - 4)
		local countX = math.max(1, math.floor(usableX / state.graphStep + 0.5) + 1)
		local countZ = math.max(1, math.floor(usableZ / state.graphStep + 0.5) + 1)

		for x = 1, countX do
			if #state.graph >= state.nodeCap then break end

			for z = 1, countZ do
				if #state.graph >= state.nodeCap then break end

				local localX = if countX == 1 then 0 else -usableX / 2 + (x - 1) * (usableX / (countX - 1))
				local localZ = if countZ == 1 then 0 else -usableZ / 2 + (z - 1) * (usableZ / (countZ - 1))
				local sample = descendant.CFrame:PointToWorldSpace(Vector3.new(localX, size.Y / 2 + 1, localZ))
				local canStand, standPosition, partName = canStandAt(sample, ignore)
				if canStand and standPosition and partName then addGraphNode(standPosition, partName) end
			end
		end

		if scannedParts % 20 == 0 then task.wait() end
	end

	local spacing = getGraphSpacing()
	local linkRange = math.ceil((state.graphStep * 1.65) / spacing) + 1
	for i, node in state.graph do
		for x = -linkRange, linkRange do
			for y = -linkRange, linkRange do
				for z = -linkRange, linkRange do
					local nearbyIds = state.nodeByKey[graphBucketKey(node.position, spacing, x, y, z)]
					if not nearbyIds then continue end

					for _, otherId in nearbyIds do
						if otherId <= i then continue end

						local otherNode = state.graph[otherId]
						local verticalDelta = math.abs(otherNode.position.Y - node.position.Y)
						if (node.wallPenalty > 0.72 or otherNode.wallPenalty > 0.72) and verticalDelta < 3 then continue end
						if hasTraversalLine(node.position, otherNode.position, ignore) then
							table.insert(node.links, otherNode.id)
							table.insert(otherNode.links, node.id)
							node.linkTechs[otherNode.id] = getGraphTraversalTech(node.position, otherNode.position)
							otherNode.linkTechs[node.id] = getGraphTraversalTech(otherNode.position, node.position)
						end
					end
				end
			end
		end

		if i % 80 == 0 then task.wait() end
	end

	for _, node in state.graph do
		local linkPenalty = if #node.links <= 1 then 1 elseif #node.links == 2 then 0.35 else 0
		local opennessPenalty = if node.openDirections <= 1 then 0.85 elseif node.openDirections == 2 then 0.35 else 0
		node.deadEndPenalty = math.clamp(math.max(linkPenalty, opennessPenalty) + node.wallPenalty * 0.45, 0, 1)
	end

	state.graphRevision += 1
	pushLog(`Built graph: {#state.graph} nodes from {scannedParts} parts.`)
	graphBuildBusy = false
end

local function nearestNodeId(position: Vector3, searchRadius: number?): number?
	local nearestId: number? = nil
	local nearestDistance = math.huge
	local candidateIds = if searchRadius then collectGraphNodeIdsNear(position, searchRadius) else {}

	if searchRadius and #candidateIds > 0 then
		for _, nodeId in candidateIds do
			local node = state.graph[nodeId]
			if not node then continue end

			local distance = (node.position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestId = node.id
			end
		end

		return nearestId
	end

	for _, node in state.graph do
		local distance = (node.position - position).Magnitude
		if distance < nearestDistance then
			nearestDistance = distance
			nearestId = node.id
		end
	end

	return nearestId
end

local function guidedDestinationIsClear(position: Vector3, relaxed: boolean?): boolean
	if getBarrierPenalty(position) > (if relaxed then 0.18 else 0.08) then return false end

	local floorHit = getFloorHit(position, 8, 12)
	if not floorHit then return false end
	if isBarrierInstance(floorHit.Instance) then return false end
	local map = workspace:FindFirstChild("Map")
	if map and not floorHit.Instance:IsDescendantOf(map) then return false end

	losParams.FilterDescendantsInstances = getIgnoreList()
	local sideClearance = if relaxed then 2.65 else 4.5
	for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local result = workspace:Raycast(position + Vector3.yAxis * 0.7, direction * sideClearance, losParams)
		if result and result.Instance.CanCollide and not isBarrierInstance(result.Instance) then return false end
	end

	local headResult = workspace:Raycast(position, Vector3.yAxis * (if relaxed then 3.25 else 4.5), losParams)
	if headResult then return false end

	if map then
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { map }
		params.MaxParts = 24

		local standCenter = floorHit.Position + Vector3.yAxis * 3.2
		local standSize = if relaxed then Vector3.new(2.6, 4.8, 2.6) else Vector3.new(4.2, 5.2, 4.2)
		for _, part in workspace:GetPartBoundsInBox(CFrame.new(standCenter), standSize, params) do
			if not part.CanCollide then continue end
			if part == floorHit.Instance then continue end
			if isBarrierInstance(part) then return false end
			if part.Position.Y + part.Size.Y * 0.5 <= floorHit.Position.Y + 0.35 then continue end

			return false
		end
	end

	return true
end

local function getGuidedRecentPenalty(position: Vector3): number
	local penalty = 0
	for index, recentPosition in state.guidedRecentDestinations do
		local flatDistance = Vector3.new(position.X - recentPosition.X, 0, position.Z - recentPosition.Z).Magnitude
		local heightDistance = math.abs(position.Y - recentPosition.Y)
		local ageWeight = math.clamp((#state.guidedRecentDestinations - index + 1) / 6, 0.25, 1)
		if flatDistance < 55 and heightDistance < 18 then
			penalty += (55 - flatDistance) * 1.4 * ageWeight
		elseif flatDistance < 32 then
			penalty += (32 - flatDistance) * 0.7 * ageWeight
		end
	end

	return penalty
end

local function chooseGuidedDestination(rootPart: BasePart): Vector3?
	local bestPosition: Vector3? = nil
	local bestScore = -math.huge

	if #state.graph > 0 then
		local origin = rootPart.Position
		local startNodeId = nearestNodeId(origin, math.max(70, state.graphStep * 16))
		local candidates = {}
		local looseGraphFallbacks = {}
		for _, node in state.graph do
			local distance = (node.position - origin).Magnitude
			if string.find(node.partName, ".Barriers.") or string.find(node.partName, "Barriers") then continue end
			if distance >= 30 and distance <= 220 and node.barrierPenalty <= 0.2 and node.deadEndPenalty < 1 then
				local looseScore = -math.abs(distance - 100)
					- node.deadEndPenalty * 30
					- node.barrierPenalty * 55
					+ math.abs(getFloorHeightDelta(origin, node.position)) * 1.4
					- getGuidedRecentPenalty(node.position)
					+ math.random() * 14
				table.insert(looseGraphFallbacks, {
					position = node.position,
					score = looseScore,
				})
			end
			if distance < 45 or distance > 150 then continue end
			if #node.links < 2 then continue end
			if node.deadEndPenalty >= 0.75 then continue end
			if node.barrierPenalty > 0.05 then continue end

			local floorDelta = getFloorHeightDelta(origin, node.position)
			local verticalMagnitude = math.abs(floorDelta)
			local exploreBonus = if node.visits < 2 then 18 elseif node.visits < 5 then 8 else 0
			local routeOptions = math.clamp(#node.links - 1, 0, 5) * 5
			local verticalBonus = if verticalMagnitude >= 9 then math.clamp(verticalMagnitude, 9, 34) * 0.9 else -6
			local climbBonus = if floorDelta > 6 then 7 else 0
			local distanceFit = -math.abs(distance - 100) * 0.09
			local recentPenalty = getGuidedRecentPenalty(node.position)
			local score = exploreBonus
				+ routeOptions
				+ verticalBonus
				+ climbBonus
				+ distanceFit
				- node.barrierPenalty * 24
				- node.deadEndPenalty * 12
				- recentPenalty
				+ math.random() * 18
			table.insert(candidates, {
				id = node.id,
				position = node.position,
				score = score,
			})
			if score > bestScore then
				bestScore = score
				bestPosition = node.position
			end
		end

		table.sort(candidates, function(a, b)
			return a.score > b.score
		end)

		bestPosition = nil
		for _, relaxed in { false, true } do
			local validCandidates = {}
			for index = 1, math.min(if relaxed then 48 else 28, #candidates) do
				local candidate = candidates[index]
				if not guidedDestinationIsClear(candidate.position, relaxed) then continue end
				if not relaxed and startNodeId and #findPath(startNodeId, candidate.id) < 2 then continue end

				table.insert(validCandidates, candidate)
			end
			if #validCandidates > 0 then
				local pickIndex = math.random(1, math.min(#validCandidates, if relaxed then 10 else 7))
				bestPosition = validCandidates[pickIndex].position
			end
			if bestPosition then break end
		end
		if not bestPosition and #looseGraphFallbacks > 0 then
			table.sort(looseGraphFallbacks, function(a, b)
				return a.score > b.score
			end)
			bestPosition = looseGraphFallbacks[math.random(1, math.min(10, #looseGraphFallbacks))].position
		end
	end

	if bestPosition then return bestPosition end

	local minPosition, maxPosition = getMapBounds()
	if not minPosition or not maxPosition then return nil end

	local inset = 18
	local minX = minPosition.X + inset
	local maxX = maxPosition.X - inset
	local minZ = minPosition.Z + inset
	local maxZ = maxPosition.Z - inset
	if minX >= maxX or minZ >= maxZ then return nil end

	local originFloorY = getFloorY(rootPart.Position)
	for _ = 1, 56 do
		local x = minX + math.random() * (maxX - minX)
		local z = minZ + math.random() * (maxZ - minZ)
		local floorHit = raycastGuidedMapFloor(Vector3.new(x, 0, z), minPosition, maxPosition)
		if not floorHit then continue end

		local candidatePosition = floorHit.Position + Vector3.yAxis * 3
		if not guidedDestinationIsClear(candidatePosition, true) then continue end

		local flatDistance = Vector3.new(candidatePosition.X - rootPart.Position.X, 0, candidatePosition.Z - rootPart.Position.Z).Magnitude
		if flatDistance < 35 or flatDistance > 220 then continue end

		local verticalMagnitude = math.abs(floorHit.Position.Y - originFloorY)
		local verticalScore = if verticalMagnitude >= 8 then math.clamp(verticalMagnitude, 8, 36) * 1.1 else -10
		local distanceScore = -math.abs(flatDistance - 105) * 0.08
		local barrierScore = -getBarrierPenalty(candidatePosition) * 28
		local recentPenalty = getGuidedRecentPenalty(candidatePosition)
		local spreadBonus = math.min(flatDistance, 140) * 0.04
		local score = verticalScore + distanceScore + barrierScore + spreadBonus - recentPenalty + math.random() * 18
		if score > bestScore then
			bestScore = score
			bestPosition = candidatePosition
		end
	end

	return bestPosition
end

findPath = function(startId: number, goalId: number): { number }
	if startId == goalId then return { startId } end

	local open = { startId }
	local openLookup: { [number]: boolean } = {
		[startId] = true,
	}
	local cameFrom: { [number]: number } = {}
	local costSoFar: { [number]: number } = {
		[startId] = 0,
	}
	local expansions = 0

	while #open > 0 do
		expansions += 1
		if expansions > Config.MAX_PATH_EXPANSIONS then return {} end

		local bestOpenIndex = 1
		local bestOpenCost = math.huge

		for index, nodeId in open do
			local node = state.graph[nodeId]
			local heuristic = (node.position - state.graph[goalId].position).Magnitude
			local learnedBonus = math.clamp(node.score, -10, 18) * 2
			local totalCost = (costSoFar[nodeId] or math.huge) + heuristic - learnedBonus

			if totalCost < bestOpenCost then
				bestOpenIndex = index
				bestOpenCost = totalCost
			end
		end

		local currentId = table.remove(open, bestOpenIndex)
		openLookup[currentId] = nil

		if currentId == goalId then
			local path = { goalId }
			local previousId = goalId
			while cameFrom[previousId] do
				previousId = cameFrom[previousId]
				table.insert(path, 1, previousId)
			end

			return path
		end

		local currentNode = state.graph[currentId]
		for _, linkId in currentNode.links do
			local linkNode = state.graph[linkId]
			local learnedPenalty = math.clamp(-linkNode.score, 0, 10)
			local learnedBonus = math.clamp(linkNode.score, 0, 18)
			local newCost = (costSoFar[currentId] or 0) + (currentNode.position - linkNode.position).Magnitude + learnedPenalty - learnedBonus
			newCost += linkNode.wallPenalty * 24 + linkNode.deadEndPenalty * 18 + linkNode.barrierPenalty * 16

			if costSoFar[linkId] and newCost >= costSoFar[linkId] then continue end

			costSoFar[linkId] = newCost
			cameFrom[linkId] = currentId

			if not openLookup[linkId] then
				openLookup[linkId] = true
				table.insert(open, linkId)
			end
		end
	end

	return {}
end

local function hasDirectRoute(rootPart: BasePart, targetPosition: Vector3): boolean
	local delta = targetPosition - rootPart.Position
	if math.abs(delta.Y) > Config.DIRECT_ROUTE_HEIGHT_LIMIT then return false end

	losParams.FilterDescendantsInstances = getIgnoreList()
	local result = workspace:Raycast(rootPart.Position + Vector3.new(0, 1.8, 0), delta, losParams)
	if not result then return true end

	local map = workspace:FindFirstChild("Map")
	return not map or not result.Instance:IsDescendantOf(map)
end

isSwingBarNear = function(fromPosition: Vector3, toPosition: Vector3): boolean
	local midpoint = (fromPosition + toPosition) * 0.5

	for _, swingBar in swingBarParts do
		if swingBar.Parent and (swingBar.Position - midpoint).Magnitude < 14 then return true end
	end

	return false
end

local function chooseLightweightGraphHop(
	startPosition: Vector3,
	goalPosition: Vector3,
	desiredDirection: Vector3,
	mode: "Chase" | "Escape",
	threatPosition: Vector3?,
	forceRoute: boolean?
): (GraphNode?, string?)
	if #state.graph == 0 then return nil, nil end

	local startId = nearestNodeId(startPosition, math.max(45, state.graphStep * 10))
	local startNode = if startId then state.graph[startId] else nil
	if not startNode then return nil, nil end

	local currentGoalDistance = (goalPosition - startPosition).Magnitude
	local currentThreatDistance = if threatPosition then (startPosition - threatPosition).Magnitude else 0
	local desired = Vector3.new(desiredDirection.X, 0, desiredDirection.Z)
	local bestNode: GraphNode? = nil
	local bestFirstHop: GraphNode? = nil
	local bestScore = -math.huge
	local visited: { [number]: boolean } = {
		[startNode.id] = true,
	}
	local queue = {}
	local queueIndex = 1
	local expansionCount = 0

	for _, linkId in startNode.links do
		local linkNode = state.graph[linkId]
		if not linkNode then continue end

		table.insert(queue, {
			id = linkId,
			firstHopId = linkId,
			depth = 1,
			travel = (linkNode.position - startNode.position).Magnitude,
		})
	end

	while queue[queueIndex] and expansionCount < Config.LIGHT_PATH_MAX_EXPANSIONS do
		local entry = queue[queueIndex]
		queueIndex += 1
		if visited[entry.id] then continue end
		visited[entry.id] = true
		expansionCount += 1

		local node = state.graph[entry.id]
		local firstHop = state.graph[entry.firstHopId]
		if not node or not firstHop then continue end

		local nodeDelta = node.position - startPosition
		local flatNodeDelta = Vector3.new(nodeDelta.X, 0, nodeDelta.Z)
		local alignment = if desired.Magnitude > 0.05 and flatNodeDelta.Magnitude > 0.05 then flatNodeDelta.Unit:Dot(desired.Unit) else 0
		local goalProgress = currentGoalDistance - (node.position - goalPosition).Magnitude
		local routeOptions = math.clamp(#node.links - 1, -1, 4)
		local score: number

		if mode == "Escape" and threatPosition then
			local threatDistance = (node.position - threatPosition).Magnitude
			local escapeGain = threatDistance - currentThreatDistance
			local tangentAlignment = 0
			local away = startPosition - threatPosition
			local flatAway = Vector3.new(away.X, 0, away.Z)
			if flatAway.Magnitude > 0.05 and flatNodeDelta.Magnitude > 0.05 then
				local tangent = Vector3.new(-flatAway.Unit.Z, 0, flatAway.Unit.X) * state.runnerLapSign
				tangentAlignment = flatNodeDelta.Unit:Dot(tangent)
			end

			score = escapeGain * 1.5
				+ threatDistance * 0.14 * state.learnParams.runnerDistanceWeight
				+ tangentAlignment * 18 * state.learnParams.orbitWeight
				+ routeOptions * 11 * state.learnParams.routeOptionWeight
				- entry.travel * 0.28
				- node.deadEndPenalty * 44
				- node.wallPenalty * 40
				- node.barrierPenalty * 34
				+ node.score * 0.36
				+ (if node.visits < 2 then 10 elseif node.visits < 5 then 4 else 0) * state.learnParams.exploreWeight

			if threatDistance < Config.TAG_RANGE * 2 then score -= 55 end
			if node.openDirections <= 2 and escapeGain <= 4 then score -= 32 end
		else
			local targetHeightDelta = goalPosition.Y - startPosition.Y
			local nodeHeightDelta = node.position.Y - startPosition.Y
			local heightBonus = if targetHeightDelta > 5
				then math.clamp(nodeHeightDelta, -4, 14) * 0.85
				else math.clamp(-nodeHeightDelta, -8, 10) * 0.18
			score = goalProgress * 2.55
				+ alignment * 9
				+ heightBonus
				+ routeOptions * (if forceRoute then 4.5 else 1.5)
				- entry.travel * 0.34
				- node.deadEndPenalty * 26
				- node.wallPenalty * 26
				- node.barrierPenalty * 18
				+ node.score * 0.42

			if node.openDirections <= 2 and goalProgress < 7 then score -= 18 end
		end

		if score > bestScore then
			bestScore = score
			bestNode = node
			bestFirstHop = firstHop
		end

		if entry.depth < Config.LIGHT_PATH_MAX_DEPTH then
			for _, linkId in node.links do
				if visited[linkId] then continue end

				local linkNode = state.graph[linkId]
				if not linkNode then continue end
				table.insert(queue, {
					id = linkId,
					firstHopId = entry.firstHopId,
					depth = entry.depth + 1,
					travel = entry.travel + (linkNode.position - node.position).Magnitude,
				})
			end
		end
	end

	if not bestNode or not bestFirstHop then return nil, nil end

	if mode == "Chase" then
		local improvement = currentGoalDistance - (bestNode.position - goalPosition).Magnitude
		if not forceRoute and improvement < math.max(4.5, state.graphStep * 0.45) then return nil, nil end
	end

	return bestFirstHop, startNode.linkTechs[bestFirstHop.id] or getGraphTraversalTech(startNode.position, bestFirstHop.position)
end

local function getRunnerEscapeGoal(rootPart: BasePart, threatRoot: BasePart): (Vector3?, number?)
	if #state.graph == 0 then return nil end

	local currentThreatDistance = (rootPart.Position - threatRoot.Position).Magnitude
	local bestPosition: Vector3? = nil
	local bestId: number? = nil
	local bestScore = -math.huge

	for _, nodeId in collectGraphNodeIdsNear(rootPart.Position, 145) do
		local node = state.graph[nodeId]
		if not node then continue end

		local distanceFromRunner = (node.position - rootPart.Position).Magnitude

		local distanceFromThreat = (node.position - threatRoot.Position).Magnitude
		local escapeGain = distanceFromThreat - currentThreatDistance
		local verticalOption = math.clamp(node.position.Y - rootPart.Position.Y, -8, 16) * 0.32 * state.learnParams.verticalRollWeight
		local routeOptions = math.clamp(#node.links - 1, -1, 4)
		local nodeDelta = node.position - rootPart.Position
		local flatNodeDelta = Vector3.new(nodeDelta.X, 0, nodeDelta.Z)
		local awayDirection = rootPart.Position - threatRoot.Position
		local flatAwayDirection = Vector3.new(awayDirection.X, 0, awayDirection.Z)
		local lapAlignment = 0
		if flatNodeDelta.Magnitude > 0.1 and flatAwayDirection.Magnitude > 0.1 then
			local tangentDirection = Vector3.new(-flatAwayDirection.Unit.Z, 0, flatAwayDirection.Unit.X) * state.runnerLapSign
			lapAlignment = flatNodeDelta.Unit:Dot(tangentDirection)
		end
		local deadEndPenalty = node.deadEndPenalty * 52
		local wallPenalty = node.wallPenalty * 46
		local closeToThreatPenalty = math.max(0, 32 - distanceFromThreat) * 1.2
		local repeatPenalty = if state.runnerLastEscapeGoalId == node.id then state.runnerEscapeGoalRepeat * 14 else 0
		local exploreBonus = (if node.visits < 2 then 14 elseif node.visits < 5 then 6 else 0) * state.learnParams.exploreWeight
		local routeComplexityCost = math.max(0, distanceFromRunner - Config.GRAPH_LOCAL_RADIUS) * 0.06
		local backtrackAllowance = if routeOptions >= 2 and distanceFromThreat > Config.TAG_RANGE * 3
			then math.max(0, -escapeGain) * 1.35 * state.learnParams.backtrackWeight
			else 0
		local score = escapeGain * 1.45
			+ distanceFromThreat * 0.16 * state.learnParams.runnerDistanceWeight
			- distanceFromRunner * 0.26
			+ verticalOption
			+ routeOptions * 13 * state.learnParams.routeOptionWeight
			+ lapAlignment * 22 * state.learnParams.orbitWeight
			+ backtrackAllowance
			+ exploreBonus
			+ node.score * 0.25
			- deadEndPenalty
			- wallPenalty
			- closeToThreatPenalty
			- node.barrierPenalty * 36
			- repeatPenalty
			- routeComplexityCost

		if distanceFromThreat < Config.TAG_RANGE * 2 then
			score -= 70
		end
		if distanceFromRunner < state.graphStep then
			score -= 12
		end
		if node.openDirections <= 2 and escapeGain <= 0 then
			score -= 35
		end

		if score > bestScore then
			bestScore = score
			bestPosition = node.position
			bestId = node.id
		end
	end

	return bestPosition, bestId
end

local function getDirectionBucket(direction: Vector3): number
	local angle = math.atan2(direction.X, direction.Z)
	local bucket = math.floor(((angle + math.pi) / (math.pi * 2)) * 8) + 1
	return math.clamp(bucket, 1, 8)
end

local function recordDirectionReward(scores: { [number]: DirectionScore }, moveDirection: Vector3, reward: number)
	if moveDirection.Magnitude <= 0.05 then return end

	local bucket = getDirectionBucket(moveDirection)
	local directionScore = scores[bucket]
	if not directionScore then
		directionScore = {
			score = 0,
			visits = 0,
		}
		scores[bucket] = directionScore
	end

	directionScore.visits += 1
	directionScore.score += (reward - directionScore.score) / math.max(1, directionScore.visits)
end

local function addReward(position: Vector3, moveDirection: Vector3, reward: number)
	local nodeId = nearestNodeId(position, math.max(55, state.graphStep * 12))
	if nodeId then
		local node = state.graph[nodeId]
		node.visits += 1
		node.score += (reward - node.score) / math.max(1, node.visits)
	end

	recordDirectionReward(state.directionScores, moveDirection, reward)
	recordDirectionReward(state.runnerDirectionScores, moveDirection, reward * 0.35)
end

local function getLearnedNudge(moveDirection: Vector3): Vector3
	if moveDirection.Magnitude < 0.05 then return Vector3.zero end

	local bestBucket = nil
	local bestScore = -math.huge
	for bucket, directionScore in state.directionScores do
		if directionScore.visits >= 2 and directionScore.score > bestScore then
			bestBucket = bucket
			bestScore = directionScore.score
		end
	end

	if not bestBucket or bestScore <= 0 then return Vector3.zero end

	local angle = ((bestBucket - 0.5) / 8) * math.pi * 2 - math.pi
	return Vector3.new(math.sin(angle), 0, math.cos(angle)) * math.clamp(bestScore / 12, 0, 0.25)
end

local function addRunnerReward(position: Vector3, moveDirection: Vector3, reward: number)
	local nodeId = nearestNodeId(position, math.max(55, state.graphStep * 12))
	if nodeId then
		local node = state.graph[nodeId]
		node.visits += 1
		node.score += (reward * 0.45 - node.score) / math.max(1, node.visits)
	end

	recordDirectionReward(state.runnerDirectionScores, moveDirection, reward)
	recordDirectionReward(state.directionScores, moveDirection, reward * 0.25)
end

local function getRunnerLearnedNudge(moveDirection: Vector3): Vector3
	if moveDirection.Magnitude < 0.05 then return Vector3.zero end

	local bestBucket = nil
	local bestScore = -math.huge
	for bucket, directionScore in state.runnerDirectionScores do
		if directionScore.visits >= 2 and directionScore.score > bestScore then
			bestBucket = bucket
			bestScore = directionScore.score
		end
	end

	if not bestBucket or bestScore <= 0 then return Vector3.zero end

	local angle = ((bestBucket - 0.5) / 8) * math.pi * 2 - math.pi
	return Vector3.new(math.sin(angle), 0, math.cos(angle)) * math.clamp(bestScore / 12, 0, 0.25)
end

local function chooseSidewaysMoveDirection(
	rootPart: BasePart,
	baseDirection: Vector3,
	goalPosition: Vector3,
	isRunner: boolean
): Vector3
	if baseDirection.Magnitude < 0.05 then return baseDirection end

	local now = os.clock()
	local lastCheckTime = if isRunner then state.runnerLastSidewaysCheckTime else state.lastSidewaysCheckTime
	local cachedDirection = if isRunner then state.runnerSidewaysMoveDirection else state.sidewaysMoveDirection
	if now - lastCheckTime < 0.14 and cachedDirection.Magnitude > 0.05 then return cachedDirection end

	local baseUnit = baseDirection.Unit
	local right = Vector3.new(baseUnit.Z, 0, -baseUnit.X)
	local candidates = {
		baseUnit,
		(baseUnit + right * 0.55).Unit,
		(baseUnit - right * 0.55).Unit,
		(baseUnit * 0.62 + right).Unit,
		(baseUnit * 0.62 - right).Unit,
	}
	local currentDistance = (goalPosition - rootPart.Position).Magnitude
	local bestDirection = baseUnit
	local bestScore = -math.huge
	local baseScore = -math.huge

	for _, candidateDirection in candidates do
		local clearDistance = getClearDistance(rootPart, candidateDirection)
		local probePosition = rootPart.Position + candidateDirection * math.min(16, math.max(6, clearDistance))
		local probeDistance = (goalPosition - probePosition).Magnitude
		local progress = if isRunner then probeDistance - currentDistance else currentDistance - probeDistance
		local sideAmount = math.abs(candidateDirection:Dot(right))
		local forwardAlignment = candidateDirection:Dot(baseUnit)
		local clearBonus = math.clamp(clearDistance, 0, Config.WALL_CHECK_DISTANCE) * 0.12
		local score = progress * 1.8 + clearBonus + sideAmount * 0.45 + forwardAlignment * 0.8
		if clearDistance < 3 then score -= 10 end
		if candidateDirection == baseUnit then baseScore = score end

		if score > bestScore then
			bestScore = score
			bestDirection = candidateDirection
		end
	end

	if bestDirection ~= baseUnit and bestScore > baseScore + 1.35 then
		local reward = math.clamp(bestScore, -6, 8)
		if isRunner then
			recordDirectionReward(state.runnerDirectionScores, bestDirection, reward)
		else
			recordDirectionReward(state.directionScores, bestDirection, reward)
		end
	else
		bestDirection = baseUnit
	end

	if isRunner then
		state.runnerLastSidewaysCheckTime = now
		state.runnerSidewaysMoveDirection = bestDirection
	else
		state.lastSidewaysCheckTime = now
		state.sidewaysMoveDirection = bestDirection
	end

	return bestDirection
end

local function rotateFlatDirection(direction: Vector3, radians: number): Vector3
	local cos = math.cos(radians)
	local sin = math.sin(radians)
	return Vector3.new(direction.X * cos - direction.Z * sin, 0, direction.X * sin + direction.Z * cos)
end

getClearDistance = function(rootPart: BasePart, direction: Vector3): number
	if direction.Magnitude < 0.05 then return 0 end

	raycastParams.FilterDescendantsInstances = getIgnoreList()

	local origin = rootPart.Position + Vector3.new(0, 2.2, 0)
	local result = workspace:Raycast(origin, direction.Unit * Config.WALL_CHECK_DISTANCE, raycastParams)
	if not result then return Config.WALL_CHECK_DISTANCE end

	return (result.Position - origin).Magnitude
end

local function getApproachObstacleDistance(rootPart: BasePart, direction: Vector3, maxDistance: number): number?
	if direction.Magnitude < 0.05 then return nil end

	raycastParams.FilterDescendantsInstances = getIgnoreList()

	local flatDirection = Vector3.new(direction.X, 0, direction.Z)
	if flatDirection.Magnitude < 0.05 then return nil end

	local origin = rootPart.Position + Vector3.new(0, 2.35, 0)
	local result = workspace:Raycast(origin, flatDirection.Unit * maxDistance, raycastParams)
	if not result then return nil end
	if result.Instance:GetAttribute("NoClimb") == true then return nil end

	return (result.Position - origin).Magnitude
end

local function getMapBarriersFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end

	return map:FindFirstChild("Barriers")
end

isBarrierInstance = function(instance: Instance): boolean
	local barriersFolder = getMapBarriersFolder()
	return barriersFolder ~= nil and instance:IsDescendantOf(barriersFolder)
end

getBarrierPenalty = function(position: Vector3): number
	local barriersFolder = getMapBarriersFolder()
	if not barriersFolder then return 0 end

	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = { barriersFolder }
	local penalty = 0
	for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local result = workspace:Raycast(position + Vector3.yAxis * 2, direction * 18, raycastParams)
		if result then
			penalty += math.clamp(18 - (result.Position - position).Magnitude, 0, 18) / 18
		end
	end
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	return penalty
end

getFloorHit = function(position: Vector3, upDistance: number?, downDistance: number?): RaycastResult?
	raycastParams.FilterDescendantsInstances = getIgnoreList()

	local up = upDistance or 8
	local down = downDistance or 32
	local result = workspace:Raycast(position + Vector3.yAxis * up, Vector3.yAxis * -(up + down), raycastParams)
	if not result then return nil end
	if result.Normal.Y < 0.62 then return nil end

	return result
end

getFloorY = function(position: Vector3): number
	local result = getFloorHit(position, 8, 38)
	return if result then result.Position.Y else position.Y - 3
end

getFloorHeightDelta = function(fromPosition: Vector3, toPosition: Vector3): number
	return getFloorY(toPosition) - getFloorY(fromPosition)
end

local function getLocalGeometryKey(position: Vector3): string
	local cellSize = 26
	return `{math.floor(position.X / cellSize)}:{math.floor(position.Y / cellSize)}:{math.floor(position.Z / cellSize)}`
end

local function getPartMemoryKey(part: BasePart, techKey: string): string
	local position = part.Position
	return `{techKey}:{string.sub(part:GetFullName(), -48)}:{math.floor(position.X + 0.5)}:{math.floor(position.Y + 0.5)}:{math.floor(
		position.Z + 0.5
	)}`
end

local function getClosestPartTopPoint(part: BasePart, position: Vector3): Vector3
	local localPoint = part.CFrame:PointToObjectSpace(position)
	local halfSize = part.Size * 0.5
	local clamped = Vector3.new(math.clamp(localPoint.X, -halfSize.X, halfSize.X), halfSize.Y + 3, math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z))

	return part.CFrame:PointToWorldSpace(clamped)
end

local function getCachedLocalVaults(rootPart: BasePart, targetPosition: Vector3): { LocalVaultInfo }
	local cacheKey = getLocalGeometryKey(rootPart.Position)
	local cached = localGeometryCache[cacheKey]
	if cached then return cached.candidates end

	local map = workspace:FindFirstChild("Map")
	if not map then return {} end

	overlapParams.FilterDescendantsInstances = { map }

	local currentFloorY = getFloorY(rootPart.Position)
	local targetHeight = getFloorHeightDelta(rootPart.Position, targetPosition)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(rootPart.Position), Vector3.new(42, 24, 42), overlapParams)
	local candidates: { LocalVaultInfo } = {}

	for _, part in parts do
		if #candidates >= 18 then break end
		if not part:IsA("BasePart") then continue end
		if not part.CanCollide then continue end
		if part.Transparency >= 1 then continue end
		if part:GetAttribute("NoClimb") == true then continue end
		if isBarrierInstance(part) then continue end

		local topPosition = getClosestPartTopPoint(part, rootPart.Position)
		local flatDelta = Vector3.new(topPosition.X - rootPart.Position.X, 0, topPosition.Z - rootPart.Position.Z)
		local approachDistance = flatDelta.Magnitude
		if approachDistance < 3.1 or approachDistance > 19 then continue end

		local heightDelta = topPosition.Y - currentFloorY
		if heightDelta < 0.75 or heightDelta > Config.SLIDE_BOOST_MAX_HEIGHT_STUDS + 1.25 then continue end

		local techKey = getVaultTechForHeight(heightDelta, targetHeight)
		if not techKey then continue end

		local standCheck = getFloorHit(topPosition, 4, 8)
		if not standCheck then continue end

		table.insert(candidates, {
			part = part,
			position = topPosition,
			direction = flatDelta.Unit,
			heightDelta = heightDelta,
			approachDistance = approachDistance,
			techKey = techKey,
			key = getPartMemoryKey(part, techKey),
		})
	end

	cached = {
		candidates = candidates,
	}
	localGeometryCache[cacheKey] = cached
	return candidates
end

local function steerAroundLocalObstacles(rootPart: BasePart, desiredDirection: Vector3): Vector3
	if desiredDirection.Magnitude < 0.05 then return Vector3.zero end

	local now = os.clock()
	if now - state.lastSteeringCheckTime < Config.STEERING_CHECK_INTERVAL_SECONDS then return state.steeredMoveDirection end
	state.lastSteeringCheckTime = now

	local desired = desiredDirection.Unit
	local straightClearDistance = getClearDistance(rootPart, desired)
	if straightClearDistance >= Config.WALL_CHECK_DISTANCE * 0.85 then
		state.steeredMoveDirection = desired
		return desired
	end

	local bestDirection = desired
	local bestScore = -math.huge
	local angles = {
		0,
		math.rad(32),
		math.rad(-32),
		math.rad(62),
		math.rad(-62),
		math.rad(105),
		math.rad(-105),
	}

	for _, angle in angles do
		local direction = rotateFlatDirection(desired, angle)
		local clearDistance = getClearDistance(rootPart, direction)
		local targetAlignment = direction:Dot(desired)
		local score = clearDistance * 2 + targetAlignment * 4

		if clearDistance < 2.4 then
			score -= 10
		end

		if score > bestScore then
			bestScore = score
			bestDirection = direction
		end
	end

	state.steeredMoveDirection = bestDirection
	return bestDirection
end

local function steerRunnerAroundLocalObstacles(rootPart: BasePart, desiredDirection: Vector3): Vector3
	if desiredDirection.Magnitude < 0.05 then return Vector3.zero end

	local now = os.clock()
	if now - state.runnerLastSteeringCheckTime < Config.STEERING_CHECK_INTERVAL_SECONDS then return state.runnerSteeredMoveDirection end
	state.runnerLastSteeringCheckTime = now

	local desired = desiredDirection.Unit
	local straightClearDistance = getClearDistance(rootPart, desired)
	if straightClearDistance >= Config.WALL_CHECK_DISTANCE * 0.85 then
		state.runnerSteeredMoveDirection = desired
		return desired
	end

	local bestDirection = desired
	local bestScore = -math.huge
	local angles = {
		0,
		math.rad(35),
		math.rad(-35),
		math.rad(75),
		math.rad(-75),
		math.rad(135),
		math.rad(-135),
	}

	for _, angle in angles do
		local direction = rotateFlatDirection(desired, angle)
		local clearDistance = getClearDistance(rootPart, direction)
		local threatAlignment = direction:Dot(desired)
		local score = clearDistance * 2 + threatAlignment * 5

		if clearDistance < 2.4 then
			score -= 10
		end

		if score > bestScore then
			bestScore = score
			bestDirection = direction
		end
	end

	state.runnerSteeredMoveDirection = bestDirection
	return bestDirection
end

local function getAerialParkourHit(rootPart: BasePart, moveDirection: Vector3): (RaycastResult?, boolean)
	if moveDirection.Magnitude < 0.2 then return nil, false end

	raycastParams.FilterDescendantsInstances = getIgnoreList()

	local forward = moveDirection.Unit
	local obstacleHit: RaycastResult? = nil

	for distance = 2.5, 0.5, -0.25 do
		if not obstacleHit then
			local origin = rootPart.Position + forward * distance + Vector3.yAxis * 2.75
			local direction = -Vector3.yAxis * 3.25

			obstacleHit = workspace:Raycast(origin, direction, raycastParams)
		end
	end

	if not obstacleHit then return nil, false end

	local forwardCheckOrigin = rootPart.Position + Vector3.new(0, 1.25, 0) - forward * 2.5
	local forwardCheck = workspace:Raycast(forwardCheckOrigin, forward * 3, raycastParams)
	if forwardCheck then return nil, false end

	local instance = obstacleHit.Instance
	local parent = instance.Parent
	local isSwingBar = instance:GetAttribute("SwingBar") == true
		or CollectionService:HasTag(instance, "SwingBar")
		or (parent ~= nil and parent:GetAttribute("SwingBar") == true)
		or (parent ~= nil and CollectionService:HasTag(parent, "SwingBar"))

	return obstacleHit, isSwingBar
end

local function getVaultHeight(rootPart: BasePart, hitResult: RaycastResult): number
	return math.clamp(math.abs(hitResult.Position.Y - rootPart.Position.Y), 0, 2.75)
end

local function startBotVault(rootPart: BasePart, humanoid: Humanoid, hitResult: RaycastResult): boolean
	local now = os.clock()
	if now - state.lastParkourActionTime < Config.PARKOUR_ACTION_COOLDOWN_SECONDS then return false end
	if hitResult.Instance:GetAttribute("NoClimb") then return false end

	state.lastParkourActionTime = now

	local bot = rootPart:FindFirstAncestorOfClass("Model")
	if bot then bot:SetAttribute("Vaulting", true) end

	local vaultHeight = getVaultHeight(rootPart, hitResult)
	if humanoid.FloorMaterial ~= Enum.Material.Air then tryBotJump(rootPart, humanoid, 28, nil, "Jump1") end
	BotRuntime.playActionAnimation(bot, "Vault")
	PlaySound("Vault", rootPart, vaultHeight)
	local airborneDelay = if humanoid.FloorMaterial ~= Enum.Material.Air and vaultHeight > 1.35 then 0.12 else 0

	task.delay(airborneDelay, function()
		if not rootPart.Parent then return end

		rootPart.AssemblyLinearVelocity = Vector3.new(
			rootPart.AssemblyLinearVelocity.X,
			math.clamp(vaultHeight / 1.5 * 30, 30, math.huge),
			rootPart.AssemblyLinearVelocity.Z
		) - rootPart.CFrame.LookVector * 2

		humanoid.WalkSpeed += 2
		addReward(rootPart.Position, rootPart.CFrame.LookVector, 8 + vaultHeight * 4)
	end)

	task.delay(airborneDelay + 0.14, function()
		if bot then bot:SetAttribute("Vaulting", nil) end
	end)

	if state.debug then pushLog(`Vault action: {math.floor(vaultHeight * 100) / 100} studs over {hitResult.Instance.Name}.`) end

	rewardRouteVault(rootPart, rootPart.CFrame.LookVector)
	return true
end

getVaultTechForHeight = function(heightDelta: number, preferredHeight: number?): string?
	local targetHeight = preferredHeight or heightDelta
	if heightDelta <= Config.GROUND_VAULT_REACH_STUDS + 0.75 then return "Vault" end
	if heightDelta >= Config.HIGH_VAULT_MIN_STUDS - 1.4 and heightDelta <= Config.HIGH_VAULT_MAX_STUDS + 0.3 then return "TimedHighVault" end
	if heightDelta >= Config.SLIDE_BOOST_MIN_HEIGHT_STUDS - 0.85 and heightDelta <= Config.SLIDE_BOOST_MAX_HEIGHT_STUDS + 0.35 then
		return "SlideVault"
	end
	if heightDelta <= Config.ROLL_BOOST_MAX_HEIGHT_STUDS + 0.5 and targetHeight > Config.HIGH_VAULT_MAX_STUDS then return "RollBoostVault" end

	return nil
end

local function scanVaultCandidate(rootPart: BasePart, targetPosition: Vector3, desiredDirection: Vector3): (Vector3?, string?, string?)
	if desiredDirection.Magnitude < 0.2 then return nil, nil end

	raycastParams.FilterDescendantsInstances = getIgnoreList()

	local bestDirection: Vector3? = nil
	local bestTech: string? = nil
	local bestGeometryKey: string? = nil
	local bestScore = -math.huge
	local rootFloorY = getFloorY(rootPart.Position)
	local targetHeight = getFloorHeightDelta(rootPart.Position, targetPosition)
	local baseDirection = desiredDirection.Unit

	for _, candidate in getCachedLocalVaults(rootPart, targetPosition) do
		local directionAlignment = candidate.direction:Dot(baseDirection)
		if directionAlignment < -0.25 then continue end

		local targetProgress = (targetPosition - rootPart.Position).Magnitude - (targetPosition - candidate.position).Magnitude
		local targetFit = math.abs(targetHeight - candidate.heightDelta)
		local distanceFit = math.abs(
			candidate.approachDistance
				- (if candidate.techKey == "Vault" then Config.GROUND_VAULT_REACH_STUDS elseif candidate.techKey == "SlideVault" then 12.2 else 10.25)
		)
		local scoreInfo = state.geometryScores[candidate.key]
		local learnedScore = if scoreInfo then scoreInfo.score else 0
		local learnedVisits = if scoreInfo then scoreInfo.visits else 0
		local score = targetProgress * 0.8
			+ directionAlignment * 6
			- targetFit * 0.85
			- distanceFit * 0.42
			+ candidate.heightDelta * 0.48
			+ learnedScore * 1.4
			- math.min(learnedVisits, 10) * 0.04

		if candidate.techKey == "SlideVault" then
			score += 1.8
		elseif candidate.techKey == "TimedHighVault" then
			score += 1.2
		end

		if score > bestScore then
			bestScore = score
			bestDirection = candidate.direction
			bestTech = candidate.techKey
			bestGeometryKey = candidate.key
		end
	end

	if bestDirection and bestScore > -4 then return bestDirection, bestTech, bestGeometryKey end

	local wideScan = state.stuckSeconds > 0.85
	local angles = if wideScan
		then { 0, math.rad(22), math.rad(-22), math.rad(48), math.rad(-48), math.rad(82), math.rad(-82) }
		else { 0, math.rad(24), math.rad(-24), math.rad(52), math.rad(-52) }
	local distances = if wideScan
		then { Config.GROUND_VAULT_REACH_STUDS, 8, Config.HIGH_VAULT_MIN_STUDS, Config.HIGH_VAULT_MAX_STUDS, 13, 17 }
		else { Config.GROUND_VAULT_REACH_STUDS, Config.HIGH_VAULT_MIN_STUDS, Config.HIGH_VAULT_MAX_STUDS, 13 }

	for _, angle in angles do
		local direction = rotateFlatDirection(baseDirection, angle)
		for _, distance in distances do
			local origin = rootPart.Position + direction * distance + Vector3.yAxis * 24
			local result = workspace:Raycast(origin, Vector3.yAxis * -42, raycastParams)
			if not result then continue end
			if result.Normal.Y < 0.62 then continue end
			if result.Instance:GetAttribute("NoClimb") == true then continue end

			local standCheck = workspace:Raycast(result.Position + Vector3.yAxis * 3, Vector3.yAxis * 4, raycastParams)
			if standCheck then continue end

			local heightDelta = result.Position.Y - rootFloorY
			if heightDelta < 0.75 then continue end

			local techKey = getVaultTechForHeight(heightDelta, targetHeight)
			if not techKey then continue end

			local targetFit = math.abs(targetHeight - heightDelta)
			local anglePenalty = math.abs(angle) * 3
			local distanceFit =
				math.abs(distance - (if techKey == "Vault" then Config.GROUND_VAULT_REACH_STUDS else if techKey == "SlideVault" then 12.2 else 10.25))
			local targetProgress = (targetPosition - rootPart.Position).Magnitude - (targetPosition - result.Position).Magnitude
			local score = targetProgress * 0.55 - targetFit * 1.05 - anglePenalty - distanceFit * 0.35 + heightDelta * 0.42

			if techKey == "JumpProbe" then
				score -= 8
			elseif techKey == "TimedHighVault" then
				score += 2.5
			elseif techKey == "SlideVault" and heightDelta < 11 then
				score -= 2
			end

			if score > bestScore then
				bestScore = score
				bestDirection = direction
				bestTech = techKey
				bestGeometryKey = nil
			end
		end
	end

	return bestDirection, bestTech, bestGeometryKey
end

tryBotJump = function(
	rootPart: BasePart,
	humanoid: Humanoid,
	verticalVelocity: number,
	forwardVelocity: Vector3?,
	animationName: string?,
	allowAirOverride: boolean?
): boolean
	if humanoid.FloorMaterial == Enum.Material.Air and not allowAirOverride then return false end

	local now = os.clock()
	if now - state.lastBasicJumpTime < Config.BASIC_JUMP_COOLDOWN_SECONDS then return false end

	state.lastBasicJumpTime = now
	humanoid.Jump = true
	local jumpingSound = rootPart:FindFirstChild("Jumping")
	if jumpingSound and jumpingSound:IsA("Sound") then
		jumpingSound.SoundId = "rbxassetid://121152687916961"
		jumpingSound:Play()
	end
	rootPart.AssemblyLinearVelocity = Vector3.new(
		rootPart.AssemblyLinearVelocity.X,
		math.max(rootPart.AssemblyLinearVelocity.Y, verticalVelocity),
		rootPart.AssemblyLinearVelocity.Z
	) + (forwardVelocity or Vector3.zero)
	BotRuntime.playActionAnimation(rootPart:FindFirstAncestorOfClass("Model"), animationName or "Jump1")
	return true
end

local function tryBasicJump(rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3, moveDirection: Vector3)
	if moveDirection.Magnitude < 0.2 then return end
	if humanoid.FloorMaterial == Enum.Material.Air then return end

	local now = os.clock()
	if now - state.lastBasicJumpTime < Config.BASIC_JUMP_COOLDOWN_SECONDS then return end
	if state.slideBoostInProgress then return end

	local heightDelta = getFloorHeightDelta(rootPart.Position, targetPosition)
	local clearDistance = getClearDistance(rootPart, moveDirection)
	local shouldJumpForHeight = heightDelta > 1.75 and heightDelta <= 7.25 and clearDistance > 2.2
	local shouldHopObstacle = clearDistance <= 3.5 and heightDelta > -1 and heightDelta <= 5.5
	if not shouldJumpForHeight and not shouldHopObstacle then return end

	local jumped =
		tryBotJump(rootPart, humanoid, if shouldHopObstacle then 32 else 27, moveDirection.Unit * (if shouldHopObstacle then 5 else 2), "Jump1")
	if not jumped then return end

	if state.debug then pushLog(`Jump action: height {math.floor(heightDelta * 10) / 10}, clear {math.floor(clearDistance * 10) / 10}.`) end
end

local function startBotSwing(rootPart: BasePart, humanoid: Humanoid, hitResult: RaycastResult, moveDirection: Vector3)
	local now = os.clock()
	if now - state.lastParkourActionTime < 0.45 then return end

	state.lastParkourActionTime = now

	local bot = rootPart:FindFirstAncestorOfClass("Model")
	if bot then bot:SetAttribute("Swinging", true) end

	local swingPart = hitResult.Instance
	local originalCollide = swingPart.CanCollide
	local parentPart: BasePart? = nil
	local originalParentCollide = false
	swingPart.CanCollide = false
	if swingPart.Parent and swingPart.Parent:GetAttribute("SwingBar") then
		local possibleParentPart = swingPart.Parent
		if possibleParentPart:IsA("BasePart") then
			parentPart = possibleParentPart
			originalParentCollide = possibleParentPart.CanCollide
			possibleParentPart.CanCollide = false
		end
	end

	local fallSpeed = math.clamp(-rootPart.AssemblyLinearVelocity.Y, 25, 95)
	local swingFactor = (fallSpeed / 25) ^ 0.7
	local launchDirection = if moveDirection.Magnitude > 0.1 then moveDirection.Unit else rootPart.CFrame.LookVector

	if humanoid.FloorMaterial ~= Enum.Material.Air then tryBotJump(rootPart, humanoid, 24, nil, "Jump1") end
	BotRuntime.playActionAnimation(bot, "Swing")
	PlaySound("Swing", rootPart)
	rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.new(hitResult.Position + Vector3.new(0, -1.5, 0)), 0.35)

	task.delay(0.18, function()
		if not rootPart.Parent then
			swingPart.CanCollide = originalCollide
			if parentPart then parentPart.CanCollide = originalParentCollide end
			if bot then bot:SetAttribute("Swinging", nil) end
			return
		end

		rootPart.AssemblyLinearVelocity = Vector3.new(
			rootPart.AssemblyLinearVelocity.X,
			math.max(rootPart.AssemblyLinearVelocity.Y, 16),
			rootPart.AssemblyLinearVelocity.Z
		) + launchDirection * (swingFactor * 50)

		swingPart.CanCollide = originalCollide
		if parentPart then parentPart.CanCollide = originalParentCollide end
		if bot then bot:SetAttribute("Swinging", nil) end

		addReward(rootPart.Position, launchDirection, 12 + swingFactor * 10)
		if state.debug then pushLog(`Swing action: {math.floor(swingFactor * 100)}% vps from {math.floor(fallSpeed)} fall speed.`) end
	end)
end

local function tryAerialParkour(rootPart: BasePart, humanoid: Humanoid, moveDirection: Vector3)
	if not state.autoVault then return end
	if moveDirection.Magnitude < 0.2 then return end

	local now = os.clock()
	if now - state.lastVaultCheckTime < Config.VAULT_CHECK_INTERVAL_SECONDS then return end
	state.lastVaultCheckTime = now

	local hitResult, isSwingBar = getAerialParkourHit(rootPart, moveDirection)
	if not hitResult then return end

	if isSwingBar then
		startBotSwing(rootPart, humanoid, hitResult, moveDirection)
	else
		startBotVault(rootPart, humanoid, hitResult)
	end
end

local function tryValidatedBotVault(
	rootPart: BasePart,
	humanoid: Humanoid,
	moveDirection: Vector3,
	requireGrounded: boolean?,
	minimumVaultHeight: number?
): boolean
	if requireGrounded and humanoid.FloorMaterial == Enum.Material.Air then return false end

	local hitResult, isSwingBar = getAerialParkourHit(rootPart, moveDirection)
	if not hitResult or isSwingBar then return false end
	local vaultHeight = getVaultHeight(rootPart, hitResult)
	if minimumVaultHeight and vaultHeight + 0.08 < minimumVaultHeight then
		if state.debug then pushLog(`Vault too low: {math.floor(vaultHeight * 100) / 100}/{math.floor(minimumVaultHeight * 100) / 100}.`) end
		return false
	end

	if moveDirection.Magnitude > 0.1 then rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + moveDirection.Unit) end
	return startBotVault(rootPart, humanoid, hitResult)
end

local function getGroundDistance(rootPart: BasePart): number?
	raycastParams.FilterDescendantsInstances = getIgnoreList()

	local result = workspace:Raycast(rootPart.Position, Vector3.new(0, -24, 0), raycastParams)
	if not result then return nil end

	return (rootPart.Position - result.Position).Magnitude
end

local function updateBotTrampoline(bot: Model?, rootPart: BasePart, humanoid: Humanoid)
	raycastParams.FilterDescendantsInstances = getIgnoreList()

	local result = workspace:Raycast(rootPart.Position + Vector3.new(0, 0.2, 0), Vector3.new(0, -3.8, 0), raycastParams)
	if not result or not CollectionService:HasTag(result.Instance, "Trampoline") then return end

	local now = os.clock()
	if trampolineBounceTimes[result.Instance] and now - trampolineBounceTimes[result.Instance] <= 0.5 then return end
	trampolineBounceTimes[result.Instance] = now

	local bounceAmount = tonumber(result.Instance:GetAttribute("BounceAmount")) or Config.TRAMPOLINE_FALLBACK_BOUNCE_AMOUNT
	local rootVelocity = rootPart.AssemblyLinearVelocity
	if bot and bot:GetAttribute("Sliding") == true then
		bot:SetAttribute("Sliding", nil)
		humanoid.HipHeight = -0.1
		state.slideBoostInProgress = false
	end

	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	rootPart.AssemblyLinearVelocity = Vector3.new(rootVelocity.X, bounceAmount / 1.2, rootVelocity.Z)
	PlaySound("Trampoline", rootPart)
	addReward(rootPart.Position, rootPart.CFrame.LookVector, 10)

	if state.debug then pushLog(`Trampoline bounce: {math.floor((bounceAmount / 1.2) * 10) / 10} Y velocity.`) end
end

local function chooseSlideBoostTiming(): (number, number, string)
	local bestCancelDelay = state.slideBoostCancelDelay
	local bestJumpDelay = state.slideBoostJumpDelay
	local bestKey = `{bestCancelDelay}:{bestJumpDelay}`
	local bestScore = -math.huge
	local foundUntried = false

	for _, cancelDelay in { 0.5, 0.56, 0.62, 0.68, 0.36, 0.44 } do
		for _, jumpDelay in { 0.08, 0.12, 0.16, 0.2 } do
			local key = `{cancelDelay}:{jumpDelay}`
			local scoreInfo = state.slideBoostScores[key]
			if not scoreInfo then
				if not foundUntried and cancelDelay >= 0.5 then
					bestCancelDelay = cancelDelay
					bestJumpDelay = jumpDelay
					bestKey = key
					foundUntried = true
				end
				continue
			end

			local timingBias = if cancelDelay >= 0.5 then 1.2 else -2.4
			local score = scoreInfo.score + timingBias + math.min(4, scoreInfo.visits) * 0.05
			if not foundUntried and score > bestScore then
				bestScore = score
				bestCancelDelay = cancelDelay
				bestJumpDelay = jumpDelay
				bestKey = key
			end
		end
	end

	return bestCancelDelay, bestJumpDelay, bestKey
end

local function recordSlideBoostTiming(key: string, reward: number)
	local scoreInfo = state.slideBoostScores[key]
	if not scoreInfo then
		scoreInfo = {
			score = 0,
			visits = 0,
		}
		state.slideBoostScores[key] = scoreInfo
	end

	scoreInfo.visits += 1
	scoreInfo.score += (reward - scoreInfo.score) / math.max(1, scoreInfo.visits)

	if scoreInfo.score > 0 then
		local cancelText, jumpText = string.match(key, "([^:]+):([^:]+)")
		local cancelDelay = tonumber(cancelText)
		local jumpDelay = tonumber(jumpText)
		if cancelDelay and jumpDelay then
			state.slideBoostCancelDelay = cancelDelay
			state.slideBoostJumpDelay = jumpDelay
		end
	end
end

local function recordScore(dictionary: { [string]: DirectionScore }, key: string, reward: number)
	local scoreInfo = dictionary[key]
	if not scoreInfo then
		scoreInfo = {
			score = 0,
			visits = 0,
		}
		dictionary[key] = scoreInfo
	end

	scoreInfo.visits += 1
	scoreInfo.score += (reward - scoreInfo.score) / math.max(1, scoreInfo.visits)
end

local function routeAlreadyExistsNear(startPosition: Vector3, endPosition: Vector3, techKey: string): boolean
	for _, route in state.routes do
		local firstPoint = route.points[1]
		local lastPoint = route.points[#route.points]
		if not firstPoint or not lastPoint then continue end

		local sameStart = (firstPoint.position - startPosition).Magnitude < 10
		local sameEnd = (lastPoint.position - endPosition).Magnitude < 12
		local hasTech = false
		for _, point in route.points do
			if point.action == techKey then
				hasTech = true
				break
			end
		end

		if sameStart and sameEnd and hasTech then return true end
	end

	return false
end

local function promoteSelfTaughtRoute(candidate: SelfTaughtRouteCandidate)
	if candidate.successes < 3 then return end
	if routeAlreadyExistsNear(candidate.startPosition, candidate.endPosition, candidate.techKey) then return end

	local route: RouteInfo = {
		id = HttpService:GenerateGUID(false),
		name = `Learned {candidate.techKey} {#state.routes + 1}`,
		points = {
			{
				position = candidate.startPosition,
				action = "Move",
				partName = nil,
				studs = nil,
			},
			{
				position = candidate.techPosition,
				action = candidate.techKey,
				partName = nil,
				studs = math.floor(getFloorHeightDelta(candidate.startPosition, candidate.techPosition) * 10 + 0.5) / 10,
			},
			{
				position = candidate.endPosition,
				action = "Move",
				partName = nil,
				studs = nil,
			},
		},
		maxTime = math.clamp((candidate.endPosition - candidate.startPosition).Magnitude / 18 + 4, 6, 18),
		maxVaults = if string.find(candidate.techKey, "Vault") then 1 else 2,
		maxSwings = if candidate.techKey == "Swing" then 1 else 2,
		maxRolls = if string.find(candidate.techKey, "Roll") then 1 else 2,
		bestTime = nil,
		successes = candidate.successes,
		failures = candidate.failures,
	}

	table.insert(state.routes, route)
	state.editorSelectedRouteIndex = #state.routes
	state.editorSelectedPointIndex = 1
	refreshRouteMarkers()
	pushLog(`Learned route saved: {route.name}.`)
end

local function recordSelfTaughtRouteAttempt(attempt: TechAttemptInfo, endPosition: Vector3, reward: number)
	if state.activeRoute then return end
	if attempt.key == "JumpProbe" then return end

	local distanceGain = attempt.startDistance - (attempt.targetPosition - endPosition).Magnitude
	local heightGain = getFloorY(endPosition) - attempt.startHeight
	local useful = reward >= 8 and (distanceGain > 4 or heightGain > 2.5)
	if not useful then return end

	local startNodeId = nearestNodeId(attempt.startPosition, math.max(70, state.graphStep * 16)) or 0
	local endNodeId = nearestNodeId(endPosition, math.max(70, state.graphStep * 16)) or 0
	local key = `{startNodeId}>{endNodeId}:{attempt.key}`
	local candidate = state.selfTaughtRouteCandidates[key]
	if not candidate then
		local traveled = endPosition - attempt.startPosition
		local flatTraveled = Vector3.new(traveled.X, 0, traveled.Z)
		local techPosition = if flatTraveled.Magnitude > 0.1
			then attempt.startPosition + flatTraveled.Unit * math.min(8, flatTraveled.Magnitude * 0.55)
			else attempt.startPosition
		candidate = {
			key = key,
			techKey = attempt.key,
			startPosition = attempt.startPosition,
			techPosition = techPosition,
			endPosition = endPosition,
			successes = 0,
			failures = 0,
			bestReward = -math.huge,
			lastUsedTime = 0,
		}
		state.selfTaughtRouteCandidates[key] = candidate
	end

	candidate.successes += 1
	candidate.endPosition = endPosition
	candidate.bestReward = math.max(candidate.bestReward, reward)
	candidate.lastUsedTime = os.clock()
	if state.autoCreateRoutes then promoteSelfTaughtRoute(candidate) end
end

local function getRouteTechKey(position: Vector3, targetPosition: Vector3, techKey: string): string
	local startNodeId = nearestNodeId(position, math.max(70, state.graphStep * 16)) or 0
	local targetNodeId = nearestNodeId(targetPosition, math.max(70, state.graphStep * 16)) or 0
	return `{startNodeId}>{targetNodeId}:{techKey}`
end

local function getWallTechKey(position: Vector3, techKey: string): string
	local nodeId = nearestNodeId(position, math.max(55, state.graphStep * 12)) or 0
	return `wall:{nodeId}:{techKey}`
end

local function getWallTechScore(position: Vector3, techKey: string): number
	local scoreInfo = state.routeTechNotes[getWallTechKey(position, techKey)]
	return if scoreInfo then scoreInfo.score + math.min(scoreInfo.visits, 8) * 0.15 else 0
end

local function recordWallTechMemory(position: Vector3, techKey: string, reward: number)
	recordScore(state.routeTechNotes, getWallTechKey(position, techKey), reward)
	recordScore(state.techScores, techKey, reward * 0.35)
end

teachTechHint = function(actionName: string?)
	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		pushLog("Tech hint needs your character to be spawned.")
		return
	end

	if #state.graph == 0 then
		pushLog("Tech hint needs a graph first. Build Graph, then teach the spot.")
		return
	end

	local nodeId = nearestNodeId(rootPart.Position, math.max(55, state.graphStep * 12))
	if not nodeId then
		pushLog("Tech hint could not find a nearby graph node.")
		return
	end

	local taughtAction = BotTechHints.canonicalAction(actionName or state.editorSelectedAction)
	local heightDelta = getFloorHeightDelta(rootPart.Position, rootPart.Position + rootPart.CFrame.LookVector * 12)
	local runtimeTech = BotTechHints.runtimeTech(taughtAction, heightDelta)
	recordScore(state.routeTechNotes, BotTechHints.hintKey(nodeId, taughtAction), 16)
	recordScore(state.techScores, runtimeTech, 8)
	if taughtAction == "SlideBoost" then
		recordScore(state.techScores, "SlideVault", 8)
	elseif taughtAction == "Roll" then
		recordScore(state.techScores, "RollBoost", 7)
	end

	pushLog(`Taught tech hint: {taughtAction} near graph node {nodeId}.`)
end

teachClimbableWall = function()
	local position: Vector3? = nil
	local route = state.routes[state.editorSelectedRouteIndex]
	local point = route and route.points[state.editorSelectedPointIndex]
	if point then
		position = point.position
	else
		local character = localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then position = rootPart.Position end
	end

	if not position then
		pushLog("Climbable wall teach needs a selected node or your character.")
		return
	end
	if #state.graph == 0 then
		pushLog("Climbable wall teach needs a graph first.")
		return
	end

	local nodeId = nearestNodeId(position, math.max(55, state.graphStep * 12))
	if not nodeId then
		pushLog("No graph node found near that climbable wall.")
		return
	end

	recordScore(state.routeTechNotes, BotTechHints.hintKey(nodeId, "ClimbableWall"), 24)
	recordWallTechMemory(position, "SlideVault", 22)
	recordScore(state.techScores, "SlideVault", 12)
	recordScore(state.techScores, "SlideBoost", 10)
	state.editorSelectedAction = "SlideBoost"
	pushLog(`Taught climbable slide-boost wall near graph node {nodeId}.`)
end

local function learnFromChasedPlayer(rootPart: BasePart, targetRoot: BasePart, predictedTargetPosition: Vector3, reward: number)
	local targetCharacter = targetRoot:FindFirstAncestorOfClass("Model")
	local targetPlayer = if targetCharacter then Players:GetPlayerFromCharacter(targetCharacter) else nil
	local playerWeight = BotRankBias.weightForPlayer(targetPlayer)
	local weightedReward = reward * playerWeight
	local recentAction = state.actionInfo.lastParkourName
	if recentAction ~= "None" and os.clock() - state.actionInfo.lastParkourTime < 1.15 then
		local routeKey = getRouteTechKey(targetRoot.Position, predictedTargetPosition, recentAction)
		recordScore(state.routeTechNotes, routeKey, math.clamp(weightedReward + 5, -12, 20))
		recordScore(state.techScores, recentAction, math.clamp(weightedReward * 0.45 + 3, -8, 16))

		local distance = (targetRoot.Position - rootPart.Position).Magnitude
		local features = BotPolicyNetwork.featuresForChase(
			rootPart.Position,
			targetRoot.Position,
			targetRoot.AssemblyLinearVelocity,
			state.lastDistance,
			distance,
			getFloorHeightDelta(rootPart.Position, targetRoot.Position)
		)
		BotPolicyNetwork.reward(state.policyWeights, recentAction, features, reward, playerWeight)
	end

	if targetPlayer then
		recordScore(state.playerModelScores, tostring(targetPlayer.UserId), math.clamp(weightedReward, -12, 18))
	end

	local targetVelocity = targetRoot.AssemblyLinearVelocity
	local flatVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)
	if flatVelocity.Magnitude > 8 then
		local botToTarget = targetRoot.Position - rootPart.Position
		local flatBotToTarget = Vector3.new(botToTarget.X, 0, botToTarget.Z)
		if flatBotToTarget.Magnitude > 0.1 then
			local side = if flatBotToTarget.Unit:Cross(flatVelocity.Unit).Y >= 0 then "left" else "right"
			local distanceBucket = if flatBotToTarget.Magnitude < 45 then "near" elseif flatBotToTarget.Magnitude < 85 then "mid" else "far"
			recordScore(state.cutoffScores, `playerRoute:{distanceBucket}:{side}`, reward)
		end
	end
end

local function isGuidedTechAction(actionName: string): boolean
	return string.find(actionName, "Vault") ~= nil
		or string.find(actionName, "Swing") ~= nil
		or string.find(actionName, "Roll") ~= nil
		or string.find(actionName, "Slide") ~= nil
		or string.find(actionName, "Jump") ~= nil
end

local function guidedRouteIsUseful(route: RouteInfo): boolean
	if #route.points < 3 then return false end

	local startPoint = route.points[1]
	local endPoint = route.points[#route.points]
	if not startPoint or not endPoint then return false end
	if (endPoint.position - startPoint.position).Magnitude < 18 then return false end

	local techNodes = 0
	for _, point in route.points do
		if isGuidedTechAction(point.action) then
			techNodes += 1
		end
	end

	return techNodes >= 1
end

local function discardGuidedRoute(route: RouteInfo, reason: string)
	local routeIndex = table.find(state.routes, route)
	if routeIndex then
		table.remove(state.routes, routeIndex)
		state.editorSelectedRouteIndex = math.clamp(routeIndex, 1, math.max(1, #state.routes))
		state.editorSelectedPointIndex = 1
	end
	if state.guidedTraining then
		if state.debug then pushLog(`Discarded guided route: {reason}.`) end
		return
	end
	if state.debug then pushLog(`Discarded guided route: {reason}.`) end
end

local function analyzeGuidedRoute(route: RouteInfo)
	if #route.points < 2 then return end

	local startPoint = route.points[1]
	local endPoint = route.points[#route.points]
	local slidePoint: RoutePointInfo? = nil
	local slideCancelPoint: RoutePointInfo? = nil
	for index, point in route.points do
		if point.action == "Slide" then
			slidePoint = point
			slideCancelPoint = nil
		elseif point.action == "SlideCancel" and slidePoint then
			slideCancelPoint = point
		elseif point.action == "Jump" and slidePoint and slideCancelPoint then
			local routeKey = getRouteTechKey(slidePoint.position, point.position, "SlideBoost")
			local progress = (endPoint.position - slidePoint.position).Magnitude - (endPoint.position - point.position).Magnitude
			local heightGain = getFloorY(point.position) - getFloorY(slidePoint.position)
			local reward = 8 + math.max(0, progress) * 0.28 + math.max(0, heightGain) * 0.75
			recordScore(state.routeTechNotes, routeKey, reward)
			recordScore(state.techScores, "SlideBoost", reward)
			recordScore(state.techScores, "SlideVault", reward * 0.75)
			if state.debug then pushLog("Guided route recognized SlideBoost sequence.") end
			slidePoint = nil
			slideCancelPoint = nil
			if index % 4 == 0 then task.wait() end
			continue
		end

		if not isGuidedTechAction(point.action) then continue end

		local previousPoint = route.points[math.max(1, index - 1)]
		local nextPoint = route.points[math.min(#route.points, index + 1)]
		local routeKey = getRouteTechKey(previousPoint.position, nextPoint.position, point.action)
		local progress = (endPoint.position - previousPoint.position).Magnitude - (endPoint.position - point.position).Magnitude
		local heightGain = getFloorY(point.position) - getFloorY(startPoint.position)
		local reward = 4 + math.max(0, progress) * 0.35 + math.max(0, heightGain) * 0.45
		recordScore(state.routeTechNotes, routeKey, reward)
		recordScore(state.techScores, point.action, reward * 0.65)
		if index % 4 == 0 then task.wait() end
	end
end

local function finalizeGuidedRoute(timedOut: boolean): boolean
	if not state.playerRouteRecording or not routeEditor then return false end

	routeEditor.stopRouteRecording()
	local route = routeEditor.getCurrentRoute and routeEditor.getCurrentRoute()
	if not route then return false end

	route.name = `Guided Run {state.guidedDestinationIndex}`
	route.successes = (route.successes or 0) + (if timedOut then 0 else 1)
	route.failures = (route.failures or 0) + (if timedOut then 1 else 0)

	if timedOut or not guidedRouteIsUseful(route) then
		discardGuidedRoute(route, if timedOut then "timed out" else "no useful movement")
		return false
	end

	discardGuidedRoute(route, "stored as tech memory")
	task.defer(function()
		analyzeGuidedRoute(route)
	end)
	return true
end

local function startNextGuidedDestination(rootPart: BasePart): boolean
	if not routeEditor then return false end

	local destination = chooseGuidedDestination(rootPart)
	if not destination then
		local now = os.clock()
		if now - state.lastGuidedNoDestinationLogTime > 2.5 then
			state.lastGuidedNoDestinationLogTime = now
			pushLog(`Guided training could not find a safe point yet. Graph nodes: {#state.graph}.`)
		end
		return false
	end

	state.guidedDestination = destination
	table.insert(state.guidedRecentDestinations, destination)
	while #state.guidedRecentDestinations > 8 do
		table.remove(state.guidedRecentDestinations, 1)
	end
	state.guidedDestinationIndex += 1
	state.guidedDestinationStartTime = os.clock()
	state.editorOpen = false
	state.editorCompact = true
	routeEditor.beginPlayerRouteRecording()
	refreshGuidedMarker()
	refreshControlButtons()
	pushLog(`Guided target #{state.guidedDestinationIndex}: run to the yellow marker.`)
	return true
end

local function stopGuidedTraining()
	if state.guidedTraining and state.playerRouteRecording then finalizeGuidedRoute(false) end

	state.guidedTraining = false
	state.guidedDestination = nil
	state.guidedTransitionBusy = false
	if guidedMarkerFolder then guidedMarkerFolder:ClearAllChildren() end
	refreshControlButtons()
	pushLog("Guided training stopped.")
end

local function startGuidedTraining()
	if state.guidedTraining then
		stopGuidedTraining()
		return
	end

	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		pushLog("Guided training needs your character loaded.")
		return
	end

	if state.recordingRoute and routeEditor then routeEditor.stopRouteRecording() end
	state.guidedTraining = true
	state.guidedDestinationIndex = 0
	state.guidedCompletions = 0
	state.guidedTransitionBusy = false
	table.clear(state.guidedRecentDestinations)
	startNextGuidedDestination(rootPart)
end

local function updateGuidedTraining()
	if not state.guidedTraining then return end
	if state.guidedTransitionBusy then return end

	local character = localPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then return end

	if not state.guidedDestination then
		startNextGuidedDestination(rootPart)
		return
	end

	local now = os.clock()
	if now - state.lastGuidedSampleTime >= 0.12 then
		state.lastGuidedSampleTime = now
		local recentAction = now - state.actionInfo.lastParkourTime < 0.85
		recordPlayerRouteSample(
			rootPart,
			if recentAction and state.actionInfo.lastParkourName ~= "None" then state.actionInfo.lastParkourName else "Move",
			false
		)
	end

	local distance = (rootPart.Position - state.guidedDestination).Magnitude
	local timedOut = now - state.guidedDestinationStartTime > 45
	if distance > 8 and not timedOut then return end

	state.guidedTransitionBusy = true
	local rootForNext = rootPart
	task.defer(function()
		local saved = finalizeGuidedRoute(timedOut)
		state.guidedCompletions += if saved then 1 else 0
		task.wait()

		pushLog(
			if timedOut
				then "Guided run timed out; picking a new target."
				elseif saved then `Guided tech memory stored. Completed {state.guidedCompletions}.`
				else "Guided run had no successful tech; picking a new target."
		)
		task.wait()

		state.guidedDestination = nil
		if state.guidedTraining and rootForNext.Parent then
			startNextGuidedDestination(rootForNext)
		end
		state.guidedTransitionBusy = false
	end)
end

local function finishTechAttempt(rootPart: BasePart, targetPosition: Vector3)
	local attempt = state.activeTechAttempt
	if not attempt then return end
	if os.clock() - attempt.startTime < Config.TECH_ATTEMPT_SCORE_SECONDS then return end

	local endDistance = (targetPosition - rootPart.Position).Magnitude
	local distanceGain = attempt.startDistance - endDistance
	local heightGain = rootPart.Position.Y - attempt.startHeight
	local moved = (rootPart.Position - attempt.startPosition).Magnitude
	local reward = distanceGain * 1.3 + heightGain * 1.8 + math.clamp(moved - 3, -4, 8)

	recordScore(state.techScores, attempt.key, reward)
	recordScore(state.routeTechNotes, attempt.routeKey, reward)
	if attempt.geometryKey then recordScore(state.geometryScores, attempt.geometryKey, reward) end
	if attempt.key == "SlideVault" or attempt.key == "TrampVault" then
		recordWallTechMemory(attempt.startPosition, attempt.key, reward)
	end
	addReward(rootPart.Position, attempt.moveDirection, reward * 0.45)
	recordSelfTaughtRouteAttempt(attempt, rootPart.Position, reward)
	state.activeTechAttempt = nil

	if state.debug then
		pushLog(
			`Tech note {attempt.key}: reward {math.floor(reward * 10) / 10}, dist {math.floor(distanceGain * 10) / 10}, height {math.floor(
				heightGain * 10
			) / 10}.`
		)
	end
end

local function startTechAttempt(rootPart: BasePart, targetPosition: Vector3, moveDirection: Vector3, techKey: string, geometryKey: string?)
	state.activeTechAttempt = {
		key = techKey,
		routeKey = getRouteTechKey(rootPart.Position, targetPosition, techKey),
		geometryKey = geometryKey,
		startPosition = rootPart.Position,
		targetPosition = targetPosition,
		startDistance = (targetPosition - rootPart.Position).Magnitude,
		startHeight = getFloorY(rootPart.Position),
		startTime = os.clock(),
		moveDirection = moveDirection,
	}
	state.lastTechTryTime = os.clock()
end

local function chooseTechExperiment(rootPart: BasePart, targetPosition: Vector3): string
	local heightDelta = getFloorHeightDelta(rootPart.Position, targetPosition)
	local approachDistance = getApproachObstacleDistance(rootPart, targetPosition - rootPart.Position, 18)
	local slideBoostSetup = heightDelta >= Config.SLIDE_BOOST_MIN_HEIGHT_STUDS - 1.25
		and heightDelta <= Config.SLIDE_BOOST_MAX_HEIGHT_STUDS + 0.65
		and approachDistance ~= nil
		and approachDistance >= 4.5
		and approachDistance <= 17
	local hintedTechKey = BotTechHints.findBestRuntimeTech(state, nearestNodeId, rootPart.Position, math.max(42, state.graphStep * 10), heightDelta)
	if hintedTechKey then return hintedTechKey end

	local techs
		if heightDelta <= Config.GROUND_VAULT_REACH_STUDS then
			techs = { "Vault", "TrampVault", "StrafeJumpVault", "VaultProbe", "JumpProbe" }
		elseif heightDelta <= Config.HIGH_VAULT_MAX_STUDS then
			techs = if slideBoostSetup
				then { "SlideVault", "TrampVault", "TimedHighVault", "JumpVault", "VaultProbe" }
				else { "TrampVault", "TimedHighVault", "JumpVault", "Vault", "VaultProbe" }
		elseif heightDelta >= Config.SLIDE_BOOST_MIN_HEIGHT_STUDS - 0.85 and heightDelta <= Config.SLIDE_BOOST_MAX_HEIGHT_STUDS + 0.35 then
			techs = { "SlideVault", "TrampVault", "TimedHighVault", "RollBoostVault", "JumpVault" }
		elseif heightDelta <= Config.ROLL_BOOST_MAX_HEIGHT_STUDS then
			techs = if slideBoostSetup
				then { "SlideVault", "RollBoost", "RollBoostVault", "TimedHighVault", "JumpVault" }
				else { "RollBoost", "RollBoostVault", "TimedHighVault", "JumpVault" }
		else
			techs = { "TrampVault", "StrafeJumpVault", "VaultProbe", "JumpProbe" }
	end

	for _, techKey in techs do
		if not state.techScores[techKey] then return techKey end
	end

	local bestKey = techs[1]
	local bestScore = -math.huge
	local policyFeatures = BotPolicyNetwork.featuresForTech(rootPart.Position, targetPosition, heightDelta, approachDistance)
	for _, techKey in techs do
		local scoreInfo = state.techScores[techKey]
		local routeInfo = state.routeTechNotes[getRouteTechKey(rootPart.Position, targetPosition, techKey)]
		local score = if scoreInfo then scoreInfo.score else 0
		if routeInfo then
			score += routeInfo.score * 0.85
		end
		score += BotPolicyNetwork.score(state.policyWeights, techKey, policyFeatures) * 0.55
		score -= math.min(if scoreInfo then scoreInfo.visits else 0, 8) * 0.08

		if score > bestScore then
			bestScore = score
			bestKey = techKey
		end
	end

	if bestScore < 1 then
		state.techExperimentCursor += 1
		return techs[((state.techExperimentCursor - 1) % #techs) + 1]
	end

	return bestKey
end

local function finishSlideBoost(
	rootPart: BasePart,
	humanoid: Humanoid,
	targetPosition: Vector3,
	moveDirection: Vector3,
	timingKey: string,
	jumpDelay: number
): boolean
	if not state.slideBoostInProgress then return false end
	if moveDirection.Magnitude < 0.2 then return false end

	local bot = rootPart:FindFirstAncestorOfClass("Model")
	if bot and bot:GetAttribute("Sliding") ~= true then return false end

	if bot then bot:SetAttribute("Sliding", nil) end
	local slideSound = rootPart:FindFirstChild("Slide")
	if slideSound and slideSound:IsA("Sound") then slideSound:Pause() end
	humanoid.HipHeight = 0
	state.lastSlideCancelTime = os.clock()

	task.delay(jumpDelay, function()
		if not rootPart.Parent then
			state.slideBoostInProgress = false
			return
		end

		local direction = if moveDirection.Magnitude > 0.2 then moveDirection.Unit else rootPart.CFrame.LookVector
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
		if not tryBotJump(rootPart, humanoid, 35, direction * 10, "Jump1", true) then
			state.slideBoostInProgress = false
			return
		end

		task.delay(0.16, function()
			if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, direction, nil, 2.25) end
		end)
		task.delay(0.34, function()
			if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, direction, nil, 2.25) end
		end)
		task.delay(0.45, function()
			if not rootPart.Parent then
				state.slideBoostInProgress = false
				return
			end

			local verticalGain = getFloorY(rootPart.Position) - state.slideBoostStartY
			local targetGain = getFloorHeightDelta(rootPart.Position, targetPosition)
			local reward = verticalGain * 3 + math.max(0, rootPart.AssemblyLinearVelocity.Y) * 0.1
			if targetGain > 0 then
				reward += math.clamp(verticalGain / math.max(targetGain, 1), 0, 1.35) * 8
			end
			recordSlideBoostTiming(timingKey, reward)
			recordScore(state.routeTechNotes, getRouteTechKey(rootPart.Position, targetPosition, "SlideVault"), reward)
			addReward(rootPart.Position, direction, 6 + reward)
			state.slideBoostInProgress = false

			if state.debug then pushLog(`Slideboost reward {math.floor(reward * 10) / 10}, gain {math.floor(verticalGain * 10) / 10}.`) end
		end)
	end)

	return true
end

local function trySlideBoost(
	rootPart: BasePart,
	humanoid: Humanoid,
	targetPosition: Vector3,
	moveDirection: Vector3,
	waitForRouteCancel: boolean?
): boolean
	local now = os.clock()
	if now - state.lastSlideTime < Config.BOT_SLIDE_BOOST_COOLDOWN_SECONDS then return false end
	if state.slideBoostInProgress then return false end
	if humanoid.FloorMaterial == Enum.Material.Air then return false end
	if moveDirection.Magnitude < 0.2 then return false end

	local heightDelta = getFloorHeightDelta(rootPart.Position, targetPosition)
	local wantsHeight = heightDelta >= Config.SLIDE_BOOST_MIN_HEIGHT_STUDS - 1.25 and heightDelta <= Config.SLIDE_BOOST_MAX_HEIGHT_STUDS + 0.65
	local approachDistance = getApproachObstacleDistance(rootPart, moveDirection, 18)
	if not wantsHeight then return false end
	if not approachDistance or approachDistance < 4.25 or approachDistance > 17 then return false end

	state.lastSlideTime = now
	state.slideBoostInProgress = true

	local bot = rootPart:FindFirstAncestorOfClass("Model")
	local direction = moveDirection.Unit
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
	if bot then bot:SetAttribute("Sliding", true) end
	humanoid.HipHeight = 0.2
	humanoid.WalkSpeed = math.max(humanoid.WalkSpeed, 34)
	BotRuntime.playActionAnimation(bot, "SlideEnter")
	local slideSound = rootPart:FindFirstChild("Slide")
	if not slideSound then
		local sounds = ReplicatedStorage.Assets:FindFirstChild("Sounds")
		local slideTemplate = sounds and sounds:FindFirstChild("Slide")
		if slideTemplate and slideTemplate:IsA("Sound") then
			slideSound = slideTemplate:Clone()
			slideSound.Parent = rootPart
		end
	end
	if slideSound and slideSound:IsA("Sound") then
		slideSound.Volume = 0.3
		slideSound:Resume()
	end

	local cancelDelay, jumpDelay, timingKey = chooseSlideBoostTiming()
	state.slideBoostKey = timingKey
	state.slideBoostStartY = getFloorY(rootPart.Position)

	if not waitForRouteCancel then
		task.delay(cancelDelay, function()
			if not rootPart.Parent then
				if bot then bot:SetAttribute("Sliding", nil) end
				state.slideBoostInProgress = false
				return
			end
			finishSlideBoost(rootPart, humanoid, targetPosition, direction, timingKey, jumpDelay)
		end)
	end

	return true
end

local function tryRollBoostJump(rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3, moveDirection: Vector3): boolean
	if moveDirection.Magnitude < 0.2 then return false end
	if humanoid.FloorMaterial == Enum.Material.Air then return false end

	local rollAge = os.clock() - state.lastRollActionTime
	if rollAge < 0.06 or rollAge > 0.22 then return false end

	local heightDelta = getFloorHeightDelta(rootPart.Position, targetPosition)
	if heightDelta < 5 or heightDelta > Config.ROLL_BOOST_MAX_HEIGHT_STUDS + 0.5 then return false end

	local jumped = tryBotJump(rootPart, humanoid, 42, moveDirection.Unit * 13, "Jump2")
	if not jumped then return false end

	recordScore(state.techScores, "RollBoost", 8 + heightDelta * 0.65)
	addReward(rootPart.Position, moveDirection, 8 + heightDelta * 0.35)
	if state.debug then pushLog(`Rollboost jump: target height {math.floor(heightDelta * 10) / 10}.`) end
	return true
end

local function tryRollSetupDrop(rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3, moveDirection: Vector3): boolean
	if moveDirection.Magnitude < 0.2 then return false end
	if humanoid.FloorMaterial == Enum.Material.Air then return false end
	if state.slideBoostInProgress then return false end

	local now = os.clock()
	if now - state.lastRollSetupTime < 1.1 then return false end
	if now - state.lastBasicJumpTime < Config.BASIC_JUMP_COOLDOWN_SECONDS then return false end

	local currentFloorY = getFloorY(rootPart.Position)
	local bestDrop = 0
	local bestDistance = 0
	for _, distance in { 5, 7.5, 10, 13 } do
		local probePosition = rootPart.Position + moveDirection.Unit * distance
		local floorHit = getFloorHit(probePosition, 5, 28)
		if not floorHit then continue end

		local drop = currentFloorY - floorHit.Position.Y
		if drop > bestDrop then
			bestDrop = drop
			bestDistance = distance
		end
	end

	if bestDrop < 7 or bestDrop > 18 then return false end

	local targetHeightAfterDrop = getFloorY(targetPosition) - (currentFloorY - bestDrop)
	local wantsRollBoost = targetHeightAfterDrop >= 3.5 and targetHeightAfterDrop <= Config.ROLL_BOOST_MAX_HEIGHT_STUDS + 1
	local targetDirection = targetPosition - rootPart.Position
	local flatTargetDirection = Vector3.new(targetDirection.X, 0, targetDirection.Z)
	local targetAligned = flatTargetDirection.Magnitude > 0.1 and moveDirection.Unit:Dot(flatTargetDirection.Unit) > 0.15
	if not wantsRollBoost and not targetAligned then return false end

	local clearDistance = getClearDistance(rootPart, moveDirection)
	if clearDistance < math.min(4.5, bestDistance - 1) then return false end

	state.lastRollSetupTime = now
	local jumped = tryBotJump(rootPart, humanoid, 27, moveDirection.Unit * 12, "Jump2")
	if not jumped then return false end

	recordScore(state.techScores, "RollSetupDrop", 5 + bestDrop * 0.45)
	addReward(rootPart.Position, moveDirection, 4 + bestDrop * 0.25)
	if state.debug then pushLog(`Roll setup drop: {math.floor(bestDrop * 10) / 10} studs ahead.`) end
	return true
end

local function tryTrampVault(rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3, moveDirection: Vector3, useExistingAttempt: boolean?): boolean
	if not state.autoVault then return false end
	if state.activeTechAttempt and not useExistingAttempt then return false end
	if humanoid.FloorMaterial == Enum.Material.Air then return false end
	if moveDirection.Magnitude < 0.2 then return false end

	local now = os.clock()
	if now - state.lastTrampVaultTime < Config.BOT_TRAMP_VAULT_COOLDOWN_SECONDS then return false end
	if now - state.lastBasicJumpTime < Config.BASIC_JUMP_COOLDOWN_SECONDS * 0.75 then return false end

	local heightDelta = getFloorHeightDelta(rootPart.Position, targetPosition)
	local approachDistance = getApproachObstacleDistance(rootPart, moveDirection, 14)
	if not approachDistance or approachDistance < 2.8 or approachDistance > 11.5 then return false end
	if heightDelta < 4 or heightDelta > Config.HIGH_VAULT_MAX_STUDS + 1.6 then return false end

	local direction = moveDirection.Unit
	local strafeSign = if state.techExperimentCursor % 2 == 0 then 1 else -1
	state.techExperimentCursor += 1
	local strafeDirection = rotateFlatDirection(direction, math.rad(42 * strafeSign))
	state.lastTrampVaultTime = now
	if not useExistingAttempt then startTechAttempt(rootPart, targetPosition, direction, "TrampVault", nil) end

	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)
	local jumped = tryBotJump(rootPart, humanoid, 31, strafeDirection * 10 + direction * 4, "Jump2")
	if not jumped then
		state.activeTechAttempt = nil
		return false
	end

	task.delay(0.1, function()
		if rootPart.Parent then rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction) end
	end)
	task.delay(0.17, function()
		if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, direction, nil, 1.6) end
	end)
	task.delay(0.3, function()
		if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, direction, nil, 1.6) end
	end)

	recordScore(state.techScores, "TrampVault", 5 + heightDelta * 0.35)
	addReward(rootPart.Position, direction, 4 + heightDelta * 0.2)
	return true
end

local function tryStuckClimbTech(rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3, moveDirection: Vector3, stuckSeconds: number): boolean
	if stuckSeconds < 0.35 then return false end
	if state.slideBoostInProgress or state.activeTechAttempt then return false end
	if humanoid.FloorMaterial == Enum.Material.Air then return false end
	if moveDirection.Magnitude < 0.2 then return false end

	local bestCandidate: LocalVaultInfo? = nil
	local bestScore = -math.huge
	for _, candidate in getCachedLocalVaults(rootPart, targetPosition) do
		local alignment = candidate.direction:Dot(moveDirection.Unit)
		if alignment < -0.05 then continue end

		local wallScore = getWallTechScore(candidate.position, candidate.techKey)
		if wallScore < -7 then continue end
		local score = alignment * 5
			- math.abs(candidate.approachDistance - 8.5) * 0.25
			+ math.max(0, candidate.heightDelta) * 0.45
			+ wallScore * 0.8
		if candidate.techKey == "SlideVault" then score += 6 end
		if candidate.heightDelta > Config.SLIDE_BOOST_MAX_HEIGHT_STUDS + 1.5 then score -= 8 end
		if score > bestScore then
			bestScore = score
			bestCandidate = candidate
		end
	end

	if bestCandidate then
		if bestCandidate.techKey == "SlideVault" and trySlideBoost(rootPart, humanoid, bestCandidate.position, bestCandidate.direction) then
			startTechAttempt(rootPart, bestCandidate.position, bestCandidate.direction, "SlideVault", bestCandidate.key)
			recordWallTechMemory(bestCandidate.position, "SlideVault", 3)
			return true
		end

		if bestCandidate.heightDelta <= Config.HIGH_VAULT_MAX_STUDS + 1.6 and tryTrampVault(rootPart, humanoid, bestCandidate.position, bestCandidate.direction) then
			recordScore(state.geometryScores, bestCandidate.key, 6)
			recordWallTechMemory(bestCandidate.position, "TrampVault", 4)
			return true
		end

		recordWallTechMemory(bestCandidate.position, bestCandidate.techKey, -8)
	end

	local triedTramp = tryTrampVault(rootPart, humanoid, targetPosition, moveDirection)
	if not triedTramp and stuckSeconds > 0.8 and getClearDistance(rootPart, moveDirection) < 3.4 then
		recordWallTechMemory(rootPart.Position + moveDirection.Unit * 5, "SlideVault", -6)
		recordWallTechMemory(rootPart.Position + moveDirection.Unit * 5, "TrampVault", -5)
		state.graphMoveTarget = nil
		state.graphMoveTech = nil
		state.runnerGraphMoveTarget = nil
		state.runnerGraphMoveTech = nil
		state.lastGraphDecisionTime = 0
		state.runnerLastGraphDecisionTime = 0
	end
	return triedTramp
end

local function tryLocalGeometryVault(rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3, moveDirection: Vector3): boolean
	if not state.autoVault then return false end
	if state.activeTechAttempt then return false end
	if moveDirection.Magnitude < 0.2 then return false end
	if humanoid.FloorMaterial == Enum.Material.Air then return false end

	local now = os.clock()
	if now - state.lastTechTryTime < Config.TECH_EXPERIMENT_COOLDOWN_SECONDS * 0.72 then return false end

	local bestCandidate: LocalVaultInfo? = nil
	local bestScore = -math.huge
	local currentDistance = (targetPosition - rootPart.Position).Magnitude
	for _, candidate in getCachedLocalVaults(rootPart, targetPosition) do
		local alignment = candidate.direction:Dot(moveDirection.Unit)
		if alignment < -0.15 then continue end

		local distanceAfterVault = (targetPosition - candidate.position).Magnitude
		local progress = currentDistance - distanceAfterVault
		local rollSetupBonus = 0
		if candidate.heightDelta >= 5.5 and candidate.heightDelta <= Config.ROLL_BOOST_MAX_HEIGHT_STUDS then
			rollSetupBonus = candidate.heightDelta * 0.7 * state.learnParams.verticalRollWeight
		end

		local scoreInfo = state.geometryScores[candidate.key]
		local learnedScore = if scoreInfo then scoreInfo.score else 0
		local approachPenalty = math.abs(candidate.approachDistance - 7.5) * 0.25
		local score = (progress * 1.15 * state.learnParams.progressWeight + alignment * 6 + rollSetupBonus + learnedScore * 1.1 - approachPenalty)
			* state.learnParams.localVaultWeight
		if candidate.techKey == "SlideVault" then
			score += 2 * state.learnParams.localVaultWeight
		end

		if score > bestScore then
			bestScore = score
			bestCandidate = candidate
		end
	end

	if not bestCandidate or bestScore < 4 / math.max(state.learnParams.localVaultWeight, 0.2) then return false end

	startTechAttempt(rootPart, targetPosition, moveDirection, bestCandidate.techKey, bestCandidate.key)
	if bestCandidate.techKey == "Vault" then
		if tryValidatedBotVault(rootPart, humanoid, bestCandidate.direction, true) then return true end
	elseif bestCandidate.techKey == "TimedHighVault" then
		local jumped = tryBotJump(rootPart, humanoid, 35, bestCandidate.direction * 6, "Jump1")
		if jumped then
			task.delay(0.18, function()
				if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, bestCandidate.direction, nil, 2.35) end
			end)
			task.delay(0.32, function()
				if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, bestCandidate.direction, nil, 2.35) end
			end)
			return true
		end
	elseif bestCandidate.techKey == "SlideVault" then
		if trySlideBoost(rootPart, humanoid, bestCandidate.position, bestCandidate.direction) then return true end
	end

	recordScore(state.geometryScores, bestCandidate.key, -5)
	state.activeTechAttempt = nil
	return false
end

local function tryExperimentalTech(rootPart: BasePart, humanoid: Humanoid, targetPosition: Vector3, moveDirection: Vector3)
	if not state.autoVault then return end
	if state.activeTechAttempt then return end
	if moveDirection.Magnitude < 0.2 then return end

	local now = os.clock()
	if now - state.lastTechTryTime < Config.TECH_EXPERIMENT_COOLDOWN_SECONDS then return end

	local heightDelta = getFloorHeightDelta(rootPart.Position, targetPosition)
	local clearDistance = getClearDistance(rootPart, moveDirection)
	local isStuck = state.stuckSeconds > 0.45
	local approachDistance = getApproachObstacleDistance(rootPart, moveDirection, 18)
	local slideBoostSetup = heightDelta >= Config.SLIDE_BOOST_MIN_HEIGHT_STUDS - 1.25
		and heightDelta <= Config.SLIDE_BOOST_MAX_HEIGHT_STUDS + 0.65
		and approachDistance ~= nil
		and approachDistance >= 4.25
		and approachDistance <= 17
	local wantsClimb = heightDelta > 2.5 or clearDistance < 4 or slideBoostSetup
	local hintedTechKey = BotTechHints.findBestRuntimeTech(state, nearestNodeId, rootPart.Position, math.max(42, state.graphStep * 10), heightDelta)
	if not isStuck and not wantsClimb and not hintedTechKey then return end

	local vaultDirection, scannedTechKey, geometryKey = scanVaultCandidate(rootPart, targetPosition, moveDirection)
	local executionDirection = vaultDirection or moveDirection
	local techKey = scannedTechKey or hintedTechKey or chooseTechExperiment(rootPart, targetPosition)
	startTechAttempt(rootPart, targetPosition, moveDirection, techKey, geometryKey)

	if techKey == "Vault" or techKey == "VaultProbe" then
		if not tryValidatedBotVault(rootPart, humanoid, executionDirection, true) then tryAerialParkour(rootPart, humanoid, moveDirection) end
	elseif techKey == "TimedHighVault" or techKey == "JumpVault" then
		tryBotJump(rootPart, humanoid, if techKey == "TimedHighVault" then 35 else 31, moveDirection.Unit * 5, "Jump1")

		task.delay(0.12, function()
			if rootPart.Parent and humanoid.Parent then tryAerialParkour(rootPart, humanoid, moveDirection) end
		end)
		task.delay(0.26, function()
			if rootPart.Parent and humanoid.Parent then
				if not tryValidatedBotVault(rootPart, humanoid, executionDirection) then tryAerialParkour(rootPart, humanoid, moveDirection) end
			end
		end)
	elseif techKey == "SlideVault" then
		local startedSlide = trySlideBoost(rootPart, humanoid, targetPosition, moveDirection)
		if not startedSlide then tryBotJump(rootPart, humanoid, 31, moveDirection.Unit * 4, "Jump1") end

		task.delay(0.36, function()
			if rootPart.Parent and humanoid.Parent then tryAerialParkour(rootPart, humanoid, moveDirection) end
		end)
		task.delay(0.56, function()
			if rootPart.Parent and humanoid.Parent then
				if not tryValidatedBotVault(rootPart, humanoid, executionDirection) then tryAerialParkour(rootPart, humanoid, moveDirection) end
			end
		end)
	elseif techKey == "RollBoost" or techKey == "RollBoostVault" then
		if os.clock() - state.lastRollActionTime > 0.22 then
			state.activeTechAttempt = nil
			return
		end

		local jumped = tryBotJump(rootPart, humanoid, 42, moveDirection.Unit * 13, "Jump2")
		if not jumped then
			state.activeTechAttempt = nil
			return
		end

		task.delay(0.18, function()
			if rootPart.Parent and humanoid.Parent and techKey == "RollBoostVault" then
				if not tryValidatedBotVault(rootPart, humanoid, executionDirection) then tryAerialParkour(rootPart, humanoid, moveDirection) end
			end
		end)
		elseif techKey == "StrafeJumpVault" then
			local strafeDirection = rotateFlatDirection(moveDirection.Unit, math.rad(if state.techExperimentCursor % 2 == 0 then 24 else -24))
			tryBotJump(rootPart, humanoid, 29, strafeDirection * 9, "Jump2")

			task.delay(0.16, function()
				if rootPart.Parent and humanoid.Parent then tryAerialParkour(rootPart, humanoid, moveDirection) end
			end)
		elseif techKey == "TrampVault" then
			if not tryTrampVault(rootPart, humanoid, targetPosition, moveDirection, true) then
				state.activeTechAttempt = nil
				tryBotJump(rootPart, humanoid, 29, rotateFlatDirection(moveDirection.Unit, math.rad(38)) * 8, "Jump2")
			end
		elseif techKey == "JumpProbe" then
		tryBotJump(rootPart, humanoid, 28, moveDirection.Unit * 3, "Jump1")
	else
		tryAerialParkour(rootPart, humanoid, moveDirection)
	end

	if state.debug then pushLog(`Trying tech: {techKey}.`) end
end

local function updateBotRoll(rootPart: BasePart, humanoid: Humanoid, moveDirection: Vector3)
	local bot = rootPart:FindFirstAncestorOfClass("Model")
	if not bot then return end

	local floorMaterial = humanoid.FloorMaterial
	local airborne = floorMaterial == Enum.Material.Air
	local previousAirborne = (botRollFloorMaterials[bot] or state.lastFloorMaterial) == Enum.Material.Air
	local velocity = rootPart.AssemblyLinearVelocity

	if airborne and velocity.Y < -40 and not botRollPressTimes[bot] then
		local groundDistance = getGroundDistance(rootPart)
		if groundDistance and groundDistance < math.clamp(-velocity.Y * 0.16, 6, 16) then
			botRollPressTimes[bot] = os.clock()
			if state.debug then pushLog(`Roll prepared from {math.floor(-velocity.Y)} fall speed.`) end
		end
	end
	if airborne then botRollFallVelocities[bot] = math.min(botRollFallVelocities[bot] or 0, velocity.Y) end

	if previousAirborne and not airborne then
		local rollPressTime = botRollPressTimes[bot]
		local fallVelocity = botRollFallVelocities[bot] or 0
		if rollPressTime and fallVelocity < -40 then
			local ms = (os.clock() - rollPressTime) * 1000
			local perfect = ms < 100
			local speedMultiplier = if perfect then (1.3 + ((0.1 - ms / 1000) * 3.5) ^ 0.85) else 1.3

			humanoid.WalkSpeed *= speedMultiplier
			rootPart.AssemblyLinearVelocity += moveDirection * math.clamp(speedMultiplier * 12, 8, 28)
			BotRuntime.playActionAnimation(bot, "Roll")
			PlaySound("Roll", rootPart, ms)
			state.lastRollActionTime = os.clock()

			addReward(rootPart.Position, moveDirection, if perfect then 18 else 9)
			if state.debug then pushLog(`Roll action: {math.floor(ms)} ms{if perfect then " perfect" else ""}.`) end

			task.delay(if perfect then 0.2 else 0.35, function()
				if humanoid.Parent then humanoid.WalkSpeed = 32 end
			end)
		end

		botRollPressTimes[bot] = nil
		botRollFallVelocities[bot] = 0
	end

	botRollFloorMaterials[bot] = floorMaterial
	state.lastFloorMaterial = floorMaterial
end

local function stabilizeTaggedBot(rootPart: BasePart)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	task.delay(0.08, function()
		if not rootPart.Parent then return end

		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end)
end

local function stabilizeBotAfterPlayerTag(bot: Model, rootPart: BasePart)
	setCharacterCollision(bot, false)
	stabilizeTaggedBot(rootPart)

	task.delay(0.35, function()
		if not bot.Parent then return end

		setCharacterCollision(bot, true)
		if rootPart.Parent then stabilizeTaggedBot(rootPart) end
	end)
end

local function maybeTag(rootPart: BasePart, targetRoot: BasePart)
	local now = os.clock()
	if now - state.lastTagTime < 0.8 then return end

	local bot = rootPart:FindFirstAncestorOfClass("Model")
	if not bot then return end
	local botRole = getBotRole(bot)
	if not isTaggerRole(botRole) then return end

	local delta = targetRoot.Position - rootPart.Position
	local distance = delta.Magnitude
	if distance > Config.TAG_RANGE then return end

	local forward = rootPart.CFrame.LookVector
	local facing = if delta.Magnitude > 0 then forward:Dot(delta.Unit) else 1
	if facing < 0.35 then return end

	losParams.FilterDescendantsInstances = getIgnoreList()
	local result = workspace:Raycast(rootPart.Position + Vector3.new(0, 1.5, 0), delta, losParams)
	if result and result.Instance:IsDescendantOf(workspace:FindFirstChild("Map") or workspace) then return end

	state.successes += 1
	state.attempts += 1
	state.lastTagTime = now
	addReward(rootPart.Position, delta, 100)
	pushLog(`Tag success #{state.successes} at {math.floor(distance * 10) / 10} studs.`)
	PlaySound("Tag", rootPart)

	local targetCharacter = targetRoot:FindFirstAncestorOfClass("Model")
	local localCharacter = localPlayer.Character
	local roleConfig = getRoleConfig(botRole)
	if roleConfig and typeof(roleConfig.onTagBecomes) == "string" and typeof(roleConfig.onTagGives) == "string" then
		if targetCharacter and localCharacter and targetCharacter == localCharacter then
				local success, result = pcall(function()
					return BotTagRF:InvokeServer(botRole, targetRoot, rootPart.Position)
				end)
				if success and typeof(result) == "table" and result.success == true then
					assignBotToRoleSlot(bot, humanoid, rootPart, result.botRole or roleConfig.onTagBecomes)
					stabilizeBotAfterPlayerTag(bot, rootPart)
					restartTaggerAfterTag()
				else
				pushLog("Server rejected bot tag request.")
			end
		elseif targetCharacter then
			local targetRole = targetCharacter:GetAttribute("Role")
			if typeof(targetRole) == "string" and roleConfig.canTagRoles and table.find(roleConfig.canTagRoles, targetRole) then
				if targetCharacter == state.bot or targetCharacter == state.runnerBot then
					if hitBotNtb(targetCharacter, targetRoot) then return end
				end

				PlaySound("TagHit", targetRoot)
				if targetCharacter == state.bot or targetCharacter == state.runnerBot then
					setCharacterCollision(targetCharacter, false)
				end
					KnockbackVelocity.apply({
						targetRootPart = targetRoot,
						originPosition = rootPart.Position,
						sourceVelocity = rootPart.AssemblyLinearVelocity,
						sourceRightVector = rootPart.CFrame.RightVector,
						knockbackType = "LocalBotTag",
					})
					grantBotNtb(bot)
					assignBotToRoleSlot(bot, humanoid, rootPart, roleConfig.onTagBecomes)
					local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
					assignBotToRoleSlot(targetCharacter, targetHumanoid, targetRoot, roleConfig.onTagGives)
					stabilizeBotAfterPlayerTag(bot, rootPart)
					if targetCharacter == state.bot or targetCharacter == state.runnerBot then
					stabilizeBotAfterPlayerTag(targetCharacter, targetRoot)
				end
				restartTaggerAfterTag()
			end
		end
	end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 64, 64)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.Parent = bot
	game:GetService("TweenService"):Create(highlight, TweenInfo.new(0.35), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	task.delay(0.4, function()
		highlight:Destroy()
	end)
end

local RouteRuntime = (function()
	local function isVaultAction(actionName: string): boolean
		return string.find(actionName, "Vault") ~= nil or string.find(actionName, "vault") ~= nil
	end

	local function getRouteEndDistance(route: RouteInfo, position: Vector3): number
		local endPoint = route.points[#route.points]
		if not endPoint then return math.huge end

		return (endPoint.position - position).Magnitude
	end

	local function setRouteCooldown(route: RouteInfo, seconds: number)
		state.routeCooldowns[route.id] = os.clock() + seconds
	end

	local function isRouteCoolingDown(route: RouteInfo): boolean
		local cooldownUntil = state.routeCooldowns[route.id]
		if not cooldownUntil then return false end
		if cooldownUntil <= os.clock() then
			state.routeCooldowns[route.id] = nil
			return false
		end

		return true
	end

	local function getRouteActionKind(actionName: string): string
		local normalized = string.lower(actionName)
		if string.find(normalized, "slidecancel") or string.find(normalized, "slide cancel") then return "SlideCancel" end
		if string.find(normalized, "slide") then return "Slide" end
		if string.find(normalized, "vault") then return "Vault" end
		if string.find(normalized, "swing") then return "Swing" end
		if string.find(normalized, "roll") then return "Roll" end
		if string.find(normalized, "jump") then return "Jump" end
		return "Move"
	end

	local function shouldAttemptRouteAction(cursor: number, actionKind: string): boolean
		if actionKind == "Move" then return false end
		if actionKind ~= "Jump" and state.routeActionAttemptCursor == cursor and state.routeActionAttemptName == actionKind then return false end
		if os.clock() - state.lastRouteActionAttemptTime < 0.28 then return false end

		state.routeActionAttemptCursor = cursor
		state.routeActionAttemptName = actionKind
		state.lastRouteActionAttemptTime = os.clock()
		return true
	end

	local function getRouteActionRadius(actionKind: string): number
		if actionKind == "Roll" then return 2.35 end
		if actionKind == "Vault" or actionKind == "Swing" then return 8 end
		if actionKind == "Slide" then return 9 end
		if actionKind == "SlideCancel" then return 3.25 end
		return 5
	end

	local function getRouteReachedRadius(actionKind: string): number
		if actionKind == "Roll" then return 2.25 end
		if actionKind == "Vault" or actionKind == "Swing" then return 3 end
		if actionKind == "SlideCancel" then return 2.75 end
		return 5
	end

	local function getRouteVaultApproachDirection(rootPart: BasePart, routePoint: RoutePointInfo, baseDirection: Vector3): Vector3
		if baseDirection.Magnitude < 0.1 then return baseDirection end
		if state.routeVaultMisses < 2 then return baseDirection.Unit end

		local side = if state.routeVaultApproachSide >= 0 then 1 else -1
		local right = Vector3.new(baseDirection.Z, 0, -baseDirection.X)
		local approachPoint = routePoint.position + right.Unit * side * math.clamp(2.5 + state.routeVaultMisses * 0.4, 2.5, 5)
		local approachDelta = approachPoint - rootPart.Position
		local flatApproachDelta = Vector3.new(approachDelta.X, 0, approachDelta.Z)
		return if flatApproachDelta.Magnitude > 0.1 then flatApproachDelta.Unit else baseDirection.Unit
	end

	local function findRoutePointPart(routePoint: RoutePointInfo): BasePart?
		local fullName = routePoint.partName
		if not fullName or fullName == "" then return nil end

		local current: Instance = game
		for token in string.gmatch(fullName, "[^%.]+") do
			if token == "game" then
				current = game
			elseif token == "Workspace" or token == "workspace" then
				current = workspace
			else
				local child = current:FindFirstChild(token)
				if not child then
					current = game
					break
				end
				current = child
			end
		end

		if current:IsA("BasePart") then return current end

		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("BasePart") and descendant:GetFullName() == fullName then return descendant end
		end

		return nil
	end

	local function getClosestPartPoint(part: BasePart, position: Vector3): Vector3
		local localPosition = part.CFrame:PointToObjectSpace(position)
		local halfSize = part.Size * 0.5
		local clampedLocalPosition = Vector3.new(
			math.clamp(localPosition.X, -halfSize.X, halfSize.X),
			math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
			math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
		)
		return part.CFrame:PointToWorldSpace(clampedLocalPosition)
	end

	local function getRoutePartAimDirection(rootPart: BasePart, routePoint: RoutePointInfo): Vector3?
		local part = findRoutePointPart(routePoint)
		if not part then return nil end

		local aimPoint = getClosestPartPoint(part, rootPart.Position)
		local flatDelta = Vector3.new(aimPoint.X - rootPart.Position.X, 0, aimPoint.Z - rootPart.Position.Z)
		return if flatDelta.Magnitude > 0.1 then flatDelta.Unit else nil
	end

	local function getRouteVaultTimingDistance(rootPart: BasePart, routePoint: RoutePointInfo, fallbackDistance: number): number
		local part = findRoutePointPart(routePoint)
		if not part then return fallbackDistance end

		local aimPoint = getClosestPartPoint(part, rootPart.Position)
		local flatDelta = Vector3.new(aimPoint.X - rootPart.Position.X, 0, aimPoint.Z - rootPart.Position.Z)
		return if flatDelta.Magnitude > 0.1 then flatDelta.Magnitude else fallbackDistance
	end

	local function getRouteMinimumVaultHeight(routePoint: RoutePointInfo): number?
		local studs = routePoint.studs
		if not studs or studs <= 0 then return nil end
		if studs <= 2.75 then return studs end
		if studs >= Config.HIGH_VAULT_MIN_STUDS then return 2.55 end
		if studs > Config.GROUND_VAULT_REACH_STUDS then return 1.75 end
		return nil
	end

	local function getRouteDesiredVaultStuds(routePoint: RoutePointInfo, rootPart: BasePart): number
		local studs = routePoint.studs
		if studs and studs > 0 then return studs end
		return math.max(0, getFloorHeightDelta(rootPart.Position, routePoint.position))
	end

	local function getRouteVaultJumpPower(routePoint: RoutePointInfo, rootPart: BasePart): number
		local desiredStuds = getRouteDesiredVaultStuds(routePoint, rootPart)
		if desiredStuds >= Config.HIGH_VAULT_MAX_STUDS - 0.35 then return 36 end
		if desiredStuds >= Config.HIGH_VAULT_MIN_STUDS then return 34 end
		if desiredStuds > Config.GROUND_VAULT_REACH_STUDS then return 32 end
		return 30
	end

	local function getRouteVaultJumpWindow(routePoint: RoutePointInfo, rootPart: BasePart): (number, number)
		local desiredStuds = getRouteDesiredVaultStuds(routePoint, rootPart)
		local highAlpha =
			math.clamp((desiredStuds - Config.GROUND_VAULT_REACH_STUDS) / (Config.HIGH_VAULT_MAX_STUDS - Config.GROUND_VAULT_REACH_STUDS), 0, 1)
		local idealLeadTime = 0.18 + highAlpha * 0.24
		local tolerance = 0.1 + highAlpha * 0.07
		return math.max(0.04, idealLeadTime - tolerance), idealLeadTime + tolerance
	end

	local function getRouteVaultAimDirection(rootPart: BasePart, routePoint: RoutePointInfo, moveDirection: Vector3): Vector3
		if moveDirection.Magnitude < 0.1 then return moveDirection end

		local partAimDirection = getRoutePartAimDirection(rootPart, routePoint)
		local baseDirection = partAimDirection or getRouteVaultApproachDirection(rootPart, routePoint, moveDirection)
		local bestDirection = baseDirection
		local bestScore = -math.huge
		local angleOffsets = { 0, -28, 28, -48, 48, -72, 72, -90, 90 }
		local minimumVaultHeight = getRouteMinimumVaultHeight(routePoint)

		for _, angleOffset in angleOffsets do
			local rotatedDirection = rotateFlatDirection(baseDirection, math.rad(angleOffset))
			local candidateDirection = if rotatedDirection.Magnitude > 0.1 then rotatedDirection.Unit else baseDirection
			local hitResult, isSwingBar = getAerialParkourHit(rootPart, candidateDirection)
			if not hitResult or isSwingBar then continue end
			local vaultHeight = getVaultHeight(rootPart, hitResult)
			if minimumVaultHeight and vaultHeight + 0.08 < minimumVaultHeight then continue end

			local hitDistance = (hitResult.Position - routePoint.position).Magnitude
			local moveAlignment = candidateDirection:Dot(moveDirection.Unit)
			local heightBonus = if minimumVaultHeight then math.clamp(vaultHeight - minimumVaultHeight, 0, 0.45) * 3 else 0
			local score = -hitDistance + moveAlignment * 2 + heightBonus - math.abs(angleOffset) * 0.025
			if math.abs(angleOffset) >= 48 then
				score += 2.5 + math.clamp(state.routeVaultMisses, 0, 4) * 0.8
			end

			if score > bestScore then
				bestScore = score
				bestDirection = candidateDirection
			end
		end

		return bestDirection
	end

	local function getRouteVaultLaunchDirection(moveDirection: Vector3, vaultDirection: Vector3): Vector3
		if moveDirection.Magnitude < 0.1 then return vaultDirection end
		if vaultDirection.Magnitude < 0.1 then return moveDirection end

		local mixedDirection = moveDirection.Unit * 0.75 + vaultDirection.Unit * 0.45
		return if mixedDirection.Magnitude > 0.1 then mixedDirection.Unit else moveDirection.Unit
	end

	local function tryRouteVaultAction(
		rootPart: BasePart,
		humanoid: Humanoid,
		routePoint: RoutePointInfo,
		moveDirection: Vector3,
		vaultDirection: Vector3,
		forceTimedJump: boolean?
	): boolean
		if moveDirection.Magnitude < 0.1 then return false end

		local approachDirection = if vaultDirection.Magnitude > 0.1
			then vaultDirection.Unit
			else getRouteVaultAimDirection(rootPart, routePoint, moveDirection)
		local minimumVaultHeight = getRouteMinimumVaultHeight(routePoint)
		local directVault =
			tryValidatedBotVault(rootPart, humanoid, approachDirection, humanoid.FloorMaterial ~= Enum.Material.Air, minimumVaultHeight)
		if directVault then return true end

		if not forceTimedJump and state.routeVaultMisses < 2 and not minimumVaultHeight then return false end
		if humanoid.FloorMaterial == Enum.Material.Air then return false end

		local launchDirection = getRouteVaultLaunchDirection(moveDirection, approachDirection)
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + approachDirection)
		local jumped = tryBotJump(rootPart, humanoid, getRouteVaultJumpPower(routePoint, rootPart), launchDirection * 7, "Jump1")
		if not jumped then return false end

		task.delay(0.16, function()
			if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, approachDirection, nil, minimumVaultHeight) end
		end)
		task.delay(0.3, function()
			if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, approachDirection, nil, minimumVaultHeight) end
		end)
		if minimumVaultHeight and minimumVaultHeight >= 2.35 then
			task.delay(0.44, function()
				if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, approachDirection, nil, minimumVaultHeight) end
			end)
		end

		return true
	end

	local function tryRoutePreVaultJump(
		rootPart: BasePart,
		humanoid: Humanoid,
		routePoint: RoutePointInfo,
		moveDirection: Vector3,
		vaultDirection: Vector3,
		distance: number
	): boolean
		if moveDirection.Magnitude < 0.1 then return false end
		if humanoid.FloorMaterial == Enum.Material.Air then return false end
		local minimumVaultHeight = getRouteMinimumVaultHeight(routePoint)
		if state.routePreVaultJumpCursor == state.activeRouteCursor and not minimumVaultHeight then return false end

		local now = os.clock()
		local retryCooldown = if minimumVaultHeight then 0.34 else 0.55
		if now - state.lastRoutePreVaultJumpTime < retryCooldown then return false end

		local floorHeightDelta = getFloorHeightDelta(rootPart.Position, routePoint.position)
		local authoredStuds = routePoint.studs or floorHeightDelta
		local needsTimedJump = authoredStuds > Config.GROUND_VAULT_REACH_STUDS + 0.35
			or floorHeightDelta > Config.GROUND_VAULT_REACH_STUDS + 0.35
			or minimumVaultHeight ~= nil
			or state.routeVaultMisses > 0
		if not needsTimedJump then return false end
		local timingDistance = getRouteVaultTimingDistance(rootPart, routePoint, distance)
		if timingDistance < 6.4 or timingDistance > 13.8 then return false end

		local flatVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude
		local expectedSpeed = math.max(flatVelocity, humanoid.WalkSpeed * 0.75, 18)
		local timeToVault = timingDistance / expectedSpeed
		local minLeadTime, maxLeadTime = getRouteVaultJumpWindow(routePoint, rootPart)
		if timeToVault < minLeadTime or timeToVault > maxLeadTime then return false end

		local approachDirection = if vaultDirection.Magnitude > 0.1
			then vaultDirection.Unit
			else getRouteVaultAimDirection(rootPart, routePoint, moveDirection)
		local launchDirection = getRouteVaultLaunchDirection(moveDirection, approachDirection)
		local jumpPower = getRouteVaultJumpPower(routePoint, rootPart)
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + approachDirection)
		local jumped = tryBotJump(rootPart, humanoid, jumpPower, launchDirection * 7, "Jump1")
		if not jumped then return false end

		state.routePreVaultJumpCursor = state.activeRouteCursor
		state.lastRoutePreVaultJumpTime = now

		task.delay(0.12, function()
			if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, approachDirection, nil, minimumVaultHeight) end
		end)
		task.delay(0.24, function()
			if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, approachDirection, nil, minimumVaultHeight) end
		end)
		task.delay(0.36, function()
			if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, approachDirection, nil, minimumVaultHeight) end
		end)

		if state.debug then
			pushLog(`Pre-vault jump: {math.floor(timingDistance * 10) / 10} studs out, height {math.floor(floorHeightDelta * 10) / 10}.`)
		end

		return true
	end

	local function failActiveRoute(rootPart: BasePart, moveDirection: Vector3, reason: string)
		local route = state.activeRoute
		if not route then return end

		route.failures = (route.failures or 0) + 1
		local endDistance = getRouteEndDistance(route, rootPart.Position)
		local penalty = -math.clamp(endDistance * 0.55, 6, 32)
		addReward(rootPart.Position, moveDirection, penalty)
		if state.activeRoutePractice then
			pushLog(`Route failed: {reason} | end distance {math.floor(endDistance * 10) / 10}. Retrying from start.`)
			resetActiveRouteToStart(reason)
			return
		end

		setRouteCooldown(route, Config.FAILED_ROUTE_COOLDOWN_SECONDS)
		state.activeRoute = nil
		state.activeRoutePractice = false
		state.activeRouteCursor = 1
		state.routeResetCount += 1
		state.activeTechAttempt = nil
		pushLog(
			`Route failed: {reason} | end distance {math.floor(endDistance * 10) / 10}. Giving it up for {Config.FAILED_ROUTE_COOLDOWN_SECONDS}s.`
		)
	end

	rewardRouteVault = function(rootPart: BasePart, moveDirection: Vector3)
		local route = state.activeRoute
		if not route then return end

		state.routeAttemptVaults += 1
		local nearestDistance = math.huge
		for _, point in route.points do
			if isVaultAction(point.action) then nearestDistance = math.min(nearestDistance, (point.position - rootPart.Position).Magnitude) end
		end

		if nearestDistance < math.huge then
			local reward = math.clamp(10 - nearestDistance, -8, 10)
			addReward(rootPart.Position, moveDirection, reward)
		end

		if state.routeAttemptVaults > route.maxVaults then failActiveRoute(rootPart, moveDirection, "vault cap exceeded") end
	end

	local function getPredictedTargetPosition(rootPart: BasePart, targetRoot: BasePart): Vector3
		local now = os.clock()
		local targetPosition = targetRoot.Position
		local targetVelocity = targetRoot.AssemblyLinearVelocity
		local flatActualVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)
		local previousSamplePosition = state.reactionTargetPosition

		if not previousSamplePosition then
			state.reactionTargetPosition = targetPosition
			state.reactionTargetVelocity = flatActualVelocity
			state.lastReactionSampleTime = now
		elseif now - state.lastReactionSampleTime >= Config.TARGET_REACTION_DELAY_SECONDS then
			local sampleDt = math.max(0.001, now - state.lastReactionSampleTime)
			local measuredVelocity =
				Vector3.new((targetPosition.X - previousSamplePosition.X) / sampleDt, 0, (targetPosition.Z - previousSamplePosition.Z) / sampleDt)
			state.reactionTargetPosition = targetPosition
			state.reactionTargetVelocity = state.reactionTargetVelocity:Lerp(measuredVelocity, 0.38)
			state.lastReactionSampleTime = now
		end

		local distance = (targetPosition - rootPart.Position).Magnitude
		local flatVelocity = state.reactionTargetVelocity
		local targetSpeed = flatVelocity.Magnitude
		state.lastCutoffKey = nil

		if distance <= Config.DIRECT_CHASE_CLOSE_DISTANCE or targetSpeed < 5 then return targetPosition end

		local distanceBucket = if distance < 45 then "near" elseif distance < 85 then "mid" else "far"
		local speedBucket = if targetSpeed < 18 then "slow" elseif targetSpeed < 36 then "run" else "fast"
		local cutoffKey = `{distanceBucket}:{speedBucket}`
		local cutoffScore = state.cutoffScores[cutoffKey]
		local cutoffConfidence = if cutoffScore then cutoffScore.score else 0
		local cutoffVisits = if cutoffScore then cutoffScore.visits else 0
		local shouldCutoff = distance >= Config.CUTOFF_MIN_DISTANCE and (cutoffVisits < 3 or cutoffConfidence > -0.75 or distance > 70)

		if not shouldCutoff then return targetPosition end

		state.lastCutoffKey = cutoffKey

		local leadTime = state.predictionLeadTime
		if distance < 45 then
			leadTime *= 0.45
		elseif distance > 75 then
			leadTime *= 1.25
		end

		if state.lastPredictionError and state.lastPredictionError > 12 then
			leadTime *= 0.55
		end

		local predictedPosition = targetPosition + flatVelocity * leadTime
		local toPredicted = predictedPosition - rootPart.Position
		if toPredicted.Magnitude > 95 then predictedPosition = rootPart.Position + toPredicted.Unit * 95 end

		return predictedPosition
	end

	local function getGraphNavigationPosition(nodePosition: Vector3, targetPosition: Vector3): Vector3
		local targetDelta = targetPosition - nodePosition
		local flatTargetDelta = Vector3.new(targetDelta.X, 0, targetDelta.Z)
		if flatTargetDelta.Magnitude < 0.1 then return nodePosition end

		local lookahead = math.min(Config.GRAPH_NAVIGATION_LOOKAHEAD, flatTargetDelta.Magnitude * 0.55)
		return nodePosition + flatTargetDelta.Unit * lookahead
	end

	local function getRunnerGraphNavigationPosition(rootPart: BasePart, nodePosition: Vector3, fallbackDirection: Vector3): Vector3
		local delta = nodePosition - rootPart.Position
		local flatDelta = Vector3.new(delta.X, 0, delta.Z)
		local direction = if flatDelta.Magnitude > 0.1
			then flatDelta.Unit
			elseif fallbackDirection.Magnitude > 0.1 then fallbackDirection.Unit
			else rootPart.CFrame.LookVector

		local passDistance = math.min(Config.RUNNER_GRAPH_LOOKAHEAD, math.max(6, flatDelta.Magnitude * 0.65))
		return nodePosition + direction * passDistance
	end

	local function chooseMoveTarget(rootPart: BasePart, targetRoot: BasePart, predictedTargetPosition: Vector3): Vector3
		local directRoute = hasDirectRoute(rootPart, predictedTargetPosition)
		local targetFloorHeightDelta = getFloorHeightDelta(rootPart.Position, predictedTargetPosition)
		local needsVerticalRoute = targetFloorHeightDelta > 4.5
		local forceGraphEscape = state.stuckSeconds > 0.75
		local targetDelta = predictedTargetPosition - rootPart.Position
			local flatTargetDelta = Vector3.new(targetDelta.X, 0, targetDelta.Z)
			local blockedDirectRoute = flatTargetDelta.Magnitude > 0.1 and getClearDistance(rootPart, flatTargetDelta) < 3.2
			local needsRoute = forceGraphEscape
				or needsVerticalRoute
				or not directRoute
				or blockedDirectRoute
				or math.abs(targetFloorHeightDelta) > Config.DIRECT_ROUTE_HEIGHT_LIMIT
			local now = os.clock()

			if
				not state.useGraph
				or #state.graph == 0
				or (directRoute and not forceGraphEscape and not needsVerticalRoute and not blockedDirectRoute)
			then
				if
					state.useGraph
					and #state.graph > 0
					and directRoute
					and flatTargetDelta.Magnitude > Config.DIRECT_CHASE_CLOSE_DISTANCE + 8
					and now - state.lastGraphDecisionTime >= Config.DIRECT_OPPORTUNITY_INTERVAL_SECONDS
				then
					local nextNode, nextTech = chooseLightweightGraphHop(
						rootPart.Position,
						predictedTargetPosition,
						flatTargetDelta,
						"Chase",
						nil,
						false
					)
					state.lastGraphDecisionTime = now
					if nextNode then
						local hopHeight = getFloorHeightDelta(rootPart.Position, nextNode.position)
						local directDistance = (predictedTargetPosition - rootPart.Position).Magnitude
						local hopDistance = (predictedTargetPosition - nextNode.position).Magnitude
						local meaningfulTech = nextTech ~= nil and nextTech ~= "Move"
						local usefulVertical = hopHeight >= 4 and hopHeight <= Config.ROLL_BOOST_MAX_HEIGHT_STUDS + 1
						local usefulShortcut = directDistance - hopDistance >= math.max(7, state.graphStep * 1.4)
						if meaningfulTech or usefulVertical or usefulShortcut or nextNode.score > 3 then
							state.graphMoveTarget = getGraphNavigationPosition(nextNode.position, predictedTargetPosition)
							state.graphMoveTech = nextTech
							state.graphMoveTargetSetTime = now
							table.clear(state.path)
							state.pathCursor = 1
							return state.graphMoveTarget
						end
					end
				end
				state.graphMoveTarget = nil
				state.graphMoveTech = nil
				table.clear(state.path)
				state.pathCursor = 1
				invalidateTaggerPathRequest()
				return predictedTargetPosition
			end

			if needsRoute and #state.path > 0 and now - state.lastPathTime < Config.TARGET_REFRESH_SECONDS then
			while state.path[state.pathCursor] do
				local node = state.graph[state.path[state.pathCursor]]
				if not node then
					state.pathCursor += 1
					continue
				end

				local nodeDelta = node.position - rootPart.Position
				local flatNodeDelta = Vector3.new(nodeDelta.X, 0, nodeDelta.Z)
				local targetDelta = predictedTargetPosition - rootPart.Position
				local flatTargetDelta = Vector3.new(targetDelta.X, 0, targetDelta.Z)
				local passedNode = flatNodeDelta.Magnitude > 0.1
					and flatTargetDelta.Magnitude > 0.1
					and flatNodeDelta.Unit:Dot(flatTargetDelta.Unit) < -0.1

				if nodeDelta.Magnitude <= Config.ROUTE_REACHED_RADIUS or passedNode then
					state.pathCursor += 1
					continue
				end

				local previousNode = state.graph[state.path[math.max(1, state.pathCursor - 1)]]
				state.graphMoveTech = if previousNode then previousNode.linkTechs[node.id] or "Move" else "Move"
				return getGraphNavigationPosition(node.position, predictedTargetPosition)
			end
		end

		if state.graphMoveTarget then
			local waypointDistance = (state.graphMoveTarget - rootPart.Position).Magnitude
			local arrivalRadius = math.clamp(state.graphStep * 0.9, 9, 16)
			local staleDistance = (state.graphMoveTarget - predictedTargetPosition).Magnitude
			local waypointAge = now - state.graphMoveTargetSetTime

			if waypointDistance <= arrivalRadius or staleDistance > 20 or waypointAge > Config.GRAPH_WAYPOINT_MAX_AGE_SECONDS then
				state.graphMoveTarget = nil
				state.graphMoveTech = nil
			elseif now - state.lastGraphDecisionTime < Config.GRAPH_DECISION_INTERVAL_SECONDS then
				return state.graphMoveTarget
			end
		end

		if state.graphMoveTarget then return state.graphMoveTarget end

		if needsRoute and now >= state.pathFailureUntil and now - state.lastGraphDecisionTime >= Config.GRAPH_DECISION_INTERVAL_SECONDS then
			local desiredDelta = predictedTargetPosition - rootPart.Position
			local desiredDirection = Vector3.new(desiredDelta.X, 0, desiredDelta.Z)
			local nextNode, nextTech = chooseLightweightGraphHop(
				rootPart.Position,
				predictedTargetPosition,
				desiredDirection,
				"Chase",
				nil,
				forceGraphEscape or needsVerticalRoute or blockedDirectRoute
			)
			state.lastPathTime = now
			state.lastGraphDecisionTime = now
			if nextNode then
				state.graphMoveTarget = getGraphNavigationPosition(nextNode.position, predictedTargetPosition)
				state.graphMoveTech = nextTech
				state.graphMoveTargetSetTime = now
				table.clear(state.path)
				state.pathCursor = 1
				return state.graphMoveTarget
			end
			return predictedTargetPosition
		end

		local currentDistanceToTarget = (predictedTargetPosition - rootPart.Position).Magnitude
		local bestNodePosition = predictedTargetPosition
		local bestNodeTech = "Move"
		local bestScore = -math.huge

		for _, nodeId in collectGraphNodeIdsNear(rootPart.Position, Config.GRAPH_LOCAL_RADIUS) do
			local node = state.graph[nodeId]
			if not node then continue end

			local distanceFromBot = (node.position - rootPart.Position).Magnitude
			if distanceFromBot < math.clamp(state.graphStep * 0.45, 4, 9) then continue end

			local distanceFromTarget = (node.position - predictedTargetPosition).Magnitude
			local realTargetDistance = (node.position - targetRoot.Position).Magnitude
			local progress = currentDistanceToTarget - distanceFromTarget
			local targetHeightDelta = getFloorHeightDelta(rootPart.Position, targetRoot.Position)
			local heightBonus = if targetHeightDelta > 7
				then math.clamp(getFloorHeightDelta(rootPart.Position, node.position), -4, 14) * 0.7
				else math.clamp(-getFloorHeightDelta(rootPart.Position, node.position), -8, 12) * 0.2
			local rollSetupHeight = getFloorHeightDelta(rootPart.Position, node.position)
			if targetHeightDelta <= 4 and rollSetupHeight > 6 and rollSetupHeight <= Config.ROLL_BOOST_MAX_HEIGHT_STUDS then
				local routeDirection = node.position - rootPart.Position
				local targetDirection = predictedTargetPosition - rootPart.Position
				local flatRouteDirection = Vector3.new(routeDirection.X, 0, routeDirection.Z)
				local flatTargetDirection = Vector3.new(targetDirection.X, 0, targetDirection.Z)
				if flatRouteDirection.Magnitude > 0.1 and flatTargetDirection.Magnitude > 0.1 then
					heightBonus += math.max(0, flatRouteDirection.Unit:Dot(flatTargetDirection.Unit)) * rollSetupHeight * 0.35
				end
			end
			local learnedBonus = node.score * 0.6
			local score = progress * 2.4 - distanceFromBot * 0.42 - realTargetDistance * 0.08 + heightBonus + learnedBonus
			if forceGraphEscape then
				score += math.clamp(#node.links - 1, 0, 5) * 4
				score -= node.deadEndPenalty * 18
				score -= node.barrierPenalty * 12
			end
			score -= node.wallPenalty * 22
			if node.openDirections <= 2 and progress < 8 then
				score -= 16
			end

			if distanceFromTarget < currentDistanceToTarget + 5 then
				score += 6
			end
			local nodeDirection = node.position - rootPart.Position
			if targetRoot.AssemblyLinearVelocity.Magnitude > 8 and nodeDirection.Magnitude > 0.1 then
				local targetTravelAlignment = nodeDirection.Unit:Dot(targetRoot.AssemblyLinearVelocity.Unit)
				score += targetTravelAlignment * 3
			end

			if score > bestScore then
				bestScore = score
				bestNodePosition = node.position
				bestNodeTech = getGraphTraversalTech(rootPart.Position, node.position)
			end
		end

		state.lastGraphDecisionTime = now
		local bestImprovement = currentDistanceToTarget - (bestNodePosition - predictedTargetPosition).Magnitude
		if bestNodePosition == predictedTargetPosition or (not forceGraphEscape and bestImprovement < math.max(7, state.graphStep * 0.65)) then
			state.graphMoveTarget = nil
			state.graphMoveTech = nil
			return predictedTargetPosition
		end

		state.graphMoveTarget = getGraphNavigationPosition(bestNodePosition, predictedTargetPosition)
		state.graphMoveTech = bestNodeTech
		state.graphMoveTargetSetTime = now
		return state.graphMoveTarget
	end

	local function runGraphMoveTech(rootPart: BasePart, humanoid: Humanoid, moveDirection: Vector3, techName: string?)
		if not techName or techName == "Move" or moveDirection.Magnitude < 0.1 then return end

		if techName == "Vault" then
			tryValidatedBotVault(rootPart, humanoid, moveDirection, true)
		elseif techName == "HighVault" then
			local jumped = false
			if humanoid.FloorMaterial ~= Enum.Material.Air and os.clock() - state.lastBasicJumpTime > 0.36 then
				jumped = tryBotJump(rootPart, humanoid, 34, moveDirection * 6, "Jump1")
			end
			if jumped then
				task.delay(0.2, function()
					if rootPart.Parent and humanoid.Parent then tryValidatedBotVault(rootPart, humanoid, moveDirection, nil, 2.4) end
				end)
			end
		elseif techName == "Swing" then
			tryAerialParkour(rootPart, humanoid, moveDirection)
		end
	end

	local function refreshGraphVisualization()
		local folder = getGraphDebugFolder()
		if not state.visualizeGraphDebug then
			if state.visualizedGraphRevision ~= -1 then
				folder:ClearAllChildren()
				state.visualizedGraphRevision = -1
			end
			return
		end
		if state.visualizedGraphRevision == state.graphRevision and #folder:GetChildren() == #state.graph then return end

		folder:ClearAllChildren()
		state.visualizedGraphRevision = state.graphRevision

		for _, node in state.graph do
			local marker = Instance.new("Part")
			marker.Name = `GraphNode_{node.id}`
			marker.Shape = Enum.PartType.Ball
			marker.Size = Vector3.new(0.65, 0.65, 0.65)
			marker.Anchored = true
			marker.CanCollide = false
			marker.CanTouch = false
			marker.CanQuery = false
			marker.Material = Enum.Material.Neon
			marker.Color = if node.deadEndPenalty >= 1
				then Color3.fromRGB(255, 95, 95)
				elseif node.wallPenalty > 0.42 or node.openDirections <= 2 then Color3.fromRGB(185, 105, 255)
				elseif node.barrierPenalty > 0 then Color3.fromRGB(255, 185, 80)
				else Color3.fromRGB(85, 180, 255)
			marker.Transparency = 0.18
			marker.Position = node.position
			marker.Parent = folder
		end
	end

	local function refreshPathVisualization()
		local folder = getPathDebugFolder()
		if not state.visualizeDebug then
			folder:ClearAllChildren()
			return
		end

		local now = os.clock()
		if now - state.lastVisualizationTime < Config.TECH_VISUAL_REFRESH_SECONDS then return end
		state.lastVisualizationTime = now
		folder:ClearAllChildren()

		local previousPosition: Vector3? = nil
		local botPosition = if state.rootPart then state.rootPart.Position else nil
		if botPosition then
			addDebugNode(folder, botPosition + Vector3.new(0, 1.7, 0), "Bot", Color3.fromRGB(255, 80, 80))
			previousPosition = botPosition
		end

		if state.activeRoute then
			for index = math.max(1, state.activeRouteCursor - 1), math.min(#state.activeRoute.points, state.activeRouteCursor + 8) do
				local point = state.activeRoute.points[index]
				local color = if index == state.activeRouteCursor then Color3.fromRGB(255, 245, 110) else getTechColor(point.action)
				addDebugNode(folder, point.position, `{index}: {point.action}`, color)
				if previousPosition then addDebugLine(folder, previousPosition, point.position, color) end
				previousPosition = point.position
			end
		elseif #state.path > 0 then
			for index = state.pathCursor, math.min(#state.path, state.pathCursor + 8) do
				local node = state.graph[state.path[index]]
				if not node then continue end

				local color = if index == state.pathCursor then Color3.fromRGB(255, 245, 110) else Color3.fromRGB(105, 175, 255)
				addDebugNode(folder, node.position, if index == state.pathCursor then `Next G{node.id}` else `G{node.id}`, color)
				if previousPosition then addDebugLine(folder, previousPosition, node.position, color) end
				previousPosition = node.position
			end
		end

		if state.graphMoveTarget then addDebugNode(folder, state.graphMoveTarget, "Move target", Color3.fromRGB(120, 255, 220)) end
		if state.runnerRootPart then
			local runnerPosition = state.runnerRootPart.Position
			addDebugNode(folder, runnerPosition + Vector3.new(0, 1.7, 0), "Runner", Color3.fromRGB(90, 170, 255))
			local runnerPreviousPosition: Vector3? = runnerPosition
			if state.runnerRoute then
				for index = state.runnerRouteCursor, math.min(#state.runnerRoute.points, state.runnerRouteCursor + 6) do
					local point = state.runnerRoute.points[index]
					local color = if index == state.runnerRouteCursor then Color3.fromRGB(255, 245, 110) else getTechColor(point.action)
					addDebugNode(folder, point.position, `R{index}: {point.action}`, color)
					if runnerPreviousPosition then addDebugLine(folder, runnerPreviousPosition, point.position, color) end
					runnerPreviousPosition = point.position
				end
			elseif #state.runnerPath > 0 then
				for index = state.runnerPathCursor, math.min(#state.runnerPath, state.runnerPathCursor + 8) do
					local node = state.graph[state.runnerPath[index]]
					if not node then continue end

					local color = if index == state.runnerPathCursor then Color3.fromRGB(255, 245, 110) else Color3.fromRGB(90, 170, 255)
					addDebugNode(folder, node.position, if index == state.runnerPathCursor then `Runner G{node.id}` else `RG{node.id}`, color)
					if runnerPreviousPosition then addDebugLine(folder, runnerPreviousPosition, node.position, color) end
					runnerPreviousPosition = node.position
				end
			end
		end
		if state.activeTechAttempt then
			addDebugNode(
				folder,
				state.activeTechAttempt.startPosition + Vector3.new(0, 2.5, 0),
				state.activeTechAttempt.key,
				getTechColor(state.activeTechAttempt.key)
				)
			end
	end

	local function updateActiveRoute(rootPart: BasePart, humanoid: Humanoid, dt: number)
		local route = state.activeRoute
		if not route then return end
		if #route.points == 0 then
			state.activeRoute = nil
			state.activeRoutePractice = false
			state.activeRouteCursor = 1
			pushLog("Route stopped: no points.")
			return
		end

		local routePoint = route.points[state.activeRouteCursor]
		if not routePoint then
			local elapsed = os.clock() - state.activeRouteStartTime
			route.bestTime = if route.bestTime then math.min(route.bestTime, elapsed) else elapsed
			route.successes = (route.successes or 0) + 1
			local endDistance = getRouteEndDistance(route, rootPart.Position)
			addReward(rootPart.Position, Vector3.zero, 36 + math.max(0, 8 - endDistance) * 2)
			pushLog(`Route completed in {math.floor(elapsed * 10) / 10}s. Resetting to start.`)
			resetActiveRouteToStart("completed")
			return
		end

		local delta = routePoint.position - rootPart.Position
		local flatDelta = Vector3.new(delta.X, 0, delta.Z)
		local moveDirection = if flatDelta.Magnitude > 0.1 then flatDelta.Unit else Vector3.zero
		moveDirection = steerAroundLocalObstacles(rootPart, moveDirection)
		local actionKind = getRouteActionKind(routePoint.action)
		local routeActionTargetPosition = routePoint.position
		local routeUsesSlideCancel = false
		if actionKind == "Slide" then
			for pointIndex = state.activeRouteCursor + 1, math.min(#route.points, state.activeRouteCursor + 3) do
				local lookaheadPoint = route.points[pointIndex]
				local lookaheadActionKind = getRouteActionKind(lookaheadPoint.action)
				if lookaheadActionKind == "SlideCancel" then
					routeUsesSlideCancel = true
					continue
				end
				if lookaheadActionKind ~= "SlideCancel" then
					routeActionTargetPosition = lookaheadPoint.position
					break
				end
			end
		elseif actionKind == "SlideCancel" then
			local nextPoint = route.points[state.activeRouteCursor + 1]
			if nextPoint then routeActionTargetPosition = nextPoint.position end
		end
		local actionTargetDelta = routeActionTargetPosition - rootPart.Position
		local flatActionTargetDelta = Vector3.new(actionTargetDelta.X, 0, actionTargetDelta.Z)
		local routeActionDirection = if flatActionTargetDelta.Magnitude > 0.1 then flatActionTargetDelta.Unit else moveDirection
		local partAimDirection = if actionKind ~= "Move" then getRoutePartAimDirection(rootPart, routePoint) else nil
		local vaultAimDirection = if actionKind == "Vault" then getRouteVaultAimDirection(rootPart, routePoint, moveDirection) else moveDirection
		local faceDirection = if actionKind == "Vault"
			then vaultAimDirection
			elseif actionKind == "Slide" or actionKind == "SlideCancel" then routeActionDirection
			else partAimDirection or moveDirection

		humanoid:Move(moveDirection, false)
		if faceDirection.Magnitude > 0.05 then
			state.lastFaceDirection = turnBotToward(rootPart, faceDirection, state.lastFaceDirection, dt)
		elseif moveDirection.Magnitude > 0.05 then
			state.lastFaceDirection = turnBotToward(rootPart, moveDirection, state.lastFaceDirection, dt)
		end

		local distance = (routePoint.position - rootPart.Position).Magnitude
		if distance + 0.75 < state.routeBestDistance then
			state.routeBestDistance = distance
			state.routeLastProgressTime = os.clock()
		end
		local now = os.clock()
		local routeStuckSeconds = now - state.routeLastProgressTime
		if actionKind == "Vault" and distance < 12 and routeStuckSeconds > 0.55 and now - state.lastRouteVaultMissTime > 0.55 then
			state.routeVaultMissCursor = state.activeRouteCursor
			state.routeVaultMisses += 1
			state.lastRouteVaultMissTime = now
			state.routeActionAttemptCursor = 0
			state.routeActionAttemptName = nil
			if state.routeVaultMisses % 2 == 0 then
				state.routeVaultApproachSide *= -1
			end
			if state.debug then pushLog(`Route vault miss {state.routeVaultMisses}; changing approach.`) end
		end

		if distance < getRouteReachedRadius(actionKind) and actionKind == "Move" then
			state.activeRouteCursor += 1
			state.routeBestDistance = math.huge
			state.routeLastProgressTime = os.clock()
			state.routeVaultMissCursor = 0
			state.routeVaultMisses = 0
			state.routeVaultApproachSide = 1
			state.routePreVaultJumpCursor = 0
		end

		if now - state.activeRouteStartTime > route.maxTime then
			failActiveRoute(rootPart, moveDirection, "max time reached")
			return
		elseif now - state.routeLastProgressTime > 1.65 then
			failActiveRoute(rootPart, moveDirection, "stuck on route point")
			return
		elseif
			state.routeAttemptVaults > route.maxVaults
			or state.routeAttemptSwings > route.maxSwings
			or state.routeAttemptRolls > route.maxRolls
		then
			failActiveRoute(rootPart, moveDirection, "action constraint exceeded")
			return
		end

		updateBotRoll(rootPart, humanoid, moveDirection)
		tryRollSetupDrop(rootPart, humanoid, routePoint.position, moveDirection)
		tryRollBoostJump(rootPart, humanoid, routePoint.position, moveDirection)
		tryLocalGeometryVault(rootPart, humanoid, routePoint.position, moveDirection)
		updateBotTrampoline(state.bot, rootPart, humanoid)
		finishTechAttempt(rootPart, routePoint.position)

		local clearDistance = getClearDistance(rootPart, moveDirection)
		local blockedMove = clearDistance < 2.8 and routeStuckSeconds > 0.45
		if actionKind == "Vault" then tryRoutePreVaultJump(rootPart, humanoid, routePoint, moveDirection, vaultAimDirection, distance) end
		local nearTechNode = actionKind ~= "Move" and actionKind ~= "Jump" and distance <= getRouteActionRadius(actionKind)
		local actionCompleted = false
		local shouldSpamTech = nearTechNode
			and (if actionKind == "Roll" then now - state.lastRouteActionAttemptTime > 0.06 else now - state.lastRouteActionAttemptTime > 0.11)
		if shouldSpamTech then
			state.lastRouteActionAttemptTime = now
			if actionKind == "Vault" then
				if tryRouteVaultAction(rootPart, humanoid, routePoint, moveDirection, vaultAimDirection, false) then
					actionCompleted = true
				else
					tryValidatedBotVault(rootPart, humanoid, vaultAimDirection, nil, getRouteMinimumVaultHeight(routePoint))
				end
			elseif actionKind == "Swing" then
				tryAerialParkour(rootPart, humanoid, faceDirection)
				state.routeAttemptSwings += 1
				actionCompleted = true
			elseif actionKind == "Roll" then
				local previousRollTime = state.lastRollActionTime
				updateBotRoll(rootPart, humanoid, moveDirection)
				if state.lastRollActionTime ~= previousRollTime then
					state.routeAttemptRolls += 1
					actionCompleted = true
				end
			elseif actionKind == "Slide" then
				if trySlideBoost(rootPart, humanoid, routeActionTargetPosition, routeActionDirection, routeUsesSlideCancel) then
					actionCompleted = true
				end
			elseif actionKind == "SlideCancel" then
				local jumpDelay = if state.slideBoostJumpDelay > 0 then state.slideBoostJumpDelay else 0.12
				if
					finishSlideBoost(
						rootPart,
						humanoid,
						routeActionTargetPosition,
						routeActionDirection,
						state.slideBoostKey or "RouteSlide",
						jumpDelay
					)
				then
					actionCompleted = true
				end
			end
		elseif shouldAttemptRouteAction(state.activeRouteCursor, actionKind) then
			if actionKind == "Jump" then
				if
					distance <= getRouteActionRadius(actionKind)
					and tryBotJump(rootPart, humanoid, 29, if moveDirection.Magnitude > 0.1 then moveDirection * 5 else nil, "Jump1")
				then
					actionCompleted = true
				end
			elseif actionKind == "Vault" then
				if tryRouteVaultAction(rootPart, humanoid, routePoint, moveDirection, vaultAimDirection, false) then
					actionCompleted = distance <= getRouteActionRadius(actionKind) + 2
				else
					tryExperimentalTech(rootPart, humanoid, routePoint.position, moveDirection)
				end
			elseif actionKind == "Swing" then
				tryAerialParkour(rootPart, humanoid, moveDirection)
				actionCompleted = distance <= getRouteActionRadius(actionKind)
			elseif actionKind == "Roll" then
				if os.clock() - state.lastRollActionTime > 0.3 and humanoid.FloorMaterial ~= Enum.Material.Air then
					tryBotJump(rootPart, humanoid, 30, if moveDirection.Magnitude > 0.1 then moveDirection * 8 else nil, "Jump2")
				end
			elseif actionKind == "Slide" then
				if trySlideBoost(rootPart, humanoid, routeActionTargetPosition, routeActionDirection, routeUsesSlideCancel) then
					actionCompleted = distance <= getRouteActionRadius(actionKind) + 2
				else
					tryExperimentalTech(rootPart, humanoid, routeActionTargetPosition, routeActionDirection)
				end
			elseif actionKind == "SlideCancel" then
				local jumpDelay = if state.slideBoostJumpDelay > 0 then state.slideBoostJumpDelay else 0.12
				if
					finishSlideBoost(
						rootPart,
						humanoid,
						routeActionTargetPosition,
						routeActionDirection,
						state.slideBoostKey or "RouteSlide",
						jumpDelay
					)
				then
					actionCompleted = distance <= getRouteActionRadius(actionKind) + 1
				end
			end
		elseif blockedMove and os.clock() - state.lastRouteRecoveryJumpTime > 0.75 then
			state.lastRouteRecoveryJumpTime = os.clock()
			if actionKind == "Vault" and tryRouteVaultAction(rootPart, humanoid, routePoint, moveDirection, vaultAimDirection, true) then return end
			if not tryValidatedBotVault(rootPart, humanoid, moveDirection, true) then
				tryBotJump(rootPart, humanoid, 25, if moveDirection.Magnitude > 0.1 then moveDirection * 4 else nil, "Jump1")
			end
		end
		if actionCompleted then
			state.activeRouteCursor += 1
			state.routeBestDistance = math.huge
			state.routeLastProgressTime = os.clock()
			state.routeVaultMissCursor = 0
			state.routeVaultMisses = 0
			state.routeVaultApproachSide = 1
			state.routePreVaultJumpCursor = 0
		end
		BotRuntime.updateAnimations(state.bot, humanoid, rootPart)
		BotRuntime.updateMovementSounds(
			state.bot,
			humanoid,
			rootPart,
			Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude
		)

		if dt > 0 and trainerUi then
			local fps = math.floor(1 / dt + 0.5)
			trainerUi:setStatus(
				`Route: ON   FPS: {fps}   Point: {state.activeRouteCursor}/{#route.points}   Dist: {math.floor(distance * 10) / 10}   S/F: {route.successes}/{route.failures}   Resets: {state.routeResetCount}`
			)
		end
	end

	return {
		isRouteCoolingDown = isRouteCoolingDown,
		setRouteCooldown = setRouteCooldown,
		getPredictedTargetPosition = getPredictedTargetPosition,
		chooseMoveTarget = chooseMoveTarget,
		getRunnerGraphNavigationPosition = getRunnerGraphNavigationPosition,
		runGraphMoveTech = runGraphMoveTech,
		refreshGraphVisualization = refreshGraphVisualization,
		refreshPathVisualization = refreshPathVisualization,
		updateActiveRoute = updateActiveRoute,
	}
end)()

local function getUsefulRunnerRoute(rootPart: BasePart, threatRoot: BasePart): RouteInfo?
	local currentThreatDistance = (rootPart.Position - threatRoot.Position).Magnitude
	local bestRoute: RouteInfo? = nil
	local bestScore = -math.huge

	for _, route in state.routes do
		if RouteRuntime.isRouteCoolingDown(route) then continue end

		local startPoint = route.points[1]
		local endPoint = route.points[#route.points]
		if not startPoint or not endPoint then continue end

		local startDistance = (startPoint.position - rootPart.Position).Magnitude
		if startDistance > 55 then continue end

		local endThreatDistance = (endPoint.position - threatRoot.Position).Magnitude
		local escapeGain = endThreatDistance - currentThreatDistance
		if escapeGain < -8 then continue end

		local successes = route.successes or 0
		local failures = route.failures or 0
		local successRate = (successes + 1) / math.max(1, successes + failures + 2)
		local routeDelta = startPoint.position - rootPart.Position
		local flatRouteDelta = Vector3.new(routeDelta.X, 0, routeDelta.Z)
		local clearDistance = if flatRouteDelta.Magnitude > 0.1 then getClearDistance(rootPart, flatRouteDelta) else math.huge
		local routeBlockedPenalty = if clearDistance < math.min(startDistance, Config.WALL_CHECK_DISTANCE * 0.85) then 18 else 0
		local nearestStartNodeId = if state.useGraph and #state.graph > 0 then nearestNodeId(startPoint.position, math.max(42, state.graphStep * 10)) else nil
		local graphPenalty = if state.useGraph and #state.graph > 0 and not nearestStartNodeId then 12 else 0
		local routeLengthPenalty = #route.points * 0.9
		local endBarrierPenalty = getBarrierPenalty(endPoint.position) * 22
		local score = escapeGain * 2.6 + successRate * 22 - startDistance * 0.42 - routeLengthPenalty - routeBlockedPenalty - graphPenalty - endBarrierPenalty

		if endThreatDistance < Config.TAG_RANGE * 2.5 then
			score -= 80
		end

		if score > bestScore then
			bestScore = score
			bestRoute = route
		end
	end

	if bestScore < 10 then return nil end
	return bestRoute
end

local function estimateRouteLength(route: RouteInfo): number
	local length = 0
	local previousPoint = route.points[1]
	if not previousPoint then return 0 end

	for index = 2, #route.points do
		local point = route.points[index]
		length += (point.position - previousPoint.position).Magnitude
		previousPoint = point
	end

	return length
end

local function getUsefulTaggerRoute(rootPart: BasePart, targetRoot: BasePart, predictedTargetPosition: Vector3): RouteInfo?
	local currentDistance = (predictedTargetPosition - rootPart.Position).Magnitude
	local directEstimate = currentDistance / 32
	local bestRoute: RouteInfo? = nil
	local bestSaving = 0

	for _, route in state.routes do
		if RouteRuntime.isRouteCoolingDown(route) then continue end
		if #route.points < 2 then continue end

		local startPoint = route.points[1]
		local endPoint = route.points[#route.points]
		if not startPoint or not endPoint then continue end

		local startDistance = (startPoint.position - rootPart.Position).Magnitude
		if startDistance > 58 then continue end

		local endDistanceToTarget = (endPoint.position - predictedTargetPosition).Magnitude
		if endDistanceToTarget > currentDistance - 8 then continue end

		local routeDirection = endPoint.position - rootPart.Position
		local targetDirection = predictedTargetPosition - rootPart.Position
		local flatRouteDirection = Vector3.new(routeDirection.X, 0, routeDirection.Z)
		local flatTargetDirection = Vector3.new(targetDirection.X, 0, targetDirection.Z)
		if
			flatRouteDirection.Magnitude > 0.1
			and flatTargetDirection.Magnitude > 0.1
			and flatRouteDirection.Unit:Dot(flatTargetDirection.Unit) < 0.05
		then
			continue
		end

		local successes = route.successes or 0
		local failures = route.failures or 0
		local successRate = (successes + 1) / math.max(1, successes + failures + 2)
		local routeDelta = startPoint.position - rootPart.Position
		local flatRouteDelta = Vector3.new(routeDelta.X, 0, routeDelta.Z)
		local clearDistance = if flatRouteDelta.Magnitude > 0.1 then getClearDistance(rootPart, flatRouteDelta) else math.huge
		local pathPenalty = if clearDistance < math.min(startDistance, Config.WALL_CHECK_DISTANCE * 0.85) then 0.9 else 0
		local routeLength = estimateRouteLength(route)
		local routeEstimate = startDistance / 32 + routeLength / 38 + endDistanceToTarget / 32 + pathPenalty
		local saving = directEstimate - routeEstimate + successRate * 0.35 - getBarrierPenalty(endPoint.position) * 0.6

		if route.bestTime then
			saving += math.clamp((routeLength / 32) - route.bestTime, -1.2, 1.8) * 0.45
		end
		if targetRoot.AssemblyLinearVelocity.Magnitude > 8 then
			local routeExitDelta = predictedTargetPosition - endPoint.position
			local flatRouteExitDelta = Vector3.new(routeExitDelta.X, 0, routeExitDelta.Z)
			if flatRouteExitDelta.Magnitude > 0.1 then
				saving += flatRouteExitDelta.Unit:Dot(targetRoot.AssemblyLinearVelocity.Unit) * 0.35
			end
		end

		if saving > bestSaving then
			bestSaving = saving
			bestRoute = route
		end
	end

	return if bestSaving > 0.35 then bestRoute else nil
end

local function startTaggerRoute(route: RouteInfo)
	state.activeRoute = route
	state.activeRoutePractice = false
	state.activeRouteCursor = 1
	state.activeRouteStartTime = os.clock()
	state.routeAttemptVaults = 0
	state.routeAttemptSwings = 0
	state.routeAttemptRolls = 0
	state.routeActionAttemptCursor = 0
	state.routeActionAttemptName = nil
	state.lastRouteActionAttemptTime = 0
	state.lastRouteRecoveryJumpTime = 0
	state.routeVaultMissCursor = 0
	state.routeVaultMisses = 0
	state.routeVaultApproachSide = 1
	state.routePreVaultJumpCursor = 0
	state.lastRoutePreVaultJumpTime = 0
	state.routeLastProgressTime = os.clock()
	state.routeBestDistance = math.huge
	state.activeTechAttempt = nil
	table.clear(state.path)
	state.pathCursor = 1
	state.graphMoveTarget = nil
	state.graphMoveTech = nil
	pushLog(`Tagger using route: {route.name}.`)
end

local function updateTraining(dt: number)
	if not state.training then return end
	if not state.taggerEnabled then return end

	if not state.bot or not state.humanoid or not state.rootPart or not state.bot.Parent then spawnBot() end

	local humanoid = state.humanoid
	local rootPart = state.rootPart
	local routeMode = state.activeRoute ~= nil
	local targetRoot = if routeMode then nil else getTaggerTargetRoot()
	if not humanoid or not rootPart then return end
	if not routeMode and not targetRoot then return end
	if humanoid.Health <= 0 then return end

	if not routeMode and state.bot and isRunnerRole(getBotRole(state.bot)) then
		state.runnerEnabled = true
		state.runnerBot = state.bot
		state.runnerHumanoid = humanoid
		state.runnerRootPart = rootPart
		return
	end

	local speedMultiplier = math.clamp(state.trainingSpeedMultiplier * state.taggerSpeedMultiplier, 0.25, 4)
	humanoid.WalkSpeed = 32 * speedMultiplier
	humanoid.JumpPower = 28 * math.clamp(speedMultiplier, 0.75, 1.6)

	local now = os.clock()
	if not routeMode and now < state.chaseStartTime then
		humanoid:Move(Vector3.zero, false)
		if trainerUi then
			local countdown = math.max(0, state.chaseStartTime - now)
			trainerUi:setStatus(
				`Training: WAIT {math.floor(countdown * 10) / 10}s   Distance: --   Successes: {state.successes}   Attempts: {state.attempts}`
			)
		end
		return
	end

	if routeMode then
		RouteRuntime.updateActiveRoute(rootPart, humanoid, dt)
		return
	end

	local chaseTargetRoot = targetRoot :: BasePart
	local predictedTargetPosition = RouteRuntime.getPredictedTargetPosition(rootPart, chaseTargetRoot)
	if not state.guidedTraining and now - state.lastGraphDecisionTime >= Config.GRAPH_DECISION_INTERVAL_SECONDS then
		local usefulRoute = getUsefulTaggerRoute(rootPart, chaseTargetRoot, predictedTargetPosition)
		if usefulRoute then
			startTaggerRoute(usefulRoute)
			RouteRuntime.updateActiveRoute(rootPart, humanoid, dt)
			return
		end
	end
	local targetPosition = RouteRuntime.chooseMoveTarget(rootPart, chaseTargetRoot, predictedTargetPosition)
	finishTechAttempt(rootPart, targetPosition)
	local delta = targetPosition - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	local moveDirection = if flatDelta.Magnitude > 0.1 then flatDelta.Unit else Vector3.zero
	moveDirection = (moveDirection + getLearnedNudge(moveDirection))
	if moveDirection.Magnitude > 1 then moveDirection = moveDirection.Unit end
	moveDirection = steerAroundLocalObstacles(rootPart, moveDirection)
	moveDirection = chooseSidewaysMoveDirection(rootPart, moveDirection, targetPosition, false)

	humanoid:Move(moveDirection, false)
	if moveDirection.Magnitude > 0.05 then state.lastFaceDirection = turnBotToward(rootPart, moveDirection, state.lastFaceDirection, dt) end

		RouteRuntime.runGraphMoveTech(rootPart, humanoid, moveDirection, state.graphMoveTech)

		updateBotRoll(rootPart, humanoid, moveDirection)
		tryStuckClimbTech(rootPart, humanoid, targetPosition, moveDirection, state.stuckSeconds)
		tryRollSetupDrop(rootPart, humanoid, targetPosition, moveDirection)
		tryRollBoostJump(rootPart, humanoid, targetPosition, moveDirection)
		tryLocalGeometryVault(rootPart, humanoid, targetPosition, moveDirection)
	updateBotTrampoline(state.bot, rootPart, humanoid)
	local hadTechAttempt = state.activeTechAttempt ~= nil
	tryExperimentalTech(rootPart, humanoid, targetPosition, moveDirection)
	if hadTechAttempt or not state.activeTechAttempt then
		tryBasicJump(rootPart, humanoid, targetPosition, moveDirection)
		tryAerialParkour(rootPart, humanoid, moveDirection)
		trySlideBoost(rootPart, humanoid, targetPosition, moveDirection)
	end
	maybeTag(rootPart, chaseTargetRoot)
	BotRuntime.updateAnimations(state.bot, humanoid, rootPart)
	BotRuntime.updateMovementSounds(
		state.bot,
		humanoid,
		rootPart,
		Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude
	)

	if now - state.lastRewardTime >= Config.REWARD_INTERVAL_SECONDS then
		local distance = (chaseTargetRoot.Position - rootPart.Position).Magnitude
		local previousDistance = state.lastDistance or distance
		local reward = math.clamp(previousDistance - distance, -8, 8) * state.learnParams.progressWeight
			if state.lastCutoffKey then recordScore(state.cutoffScores, state.lastCutoffKey, reward) end
			state.lastPredictionError = (predictedTargetPosition - chaseTargetRoot.Position).Magnitude
		if state.lastPredictionError < 7 then
			reward += 1.5
		elseif state.lastPredictionError > 16 then
			reward -= 2
			end
			learnFromChasedPlayer(rootPart, chaseTargetRoot, predictedTargetPosition, reward)

		if now - state.lastChaseProgressCheckTime >= Config.CHASE_PROGRESS_CHECK_INTERVAL_SECONDS then
			local previousPosition = state.lastPosition or rootPart.Position
			local moved = (rootPart.Position - previousPosition).Magnitude
			local previousProgressDistance = state.lastChaseProgressDistance or distance
			local distanceProgress = previousProgressDistance - distance
			local noTargetProgress = state.lastChaseProgressDistance ~= nil and distanceProgress < 0.32
			local sampleDt = if state.lastChaseProgressCheckTime > 0
				then now - state.lastChaseProgressCheckTime
				else Config.CHASE_PROGRESS_CHECK_INTERVAL_SECONDS
			state.lastChaseProgressCheckTime = now
			state.lastPosition = rootPart.Position
			state.lastChaseProgressDistance = distance

			if moved < 1.1 or noTargetProgress then
				state.stuckSeconds += sampleDt
				reward -= if moved < 1.1 then 4 else 2.5
				if
					state.stuckSeconds > Config.CHASE_STUCK_REPLAN_SECONDS
					and now - state.lastChaseReplanTime >= Config.CHASE_REPLAN_COOLDOWN_SECONDS
				then
					state.lastChaseReplanTime = now
					if state.useGraph and #state.graph > 0 then
						local stuckNodeId = nearestNodeId(rootPart.Position, math.max(55, state.graphStep * 12))
						if stuckNodeId then
							local node = state.graph[stuckNodeId]
							node.visits += 1
							node.score += (-12 - node.score) / math.max(1, node.visits)
						end
						table.clear(state.path)
						state.pathCursor = 1
						state.lastPathTime = 0
						state.pathFailureUntil = now + 0.25
						state.graphMoveTarget = nil
						state.graphMoveTech = nil
						state.lastGraphDecisionTime = now - Config.GRAPH_DECISION_INTERVAL_SECONDS
						state.stuckSeconds = 0.65
						if state.debug then
							pushLog(if moved < 1.1 then "Tagger replan: physically stuck." else "Tagger replan: no chase progress.")
						end
					else
						tryBotJump(rootPart, humanoid, 24, nil, "Jump1")
						state.stuckSeconds = 0
					end
				end
			else
				state.stuckSeconds = 0
			end
		end

		addReward(rootPart.Position, moveDirection, reward)
		state.lastDistance = distance
		state.lastRewardTime = now
	end

	if dt > 0 and trainerUi then
		local fps = math.floor(1 / dt + 0.5)
		local distance = math.floor((chaseTargetRoot.Position - rootPart.Position).Magnitude * 10) / 10
		trainerUi:setStatus(
			`Training: {if state.training then "ON" else "OFF"}   FPS: {fps}   Distance: {distance}   You: {state.actionInfo.lastParkourName}   Successes: {state.successes}   Attempts: {state.attempts}`
		)
	end
end

local function abandonRunnerRoute(reason: string)
	if not state.runnerRoute then return end

	state.runnerRoute.failures = (state.runnerRoute.failures or 0) + 1
	RouteRuntime.setRouteCooldown(state.runnerRoute, Config.FAILED_ROUTE_COOLDOWN_SECONDS)
	pushLog(`Runner gave up route: {state.runnerRoute.name} ({reason}).`)
	state.runnerRoute = nil
	state.runnerRouteCursor = 1
	state.runnerRouteLastProgressTime = 0
	state.runnerRouteBestDistance = math.huge
	table.clear(state.runnerPath)
	state.runnerPathCursor = 1
	state.runnerGraphMoveTarget = nil
	state.runnerGraphMoveTech = nil
	state.runnerLastGraphDecisionTime = 0
	state.runnerPathFailureUntil = os.clock() + 0.12
end

local function updateRunnerTraining(dt: number)
	if not state.training or not state.runnerEnabled then return end
	if state.activeRoute then return end

	if not state.runnerBot or not state.runnerHumanoid or not state.runnerRootPart or not state.runnerBot.Parent then spawnRunnerBot() end

	local humanoid = state.runnerHumanoid
	local rootPart = state.runnerRootPart
	local threatRoot = getRunnerThreatRoot()
	if not humanoid or not rootPart or not threatRoot then return end
	if humanoid.Health <= 0 then return end
	if state.runnerBot and isTaggerRole(getBotRole(state.runnerBot)) then
		state.bot = state.runnerBot
		state.humanoid = humanoid
		state.rootPart = rootPart
		return
	end

	local speedMultiplier = math.clamp(state.trainingSpeedMultiplier * state.runnerSpeedMultiplier, 0.25, 4)
	humanoid.WalkSpeed = 33 * speedMultiplier
	humanoid.JumpPower = 28 * math.clamp(speedMultiplier, 0.75, 1.6)

	local now = os.clock()
	local away = rootPart.Position - threatRoot.Position
	local flatAway = Vector3.new(away.X, 0, away.Z)
	local threatDistance = flatAway.Magnitude
	local awayDirection = if flatAway.Magnitude > 0.1 then flatAway.Unit else rootPart.CFrame.LookVector
	local tangentDirection = Vector3.new(-awayDirection.Z, 0, awayDirection.X) * state.runnerLapSign
	local threatVelocity = Vector3.new(threatRoot.AssemblyLinearVelocity.X, 0, threatRoot.AssemblyLinearVelocity.Z)
	if
		threatDistance < 50
		and threatVelocity.Magnitude > 8
		and tangentDirection:Dot(threatVelocity.Unit) > 0.62
		and now - state.runnerLastLapSwitchTime > 0.85
	then
		state.runnerLapSign *= -1
		state.runnerLastLapSwitchTime = now
		tangentDirection *= -1
	end

	local awayWeight = if threatDistance < Config.TAG_RANGE * 3 then 0.78 elseif threatDistance < 55 then 0.48 else 0.28
	local lapWeight = if threatDistance < Config.TAG_RANGE * 3 then 0.45 elseif threatDistance < 55 then 0.78 else 0.95
	local blendedEscape = awayDirection * awayWeight + tangentDirection * lapWeight
	local moveDirection = if blendedEscape.Magnitude > 0.1 then blendedEscape.Unit else awayDirection
	local escapeProbePosition = rootPart.Position + moveDirection * 32
	local escapeTargetPosition = escapeProbePosition
	if state.runnerRoute then
		local routePoint = state.runnerRoute.points[state.runnerRouteCursor]
		if not routePoint then
			state.runnerRoute.successes = (state.runnerRoute.successes or 0) + 1
			state.runnerRoute = nil
			state.runnerRouteCursor = 1
			state.runnerRouteLastProgressTime = 0
			state.runnerRouteBestDistance = math.huge
		elseif (routePoint.position - rootPart.Position).Magnitude <= Config.ROUTE_REACHED_RADIUS then
			state.runnerRouteCursor += 1
			state.runnerRouteLastProgressTime = now
			state.runnerRouteBestDistance = math.huge
			routePoint = state.runnerRoute.points[state.runnerRouteCursor]
			if not routePoint then
				state.runnerRoute.successes = (state.runnerRoute.successes or 0) + 1
				state.runnerRoute = nil
				state.runnerRouteCursor = 1
				state.runnerRouteLastProgressTime = 0
				state.runnerRouteBestDistance = math.huge
			end
		end

		if routePoint then
			local routePointDistance = (routePoint.position - rootPart.Position).Magnitude
			local threatDistance = (threatRoot.Position - rootPart.Position).Magnitude
			if state.runnerRouteLastProgressTime <= 0 then
				state.runnerRouteLastProgressTime = now
				state.runnerRouteBestDistance = routePointDistance
			elseif routePointDistance + 0.8 < state.runnerRouteBestDistance then
				state.runnerRouteBestDistance = routePointDistance
				state.runnerRouteLastProgressTime = now
			elseif now - state.runnerRouteLastProgressTime > 1.25 or threatDistance < Config.TAG_RANGE * 2.4 then
				abandonRunnerRoute(if threatDistance < Config.TAG_RANGE * 2.4 then "tagger too close" else "no route progress")
				routePoint = nil
			end
		end

		if routePoint then
			local routeDelta = routePoint.position - rootPart.Position
			local flatRouteDelta = Vector3.new(routeDelta.X, 0, routeDelta.Z)
			if flatRouteDelta.Magnitude > 0.1 then
				moveDirection = flatRouteDelta.Unit
				escapeTargetPosition = routePoint.position
			end
		end
	elseif now - state.runnerLastGraphDecisionTime >= Config.GRAPH_DECISION_INTERVAL_SECONDS then
		local usefulRoute = if threatDistance > Config.TAG_RANGE * 3 then getUsefulRunnerRoute(rootPart, threatRoot) else nil
		if usefulRoute then
			state.runnerRoute = usefulRoute
			state.runnerRouteCursor = 1
			state.runnerRouteLastProgressTime = now
			state.runnerRouteBestDistance = math.huge
			state.runnerLastGraphDecisionTime = now
			pushLog(`Runner using taught route: {usefulRoute.name}.`)
		end
	end

	local escapeClearDistance = getClearDistance(rootPart, moveDirection)
	local runnerBlocked = escapeClearDistance < 3.2 or state.runnerStuckSeconds > 0.45
	local runnerNeedsRoute = state.useGraph
		and #state.graph > 0
		and state.runnerRoute == nil
		and (threatDistance < 85 or runnerBlocked or not hasDirectRoute(rootPart, escapeProbePosition))

	if runnerNeedsRoute and #state.runnerPath > 0 and now - state.runnerLastPathTime < Config.TARGET_REFRESH_SECONDS then
		while state.runnerPath[state.runnerPathCursor] do
			local node = state.graph[state.runnerPath[state.runnerPathCursor]]
			if not node then
				state.runnerPathCursor += 1
				continue
			end

			local nodeDelta = node.position - rootPart.Position
			local flatNodeDelta = Vector3.new(nodeDelta.X, 0, nodeDelta.Z)
			local passedNode = flatNodeDelta.Magnitude > 0.1 and moveDirection.Magnitude > 0.1 and flatNodeDelta.Unit:Dot(moveDirection.Unit) < -0.2

			if nodeDelta.Magnitude <= Config.RUNNER_GRAPH_PASS_RADIUS or passedNode then
				state.runnerPathCursor += 1
				continue
			end

			local previousNode = state.graph[state.runnerPath[math.max(1, state.runnerPathCursor - 1)]]
			state.runnerGraphMoveTech = if previousNode then previousNode.linkTechs[node.id] or "Move" else "Move"
				if flatNodeDelta.Magnitude > 0.1 then
					escapeTargetPosition = RouteRuntime.getRunnerGraphNavigationPosition(rootPart, node.position, moveDirection)
				local passDelta = escapeTargetPosition - rootPart.Position
				local flatPassDelta = Vector3.new(passDelta.X, 0, passDelta.Z)
				if flatPassDelta.Magnitude > 0.1 then moveDirection = flatPassDelta.Unit end
			end
			break
		end
	end

	if
		runnerNeedsRoute
		and now >= state.runnerPathFailureUntil
		and now - state.runnerLastPathTime >= Config.GRAPH_DECISION_INTERVAL_SECONDS
		and not state.runnerPath[state.runnerPathCursor]
	then
		local escapeGoal, escapeGoalId = getRunnerEscapeGoal(rootPart, threatRoot)
		if escapeGoal then
			if escapeGoalId and state.runnerLastEscapeGoalId == escapeGoalId then
				state.runnerEscapeGoalRepeat += 1
			else
				state.runnerLastEscapeGoalId = escapeGoalId
				state.runnerEscapeGoalRepeat = 0
			end
			state.runnerLastPathTime = now
			state.runnerLastGraphDecisionTime = now
			local nextNode, nextTech = chooseLightweightGraphHop(rootPart.Position, escapeGoal, moveDirection, "Escape", threatRoot.Position, true)
			if nextNode then
				table.clear(state.runnerPath)
				state.runnerPathCursor = 1
				state.runnerPathFailureUntil = 0
				state.runnerGraphMoveTarget = nextNode.position
				state.runnerGraphMoveTech = nextTech
			else
				table.clear(state.runnerPath)
				state.runnerPathCursor = 1
				state.runnerPathFailureUntil = now + Config.PATH_FAILURE_COOLDOWN_SECONDS
				state.runnerGraphMoveTech = nil
			end
		end
	end

	if state.runnerPath[state.runnerPathCursor] then
		local node = state.graph[state.runnerPath[state.runnerPathCursor]]
		if node then
			local previousNode = state.graph[state.runnerPath[math.max(1, state.runnerPathCursor - 1)]]
			state.runnerGraphMoveTech = if previousNode then previousNode.linkTechs[node.id] or "Move" else "Move"
			local nodeDelta = node.position - rootPart.Position
			local flatNodeDelta = Vector3.new(nodeDelta.X, 0, nodeDelta.Z)
			if flatNodeDelta.Magnitude > 0.1 then
				escapeTargetPosition = RouteRuntime.getRunnerGraphNavigationPosition(rootPart, node.position, moveDirection)
				local passDelta = escapeTargetPosition - rootPart.Position
				local flatPassDelta = Vector3.new(passDelta.X, 0, passDelta.Z)
				if flatPassDelta.Magnitude > 0.1 then moveDirection = flatPassDelta.Unit end
			end
		end
	end

	if
		state.runnerRoute == nil
		and state.useGraph
		and #state.graph > 0
		and not runnerNeedsRoute
		and now - state.runnerLastGraphDecisionTime >= Config.GRAPH_DECISION_INTERVAL_SECONDS
	then
		local nextNode, nextTech = chooseLightweightGraphHop(rootPart.Position, escapeProbePosition, moveDirection, "Escape", threatRoot.Position, false)
		state.runnerLastGraphDecisionTime = now
		if nextNode then
			state.runnerGraphMoveTarget = nextNode.position
			state.runnerGraphMoveTech = nextTech
			if state.runnerLastEscapeGoalId == nextNode.id then
				state.runnerEscapeGoalRepeat += 1
			else
				state.runnerLastEscapeGoalId = nextNode.id
				state.runnerEscapeGoalRepeat = 0
			end
		end
	end

	if state.runnerRoute == nil and state.runnerGraphMoveTarget then
		local nodeDelta = state.runnerGraphMoveTarget - rootPart.Position
		if nodeDelta.Magnitude < Config.RUNNER_GRAPH_PASS_RADIUS then
			state.runnerGraphMoveTarget = nil
			state.runnerGraphMoveTech = nil
		else
			local flatNodeDelta = Vector3.new(nodeDelta.X, 0, nodeDelta.Z)
				if flatNodeDelta.Magnitude > 0.1 then
					escapeTargetPosition =
						RouteRuntime.getRunnerGraphNavigationPosition(rootPart, state.runnerGraphMoveTarget, moveDirection)
				local passDelta = escapeTargetPosition - rootPart.Position
				local flatPassDelta = Vector3.new(passDelta.X, 0, passDelta.Z)
				if flatPassDelta.Magnitude > 0.1 then moveDirection = flatPassDelta.Unit end
			end
		end
	end

	moveDirection = moveDirection + getRunnerLearnedNudge(moveDirection)
	if moveDirection.Magnitude > 1 then moveDirection = moveDirection.Unit end
	moveDirection = steerRunnerAroundLocalObstacles(rootPart, moveDirection)
	moveDirection = chooseSidewaysMoveDirection(rootPart, moveDirection, escapeTargetPosition, true)
	humanoid:Move(moveDirection, false)

	if moveDirection.Magnitude > 0.05 then
		state.runnerLastFaceDirection = turnBotToward(rootPart, moveDirection, state.runnerLastFaceDirection, dt)
	end

		local clearDistance = getClearDistance(rootPart, moveDirection)
		RouteRuntime.runGraphMoveTech(rootPart, humanoid, moveDirection, state.runnerGraphMoveTech)
		updateBotRoll(rootPart, humanoid, moveDirection)
		tryStuckClimbTech(rootPart, humanoid, escapeTargetPosition, moveDirection, state.runnerStuckSeconds)
		tryRollSetupDrop(rootPart, humanoid, escapeTargetPosition, moveDirection)
		tryRollBoostJump(rootPart, humanoid, escapeTargetPosition, moveDirection)
		tryLocalGeometryVault(rootPart, humanoid, escapeTargetPosition, moveDirection)
	finishTechAttempt(rootPart, escapeTargetPosition)
	local hadTechAttempt = state.activeTechAttempt ~= nil
	tryExperimentalTech(rootPart, humanoid, escapeTargetPosition, moveDirection)
	if hadTechAttempt or not state.activeTechAttempt then
		tryBasicJump(rootPart, humanoid, escapeTargetPosition, moveDirection)
		tryAerialParkour(rootPart, humanoid, moveDirection)
		trySlideBoost(rootPart, humanoid, escapeTargetPosition, moveDirection)
	end
	if clearDistance < 2.8 and humanoid.FloorMaterial ~= Enum.Material.Air then tryBotJump(rootPart, humanoid, 24, nil, "Jump1") end
	updateBotTrampoline(state.runnerBot, rootPart, humanoid)
	BotRuntime.updateAnimations(state.runnerBot, humanoid, rootPart)
	BotRuntime.updateMovementSounds(
		state.runnerBot,
		humanoid,
		rootPart,
		Vector3.new(rootPart.AssemblyLinearVelocity.X, 0, rootPart.AssemblyLinearVelocity.Z).Magnitude
	)

	if now - state.runnerLastRewardTime >= Config.REWARD_INTERVAL_SECONDS then
		local distance = (threatRoot.Position - rootPart.Position).Magnitude
		local previousDistance = state.runnerLastDistance or distance
		local reward = math.clamp(distance - previousDistance, -8, 8) * state.learnParams.progressWeight * state.learnParams.runnerDistanceWeight
		if distance < Config.TAG_RANGE * 2 then
			reward -= 8
		elseif distance > 45 then
			reward += 2
		end
		if state.runnerGraphMoveTarget and #state.runnerPath == 0 then
			local futureThreatDistance = (state.runnerGraphMoveTarget - threatRoot.Position).Magnitude
			if futureThreatDistance > distance + 18 then
				reward += 1.5
			end
		end
		if clearDistance < 2.2 then
			reward -= 4
		end
		if state.runnerLastEscapeGoalId then
			local escapeNode = state.graph[state.runnerLastEscapeGoalId]
			if escapeNode then
				local nodeReward = reward
				if state.runnerRoute then
					nodeReward *= 0.35
				end
				escapeNode.visits += 1
				escapeNode.score += (nodeReward - escapeNode.score) / math.max(1, escapeNode.visits)
			end
		end
		local previousPosition = state.runnerLastPosition or rootPart.Position
		local moved = (rootPart.Position - previousPosition).Magnitude
		local distanceProgress = distance - previousDistance
		local graphProgress = math.huge
		if state.runnerGraphMoveTarget then
			graphProgress = (state.runnerGraphMoveTarget - previousPosition).Magnitude - (state.runnerGraphMoveTarget - rootPart.Position).Magnitude
		end
		local noEscapeProgress = state.runnerLastDistance ~= nil
			and distance < 62
			and distanceProgress < 0.12
			and (not state.runnerGraphMoveTarget or graphProgress < 0.12)

		if (moved < 0.55 or noEscapeProgress) and state.runnerRoute == nil and (state.runnerGraphMoveTarget or #state.runnerPath > 0) then
			table.clear(state.runnerPath)
			state.runnerPathCursor = 1
			state.runnerGraphMoveTarget = nil
			state.runnerGraphMoveTech = nil
			state.runnerLastGraphDecisionTime = 0
			state.runnerPathFailureUntil = now + 0.18
		end
		if moved < 0.55 or noEscapeProgress then
			local sampleDt = if state.runnerLastRewardTime > 0 then now - state.runnerLastRewardTime else Config.REWARD_INTERVAL_SECONDS
			state.runnerStuckSeconds += sampleDt
			reward -= if moved < 0.55 then 6 else 3.5
			if state.runnerStuckSeconds > 1.1 then
				local stuckNodeId = nearestNodeId(rootPart.Position, math.max(55, state.graphStep * 12))
				if stuckNodeId then
					local node = state.graph[stuckNodeId]
					node.visits += 1
					node.score += (-18 - node.score) / math.max(1, node.visits)
				end
				if state.runnerRoute then abandonRunnerRoute("stuck") end
				state.runnerLapSign *= -1
				state.runnerLastLapSwitchTime = now
				table.clear(state.runnerPath)
				state.runnerPathCursor = 1
				state.runnerGraphMoveTarget = nil
				state.runnerGraphMoveTech = nil
				state.runnerPathFailureUntil = 0
				invalidateRunnerPathRequest()
					if state.useGraph and #state.graph > 0 then
						local escapeGoal, escapeGoalId = getRunnerEscapeGoal(rootPart, threatRoot)
						if escapeGoal then
							state.runnerLastPathTime = 0
							state.runnerLastEscapeGoalId = escapeGoalId
							local nextNode, nextTech = chooseLightweightGraphHop(rootPart.Position, escapeGoal, moveDirection, "Escape", threatRoot.Position, true)
							if nextNode then
								state.runnerGraphMoveTarget = nextNode.position
								state.runnerGraphMoveTech = nextTech
							end
						end
					end
				tryBotJump(rootPart, humanoid, 27, moveDirection * 6, "Jump1")
				if state.debug then pushLog(if moved < 0.55 then "Runner replan: physically stuck." else "Runner replan: no escape progress.") end
				state.runnerStuckSeconds = 0
			end
		else
			state.runnerStuckSeconds = 0
		end

		addRunnerReward(rootPart.Position, moveDirection, reward)
		state.runnerLastDistance = distance
		state.runnerLastPosition = rootPart.Position
		state.runnerLastRewardTime = now
	end

	if dt > 0 and trainerUi and state.targetMode == "AI" then
		local distance = math.floor((threatRoot.Position - rootPart.Position).Magnitude * 10) / 10
		trainerUi:setStatus(
			`Training: AI   Gap: {distance}   Speed: {state.trainingSpeedMultiplier}x   Selected: {state.selectedAI}   Successes: {state.successes}`
		)
	end
end

local function clearLearning()
	table.clear(state.directionScores)
	table.clear(state.runnerDirectionScores)
	table.clear(state.slideBoostScores)
	table.clear(state.techScores)
	table.clear(state.routeTechNotes)
	table.clear(state.geometryScores)
	table.clear(state.policyWeights)
	table.clear(state.playerModelScores)
	table.clear(state.selfTaughtRouteCandidates)
	table.clear(localGeometryCache)
	state.activeTechAttempt = nil
	table.clear(state.cutoffScores)
	for _, node in state.graph do
		node.score = 0
		node.visits = 0
	end

	state.slideBoostCancelDelay = 0.52
	state.slideBoostJumpDelay = 0.12
	state.slideBoostKey = nil
	state.successes = 0
	state.attempts = 0
	state.lastDistance = nil
	state.stuckSeconds = 0
	state.runnerStuckSeconds = 0
	state.runnerLastEscapeGoalId = nil
	state.runnerEscapeGoalRepeat = 0
	state.runnerRoute = nil
	state.runnerRouteCursor = 1
	state.runnerRouteLastProgressTime = 0
	state.runnerRouteBestDistance = math.huge
	pushLog("Cleared learned scores and counters.")
end

local function printGraph()
	local payload = {
		map = workspace:GetAttribute("Map") or "Unknown",
		step = state.graphStep,
		nodes = {},
	}

	for _, node in state.graph do
		table.insert(payload.nodes, {
			id = node.id,
			x = math.floor(node.position.X * 100 + 0.5) / 100,
			y = math.floor(node.position.Y * 100 + 0.5) / 100,
			z = math.floor(node.position.Z * 100 + 0.5) / 100,
			links = node.links,
			score = math.floor(node.score * 100 + 0.5) / 100,
			visits = node.visits,
			barrierPenalty = math.floor(node.barrierPenalty * 100 + 0.5) / 100,
			deadEndPenalty = math.floor(node.deadEndPenalty * 100 + 0.5) / 100,
			wallPenalty = math.floor(node.wallPenalty * 100 + 0.5) / 100,
			openDirections = node.openDirections,
		})
	end

	print("[BotTrainer] GRAPH_EXPORT_BEGIN")
	print(HttpService:JSONEncode(payload))
	print("[BotTrainer] GRAPH_EXPORT_END")
	pushLog(`Printed {#state.graph} graph nodes to output.`)
end

resetActiveRouteToStart = function(reason: string)
	if routeEditor then routeEditor.resetActiveRouteToStart(reason) end
end

dragSelectedRoutePointToMouse = function()
	if routeEditor then routeEditor.dragSelectedRoutePointToMouse() end
end

setEditorOpen = function(open: boolean)
	state.editorOpen = open
	refreshRouteMarkers()
	refreshControlButtons()
end

local function init()
	if not trainerUi then
		local result = BotTrainerBootstrap.create {
			state = state,
			localPlayer = localPlayer,
			raycastParams = raycastParams,
			persistence = persistence,
			routeEditor = routeEditor,
			chaseStartDelaySeconds = Config.CHASE_START_DELAY_SECONDS,
			getIgnoreList = getIgnoreList,
			refreshRouteMarkers = refreshRouteMarkers,
			refreshControlButtons = refreshControlButtons,
			pushLog = pushLog,
			spawnBot = spawnBot,
			spawnRunnerBot = spawnRunnerBot,
			buildGraph = buildGraph,
			printGraph = printGraph,
			clearLearning = clearLearning,
			getSelectedRoleName = getSelectedRoleName,
			getSelectedEnabled = getSelectedEnabled,
			setSelectedEnabled = setSelectedEnabled,
			getSelectedSpeedMultiplier = getSelectedSpeedMultiplier,
			setSelectedSpeedMultiplier = setSelectedSpeedMultiplier,
			setEditorOpen = setEditorOpen,
				startGuidedTraining = startGuidedTraining,
				teachTechHint = teachTechHint,
				teachClimbableWall = teachClimbableWall,
			}
		trainerUi = result.trainerUi
		persistence = result.persistence
		routeEditor = result.routeEditor

		refreshControlButtons()
		pushLog("Ready. Spawn the bot, build graph, then start training.")
	end

	bindPlayerActionTracking()
	spawnBot()
	if persistence then task.spawn(persistence.retrieveTrainingData) end

		heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
			local aiStep = 1 / 60
			aiUpdateAccumulator = math.min(aiUpdateAccumulator + dt, aiStep * 3)
			if aiUpdateAccumulator < aiStep then return end
			aiUpdateAccumulator -= aiStep
			dt = aiStep

			updateGuidedTraining()
			updateTraining(dt)
			updateRunnerTraining(dt)
			RouteRuntime.refreshGraphVisualization()
			RouteRuntime.refreshPathVisualization()
			if state.training and not state.guidedTraining and os.clock() - state.lastAutoSaveTime >= Config.AUTO_SAVE_INTERVAL_SECONDS then
				state.lastAutoSaveTime = os.clock()
				if persistence then
					persistence.saveLearningVersion("tagger", false)
					if state.runnerEnabled then persistence.saveLearningVersion("runner", false) end
				end
			end
			if trainerUi then trainerUi:updateGui(getTargetRoot()) end
		end)

	localPlayer.CharacterAdded:Connect(function()
		task.wait(1)
		if state.bot then spawnBot() end
	end)

	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Bot Trainer",
			Text = "Local tagger AI trainer loaded.",
			Duration = 4,
		})
	end)
end

return require(ReplicatedStorage.Shared.Schedules).Boot.job(init)
