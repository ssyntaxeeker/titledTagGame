--!strict
--[[
    BotRuntime (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Lifecycle coordinator for the rebuilt bot stack. Map building, affordance
    generation, planning, decisions, skills, persistence, and debug rendering
    each own an independent frame budget or update cadence.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Packages.Net)
local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local BotAffordanceBuilder = require(ReplicatedStorage.Modules.Bot.BotAffordanceBuilder)
local BotAgent = require(ReplicatedStorage.Modules.Bot.BotAgent)
local Config = require(ReplicatedStorage.Modules.Bot.BotNavigationConfig)
local BotDebugRenderer = require(ReplicatedStorage.Modules.Bot.BotDebugRenderer)
local BotExplorationSwarm = require(ReplicatedStorage.Modules.Bot.BotExplorationSwarm)
local BotMapModel = require(ReplicatedStorage.Modules.Bot.BotMapModel)
local BotOnlinePolicyTrainer = require(ReplicatedStorage.Modules.Bot.BotOnlinePolicyTrainer)
local BotPolicy = require(ReplicatedStorage.Modules.Bot.BotPolicy)
local BotPlayerLearningObserver = require(ReplicatedStorage.Modules.Bot.BotPlayerLearningObserver)
local BotPresentation = require(ReplicatedStorage.Modules.Bot.BotPresentation)
local BotRouteMemory = require(ReplicatedStorage.Modules.Bot.BotRouteMemory)
local BotRouteTeaching = require(ReplicatedStorage.Modules.Bot.BotRouteTeaching)
local BotTelemetry = require(ReplicatedStorage.Modules.Bot.BotTelemetry)
local BotTechDrill = require(ReplicatedStorage.Modules.Bot.BotTechDrill)
local BotTrainingRecorder = require(ReplicatedStorage.Modules.Bot.BotTrainingRecorder)
local KnockbackVelocity = require(ReplicatedStorage.Modules.FX.KnockbackVelocity)
local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type BotRole = Types.BotRole
type RAffordanceGraph = Types.RAffordanceGraph
type RAgent = BotAgent.RAgent
type RMapBuildJob = BotMapModel.RBuildJob
type RPolicyJob = BotOnlinePolicyTrainer.RJob
type RAffordanceBuildJob = BotAffordanceBuilder.RBuildJob
type RMemory = BotRouteMemory.RMemory
type RRecorder = BotTrainingRecorder.RRecorder
type RRenderer = BotDebugRenderer.RRenderer
type RPlayerObserver = BotPlayerLearningObserver.RState
type RSwarm = BotExplorationSwarm.RState
type RTelemetry = BotTelemetry.RState
type RTechDrill = BotTechDrill.RState
type RRouteTeaching = BotRouteTeaching.RState

type RuntimeState = {
	mapJob: RMapBuildJob?,
	affordanceJob: RAffordanceBuildJob?,
	graph: RAffordanceGraph?,
	graphActionSummary: string,
	memory: RMemory,
	memorySnapshot: { [string]: { attempts: number, successes: number, reward: number, timingSum: number } },
	playerRouteSnapshot: { [string]: number },
	areaSnapshot: { [string]: number },
	memoryLoaded: boolean,
	memoryLoadStarted: boolean,
	memorySaving: boolean,
	memorySaveQueued: boolean,
	memorySaveReason: string?,
	lastMemorySaveAt: number,
	mainAgent: RAgent?,
	opponentAgent: RAgent?,
	mainAnimationCleanup: (() -> ())?,
	opponentAnimationCleanup: (() -> ())?,
	enabled: boolean,
	duelMode: boolean,
	selectedRole: BotRole,
	status: string,
	logs: { string },
	recorder: RRecorder,
	renderer: RRenderer,
	lastVisualRefreshAt: number,
	visualSignature: string,
	manualStart: Vector3?,
	manualGoal: Vector3?,
	manualTarget: Part?,
	manualStartMarker: Part?,
	manualGoalMarker: Part?,
	manualRun: boolean,
	manualAttemptActive: boolean,
	manualAttemptStartedAt: number,
	manualResetAt: number,
	manualTimeLimit: number,
	manualTimeFloor: number,
	manualBestTime: number?,
	manualAttemptCount: number,
	manualSuccessCount: number,
	manualFailureCount: number,
	connection: RBXScriptConnection?,
	localBotTaggedConnection: RBXScriptConnection?,
	lastTagTimes: { [Model]: number },
	playerObserver: RPlayerObserver,
	lastPlayerLearningDistance: number?,
	swarm: RSwarm,
	policyJob: RPolicyJob?,
	policyTrainingStatus: string,
	policyLoaded: boolean,
	telemetry: RTelemetry,
	techDrill: RTechDrill,
	routeTeaching: RRouteTeaching,
}

local BotRuntime = {}
local localPlayer = Players.LocalPlayer
local RetrieveBotLightweightMemoryRF = Net:RemoteFunction("RetrieveBotLightweightMemory")
local SaveBotLightweightMemoryRF = Net:RemoteFunction("SaveBotLightweightMemory")
local RetrieveBotRuntimePolicyRF = Net:RemoteFunction("RetrieveBotRuntimePolicy")
local SaveBotRuntimePolicyRF = Net:RemoteFunction("SaveBotRuntimePolicy")
local BotTagRF = Net:RemoteFunction("BotTag")

local state: RuntimeState = {
	mapJob = nil,
	affordanceJob = nil,
	graph = nil,
	graphActionSummary = "not ready",
	memory = BotRouteMemory.create(),
	memorySnapshot = {},
	playerRouteSnapshot = {},
	areaSnapshot = {},
	memoryLoaded = false,
	memoryLoadStarted = false,
	memorySaving = false,
	memorySaveQueued = false,
	memorySaveReason = nil,
	lastMemorySaveAt = 0,
	mainAgent = nil,
	opponentAgent = nil,
	mainAnimationCleanup = nil,
	opponentAnimationCleanup = nil,
	enabled = false,
	duelMode = false,
	selectedRole = "Tagger",
	status = "Idle",
	logs = {},
	recorder = BotTrainingRecorder.create(5000),
	renderer = BotDebugRenderer.create(),
	lastVisualRefreshAt = 0,
	visualSignature = "",
	manualStart = nil,
	manualGoal = nil,
	manualTarget = nil,
	manualStartMarker = nil,
	manualGoalMarker = nil,
	manualRun = false,
	manualAttemptActive = false,
	manualAttemptStartedAt = 0,
	manualResetAt = 0,
	manualTimeLimit = 0,
	manualTimeFloor = 0,
	manualBestTime = nil,
	manualAttemptCount = 0,
	manualSuccessCount = 0,
	manualFailureCount = 0,
	connection = nil,
	localBotTaggedConnection = nil,
	lastTagTimes = {},
	playerObserver = BotPlayerLearningObserver.create(),
	lastPlayerLearningDistance = nil,
	swarm = BotExplorationSwarm.create(),
	policyJob = nil,
	policyTrainingStatus = "idle",
	policyLoaded = false,
	telemetry = BotTelemetry.create(),
	techDrill = BotTechDrill.create(),
	routeTeaching = BotRouteTeaching.create(),
}

local function pushLog(message: string)
	state.logs[#state.logs + 1] = `{math.floor(os.clock() * 10) / 10}s {message}`
	if #state.logs > 200 then table.remove(state.logs, 1) end
end

local function createManualMarker(name: string, position: Vector3, color: Color3, text: string): Part
	local marker = Instance.new("Part")
	marker.Name = name
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.one * 1.25
	marker.Position = position
	marker.Color = color
	marker.Material = Enum.Material.Neon
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Parent = state.renderer.folder
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(150, 24)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 500
	billboard.Parent = marker
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.Text = text
	label.TextColor3 = color
	label.TextSize = 13
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard
	return marker
end

local function normalizeRole(roleName: string): BotRole?
	if roleName == "Tagger" or roleName == "Peasant" then return "Tagger" end
	if roleName == "Runner" or roleName == "Crown" then return "Runner" end
	return nil
end

local function getPlayerRoot(): BasePart?
	local character = localPlayer.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if rootPart and rootPart:IsA("BasePart") then rootPart else nil
end

local function getRoleInfo(roleName: string): { [string]: any }?
	local module = ReplicatedStorage.Shared.Configs.Roles:FindFirstChild(roleName)
	if not module or not module:IsA("ModuleScript") then return nil end
	return require(module)
end

local function canTag(taggerRole: string, targetRole: string): (boolean, string?, string?)
	local info = getRoleInfo(taggerRole)
	if not info or typeof(info.canTagRoles) ~= "table" or not table.find(info.canTagRoles, targetRole) then return false, nil, nil end
	return true, info.onTagBecomes, info.onTagGives
end

local RANK_WEIGHTS = table.freeze({ C = 0.75, ["B-"] = 0.9, B = 1, ["B+"] = 1.1, ["A-"] = 1.2, A = 1.35, ["A+"] = 1.5, S = 1.75 })

local function getPlayerSampleWeight(): number
	local rank = tostring(localPlayer:GetAttribute("Rank") or "C")
	local stars = tonumber(localPlayer:GetAttribute("Stars")) or 0
	return (RANK_WEIGHTS[rank] or 0.75) * (1 + math.clamp(stars, 0, 5) * 0.08)
end

local function recordExperience(
	graph: RAffordanceGraph,
	edgeId: number,
	role: BotRole,
	succeeded: boolean,
	reward: number,
	duration: number,
	goalPosition: Vector3?,
	source: string?,
	weightMultiplier: number?
)
	local edge = graph.edges[edgeId]
	if not edge then return end
	BotTelemetry.recordTransition(state.telemetry, edge.action, role, succeeded, reward, duration)
	if not BotTrainingRecorder.isEnabled(state.recorder) then return end
	local from = graph.mapModel.nodes[edge.from]
	local to = graph.mapModel.nodes[edge.to]
	local goalNode = { rootPosition = goalPosition or to.rootPosition }
	local legacyEdge = {
		action = edge.action,
	}
	local features = BotPolicy.makeFeatures(
		role,
		{ position = from.rootPosition, openness = from.openDirections / 4, escapeScore = from.openDirections, openDirections = from.openDirections, wallPenalty = 4 - from.openDirections },
		{ position = to.rootPosition, openness = to.openDirections / 4, escapeScore = to.openDirections, openDirections = to.openDirections, wallPenalty = 4 - to.openDirections },
		legacyEdge,
		{ position = goalNode.rootPosition },
		if to.isBarrierAdjacent then 10 else 0,
		BotRouteMemory.getAreaScore(state.memory, to.rootPosition, role),
		Config.botWalkSpeed
	)
	BotTrainingRecorder.record(state.recorder, {
		role = role,
		action = edge.action,
		reward = reward,
		nodeId = edge.from,
		targetNodeId = edge.to,
		features = features,
		createdAt = os.time(),
		weight = getPlayerSampleWeight() * (weightMultiplier or 1),
		mapName = tostring(Workspace:GetAttribute("Map") or "Unknown"),
		source = source or "Bot",
	})
end

local function applyMemory(raw: any)
	if typeof(raw) ~= "table" then return end
	local processed = 0
	local attempts = if typeof(raw.techAttempts) == "table" then raw.techAttempts else {}
	local rewards = if typeof(raw.techScores) == "table" then raw.techScores else {}
	local successes = if typeof(raw.edgeScores) == "table" then raw.edgeScores else {}
	local timingSums = if typeof(raw.timingSums) == "table" then raw.timingSums else {}
	local timingSuccesses = if typeof(raw.timingSuccesses) == "table" then raw.timingSuccesses else {}
	for key, attemptValue in attempts do
		if typeof(key) ~= "string" then continue end
		local attemptCount = math.max(0, math.floor(tonumber(attemptValue) or 0))
		state.memory.edges[key] = {
			attempts = attemptCount,
			successes = math.clamp(math.floor(tonumber(successes[key]) or 0), 0, attemptCount),
			reward = tonumber(rewards[key]) or 0,
			meanDuration = 0,
			meanTiming = (tonumber(timingSums[key]) or 0) / math.max(1, tonumber(timingSuccesses[key]) or 0),
		}
		state.memorySnapshot[key] = {
			attempts = attemptCount,
			successes = state.memory.edges[key].successes,
			reward = state.memory.edges[key].reward,
			timingSum = tonumber(timingSums[key]) or 0,
		}
		if string.sub(key, 1, 8) == "General:" then state.memory.evidenceCount += attemptCount end
		processed += 1
		if processed % Config.memoryApplyYieldBatch == 0 then task.wait() end
	end
	if typeof(raw.areaScores) == "table" then
		for key, value in raw.areaScores do
			if typeof(key) == "string" and tonumber(value) then
				state.memory.areas[key] = tonumber(value) :: number
					state.areaSnapshot[key] = tonumber(value) :: number
					processed += 1
					if processed % Config.memoryApplyYieldBatch == 0 then task.wait() end
				end
		end
	end
	if typeof(raw.playerRouteScores) == "table" then
		for key, value in raw.playerRouteScores do
			if typeof(key) == "string" and tonumber(value) then
				state.memory.playerRoutes[key] = tonumber(value) :: number
					state.playerRouteSnapshot[key] = tonumber(value) :: number
					processed += 1
					if processed % Config.memoryApplyYieldBatch == 0 then task.wait() end
				end
		end
	end
	state.memoryLoaded = true
end

local function loadMemory()
	if state.memoryLoadStarted then return end
	state.memoryLoadStarted = true
		task.spawn(function()
			local success, raw = pcall(function()
				return RetrieveBotLightweightMemoryRF:InvokeServer()
		end)
		if success then
			applyMemory(raw)
			local keyCount = 0
			for _ in state.memory.edges do keyCount += 1 end
			pushLog(`Loaded global navigation memory ({keyCount} aggregate keys).`)
		else
			state.memoryLoaded = true
				pushLog(`Global memory load failed: {tostring(raw)}`)
			end
			local policySuccess, policyInfo = pcall(function()
				return RetrieveBotRuntimePolicyRF:InvokeServer()
			end)
			if policySuccess and typeof(policyInfo) == "table" and typeof(policyInfo.model) == "table" then
				local installed, installError = pcall(function()
					BotPolicy.setModel(policyInfo.model)
				end)
				if installed then
					state.policyTrainingStatus = `loaded global v{policyInfo.model.version}`
					pushLog(`Loaded global runtime policy v{policyInfo.model.version}.`)
				else
					state.policyTrainingStatus = "global policy rejected"
					pushLog(`Global runtime policy was invalid: {tostring(installError)}`)
				end
			else
				state.policyTrainingStatus = "using bundled policy"
			end
			state.policyLoaded = true
		end)
end

local function updatePolicyTraining()
	local job = state.policyJob
	if not job then return end
	local finished = BotOnlinePolicyTrainer.step(job, Config.onlinePolicyBudgetSeconds)
	state.policyTrainingStatus = BotOnlinePolicyTrainer.getProgress(job)
	if not finished then return end
	state.policyJob = nil
	if not job.accepted then
		pushLog(`Runtime policy rejected: validation loss {job.validationLoss}, baseline {job.baselineLoss}.`)
		return
	end
	BotPolicy.setModel(job.model)
	pushLog(`Installed runtime policy v{job.model.version}; saving validated output head.`)
	task.spawn(function()
		local success, result = pcall(function()
			return SaveBotRuntimePolicyRF:InvokeServer({
				model = job.model,
				sampleCount = #job.samples,
				baselineLoss = job.baselineLoss,
				validationLoss = job.validationLoss,
			})
		end)
		if success and result then
			state.policyTrainingStatus = `saved global v{job.model.version}`
			pushLog(`Saved global runtime policy v{job.model.version}.`)
		else
			state.policyTrainingStatus = "installed locally; server save failed"
			pushLog(`Runtime policy save failed: {tostring(result)}`)
		end
	end)
end

local function saveMemory(force: boolean, reason: string?)
	if state.memorySaving then
		if force then
			state.memorySaveQueued = true
			state.memorySaveReason = reason or state.memorySaveReason or "forced memory update"
			pushLog(`Global memory save queued: {state.memorySaveReason}.`)
		end
		return
	end
	if not state.memory.dirty then
		if force and reason then pushLog(`Global memory is already current after {reason}.`) end
		return
	end
	if not force and os.clock() - state.lastMemorySaveAt < 30 then return end
	state.memorySaving = true
	state.lastMemorySaveAt = os.clock()
	local saveReason = reason
	task.spawn(function()
		local payload = {
			techAttempts = {},
			techScores = {},
			edgeScores = {},
			areaScores = {},
			playerRouteScores = {},
			timingSums = {},
			timingSuccesses = {},
		}
		local changes = 0
		local scanned = 0
		for key, stat in state.memory.edges do
			local old = state.memorySnapshot[key]
				or { attempts = 0, successes = 0, reward = 0, timingSum = 0 }
			local attemptDelta = stat.attempts - old.attempts
			local successDelta = stat.successes - old.successes
			local rewardDelta = stat.reward - old.reward
			if attemptDelta > 0 or successDelta > 0 or math.abs(rewardDelta) >= 0.001 then
				payload.techAttempts[key] = attemptDelta
				payload.edgeScores[key] = successDelta
				payload.techScores[key] = rewardDelta
				local timingSum = stat.meanTiming * stat.successes
				local timingDelta = timingSum - old.timingSum
				if timingDelta > 0 then payload.timingSums[key] = timingDelta end
				if successDelta > 0 then payload.timingSuccesses[key] = successDelta end
				changes += 1
				if changes >= 300 then break end
			end
			scanned += 1
			if scanned % Config.memoryApplyYieldBatch == 0 then task.wait() end
		end
		for key, value in state.memory.areas do
			if changes >= 300 then break end
			local delta = value - (state.areaSnapshot[key] or 0)
			if math.abs(delta) >= 0.001 then
				payload.areaScores[key] = delta
				changes += 1
			end
			scanned += 1
			if scanned % Config.memoryApplyYieldBatch == 0 then task.wait() end
		end
		for key, value in state.memory.playerRoutes do
			if changes >= 300 then break end
			local delta = value - (state.playerRouteSnapshot[key] or 0)
			if delta > 0 then
				payload.playerRouteScores[key] = delta
				changes += 1
			end
			scanned += 1
			if scanned % Config.memoryApplyYieldBatch == 0 then task.wait() end
		end
		if changes == 0 then
			state.memory.dirty = false
			state.memorySaving = false
			return
		end
		local success, result = pcall(function()
			return SaveBotLightweightMemoryRF:InvokeServer(payload)
		end)
		state.memorySaving = false
		if success and result then
			for key, attemptDelta in payload.techAttempts do
				local old = state.memorySnapshot[key] or { attempts = 0, successes = 0, reward = 0, timingSum = 0 }
				state.memorySnapshot[key] = {
					attempts = old.attempts + attemptDelta,
					successes = old.successes + (payload.edgeScores[key] or 0),
					reward = old.reward + (payload.techScores[key] or 0),
					timingSum = old.timingSum + (payload.timingSums[key] or 0),
				}
			end
			for key, delta in payload.playerRouteScores do
				state.playerRouteSnapshot[key] = (state.playerRouteSnapshot[key] or 0) + delta
			end
			for key, delta in payload.areaScores do
				state.areaSnapshot[key] = (state.areaSnapshot[key] or 0) + delta
			end
			-- Keep the dirty flag until a later pass proves that no changes remain;
			-- explorers can add evidence while this remote invocation is in flight.
			state.memory.dirty = true
			pushLog(`Saved {changes} navigation aggregates globally{if saveReason then ` ({saveReason})` else ""}. No policy rebuild is required.`)
			local queued = state.memorySaveQueued
			local queuedReason = state.memorySaveReason
			state.memorySaveQueued = false
			state.memorySaveReason = nil
			if queued or changes >= 300 then
				task.delay(0.1, function()
					saveMemory(true, queuedReason or saveReason or "remaining memory batch")
				end)
			end
		else
			pushLog(`Global memory save failed: {tostring(result)}`)
		end
	end)
end

local function destroyAgent(agent: RAgent?, cleanup: (() -> ())?)
	if cleanup then cleanup() end
	if agent then BotAgent.destroy(agent) end
end

local function attachGraph(agent: RAgent?)
	if agent then BotAgent.setGraph(agent, state.graph) end
end

local function spawnMainAgent()
	destroyAgent(state.mainAgent, state.mainAnimationCleanup)
	state.lastPlayerLearningDistance = nil
	BotPlayerLearningObserver.reset(state.playerObserver)
	state.mainAgent = nil
	state.mainAnimationCleanup = nil
	local playerRoot = getPlayerRoot()
	assert(playerRoot, "[BotRuntime.spawnMainAgent] local player has no root part")
	local bot, humanoid, rootPart, cleanup = BotPresentation.spawn(
		"TrainingBot",
		playerRoot.CFrame * CFrame.new(6, 1, 0),
		state.selectedRole
	)
	local agent = BotAgent.create(bot, humanoid, rootPart, state.selectedRole, state.memory, recordExperience)
	BotAgent.setGraph(agent, state.graph)
	BotAgent.setLearningEnabled(agent, BotTrainingRecorder.isEnabled(state.recorder))
	BotAgent.setEnabled(agent, state.enabled)
	state.mainAgent = agent
	state.mainAnimationCleanup = cleanup
	pushLog(`Spawned main {state.selectedRole} bot in workspace.Bots.`)
end

local function spawnOpponentAgent()
	destroyAgent(state.opponentAgent, state.opponentAnimationCleanup)
	state.opponentAgent = nil
	state.opponentAnimationCleanup = nil
	local main = state.mainAgent
	if not main then return end
	local opposite: BotRole = if main.role == "Tagger" then "Runner" else "Tagger"
	local bot, humanoid, rootPart, cleanup = BotPresentation.spawn(
		"TrainingOpponent",
		main.rootPart.CFrame * CFrame.new(-10, 1, 0),
		opposite
	)
	local agent = BotAgent.create(bot, humanoid, rootPart, opposite, state.memory, recordExperience)
	BotAgent.setGraph(agent, state.graph)
	BotAgent.setLearningEnabled(agent, BotTrainingRecorder.isEnabled(state.recorder))
	BotAgent.setEnabled(agent, state.enabled)
	state.opponentAgent = agent
	state.opponentAnimationCleanup = cleanup
	pushLog(`Spawned opponent {opposite} bot.`)
end

local function updateBuildJobs()
	if state.mapJob then
		debug.profilebegin("BotMapModel.stepBuild")
		local done = BotMapModel.stepBuild(state.mapJob, Config.mapBuildBudgetSeconds)
		debug.profileend()
		state.status = state.mapJob.status
		if done then
			if state.mapJob.model.ready then
				state.affordanceJob = BotAffordanceBuilder.createBuildJob(state.mapJob.model)
			else
				pushLog(state.mapJob.status)
			end
			state.mapJob = nil
		end
	end
	if state.affordanceJob then
		debug.profilebegin("BotAffordanceBuilder.stepBuild")
		local buildBudget = if state.affordanceJob.phase == "Primary"
			then Config.primaryAffordanceBuildBudgetSeconds
			else Config.affordanceBuildBudgetSeconds
		local done = BotAffordanceBuilder.stepBuild(state.affordanceJob, buildBudget)
		debug.profileend()
		state.status = state.affordanceJob.status
		if done then
			state.graph = state.affordanceJob.graph
			local actionCounts: { [string]: number } = {}
			for _, edge in state.graph.edges do actionCounts[edge.action] = (actionCounts[edge.action] or 0) + 1 end
			state.graphActionSummary = `Walk {actionCounts.Walk or 0} | Jump {actionCounts.Jump or 0} | Vault {(actionCounts.Vault or 0) + (actionCounts.HighVault or 0)} | Truss {actionCounts.TrussClimb or 0} | Swing {actionCounts.Swing or 0} | Drop {actionCounts.Drop or 0} | Roll {(actionCounts.Roll or 0) + (actionCounts.RollBoost or 0)} | SlideBoost {actionCounts.SlideBoost or 0} | Trampoline {actionCounts.Trampoline or 0}`
			state.visualSignature = ""
			state.affordanceJob = nil
			attachGraph(state.mainAgent)
			attachGraph(state.opponentAgent)
			BotExplorationSwarm.setGraph(state.swarm, state.graph)
			pushLog(`Navigation graph ready: {#state.graph.mapModel.nodes} nodes, {#state.graph.edges} executable transitions.`)
		end
	end
end

local function getIgnoreList(): { Instance }
	local ignore = {}
	local bots = Workspace:FindFirstChild("Bots")
	local debug = Workspace:FindFirstChild("BotDebug")
	if bots then ignore[#ignore + 1] = bots end
	if debug then ignore[#ignore + 1] = debug end
	return ignore
end

local function applyBotTagLockout(bot: Model)
	bot:SetAttribute("TagLockedUntil", os.clock() + Config.tagLockoutSeconds)
	BotPresentation.applyNtb(bot, Config.tagLockoutSeconds)
end

local function tryBotVsBotTag(tagger: RAgent, target: RAgent)
	if (tagger.rootPart.Position - target.rootPart.Position).Magnitude > Config.tagRange then return end
	if os.clock() < (tagger.character:GetAttribute("TagLockedUntil") or 0) then return end
	if os.clock() - (state.lastTagTimes[tagger.character] or 0) < 0.5 then return end
	local allowed, taggerNewName, targetNewName = canTag(tagger.role, target.role)
	if not allowed or not taggerNewName or not targetNewName then return end
	local taggerNew = normalizeRole(taggerNewName)
	local targetNew = normalizeRole(targetNewName)
	if not taggerNew or not targetNew then return end
	state.lastTagTimes[tagger.character] = os.clock()
	BotAgent.recordTagOutcome(tagger, true, target.rootPart.Position)
	BotAgent.recordTagOutcome(target, false, target.lastPlanGoal)
	BotAgent.setRole(tagger, taggerNew)
	BotAgent.setRole(target, targetNew)
	BotPresentation.applyRole(tagger.character, taggerNew)
	BotPresentation.applyRole(target.character, targetNew)
	applyBotTagLockout(target.character)
	KnockbackVelocity.apply({
		targetRootPart = target.rootPart,
		originPosition = tagger.rootPart.Position,
		sourceVelocity = tagger.rootPart.AssemblyLinearVelocity,
		knockbackType = "LocalBotTag",
	})
	pushLog(`Bot tag: {taggerNew} / {targetNew}.`)
end

local function tryBotVsPlayerTag(agent: RAgent, playerRoot: BasePart)
	if (agent.rootPart.Position - playerRoot.Position).Magnitude > Config.tagRange then return end
	if os.clock() < (agent.character:GetAttribute("TagLockedUntil") or 0) then return end
	if os.clock() - (state.lastTagTimes[agent.character] or 0) < 0.7 then return end
	local playerCharacter = playerRoot.Parent
	if not playerCharacter then return end
	local playerRole = playerCharacter:GetAttribute("Role")
	if typeof(playerRole) ~= "string" then return end
	if not canTag(agent.role, playerRole) then return end
	state.lastTagTimes[agent.character] = os.clock()
	task.spawn(function()
		local success, result = pcall(function()
			return BotTagRF:InvokeServer(agent.role, playerRoot, agent.rootPart.Position)
		end)
		if not success or typeof(result) ~= "table" or result.success ~= true then return end
		local newRole = normalizeRole(tostring(result.botRole))
		if not newRole or not agent.character.Parent then return end
			BotAgent.recordTagOutcome(agent, true, playerRoot.Position)
		BotAgent.setRole(agent, newRole)
		BotPresentation.applyRole(agent.character, newRole)
		applyBotTagLockout(agent.character)
		pushLog(`Bot tagged player and became {newRole}.`)
	end)
end

local function beginManualAttempt(agent: RAgent)
	local startPosition = state.manualStart
	local goalPosition = state.manualGoal
	assert(startPosition and goalPosition, "[BotRuntime.beginManualAttempt] manual start and goal are required")
	BotAgent.resetNavigation(agent, "Manual time-trial attempt reset")
	local flatGoal = Vector3.new(goalPosition.X, startPosition.Y, goalPosition.Z)
	local spawnCFrame = if (flatGoal - startPosition).Magnitude > 0.1
		then CFrame.lookAt(startPosition, flatGoal)
		else CFrame.new(startPosition)
	agent.character:PivotTo(spawnCFrame)
	agent.rootPart.AssemblyLinearVelocity = Vector3.zero
	agent.rootPart.AssemblyAngularVelocity = Vector3.zero
	agent.humanoid:Move(Vector3.zero, false)
	state.manualAttemptCount += 1
	state.manualAttemptStartedAt = os.clock()
	state.manualAttemptActive = true
	state.status = `Manual trial #{state.manualAttemptCount}: beat {math.floor(state.manualTimeLimit * 100) / 100}s`
	pushLog(
		`Manual trial #{state.manualAttemptCount} started; target time {math.floor(state.manualTimeLimit * 100) / 100}s.`
	)
end

local function finishManualAttempt(agent: RAgent, succeeded: boolean, elapsed: number)
	local goalPosition = if state.manualGoal
		then state.manualGoal
		elseif state.manualTarget
		then state.manualTarget.Position
		else agent.rootPart.Position
	local reward = if succeeded
		then Config.manualTrialSuccessReward + math.max(0, state.manualTimeLimit - elapsed) * 0.2
		else -Config.manualTrialFailurePenalty
	BotAgent.recordTrialOutcome(agent, succeeded, reward, elapsed, goalPosition)
	state.manualAttemptActive = false
	state.manualResetAt = os.clock() + Config.manualTrialResetDelaySeconds
	BotAgent.resetNavigation(agent, if succeeded then "Manual time trial succeeded" else "Manual time trial timed out")
	agent.humanoid:Move(Vector3.zero, false)
	if succeeded then
		state.manualSuccessCount += 1
		state.manualBestTime = math.min(state.manualBestTime or math.huge, elapsed)
		local improvement = math.max(
			Config.manualTrialImprovementSeconds,
			elapsed * Config.manualTrialImprovementFraction
		)
		state.manualTimeLimit = math.max(state.manualTimeFloor, elapsed - improvement)
		state.status = `Manual success {math.floor(elapsed * 100) / 100}s; next {math.floor(state.manualTimeLimit * 100) / 100}s`
		pushLog(
			`Manual trial success in {math.floor(elapsed * 100) / 100}s. Next attempt must beat {math.floor(state.manualTimeLimit * 100) / 100}s.`
		)
	else
		state.manualFailureCount += 1
		state.status = `Manual failure at {math.floor(elapsed * 100) / 100}s; retrying`
		pushLog(
			`Manual trial timed out at {math.floor(elapsed * 100) / 100}s; resetting with the same {math.floor(state.manualTimeLimit * 100) / 100}s target.`
		)
	end
end

local function updateManualTimeTrial(agent: RAgent, dt: number, ignore: { Instance })
	local target = state.manualTarget
	if not target then return end
	local now = os.clock()
	if not state.manualAttemptActive then
		agent.humanoid:Move(Vector3.zero, false)
		if now >= state.manualResetAt then beginManualAttempt(agent) end
		return
	end
	BotAgent.update(agent, dt, target, ignore, target.Position, Config.plannerMainAgentBudgetSeconds)
	local elapsed = now - state.manualAttemptStartedAt
	local reached = (agent.rootPart.Position - target.Position).Magnitude <= Config.manualTrialGoalReachDistance
	if reached then
		finishManualAttempt(agent, elapsed <= state.manualTimeLimit, elapsed)
	elseif elapsed >= state.manualTimeLimit then
		finishManualAttempt(agent, false, elapsed)
	end
end

local function updateAgents(dt: number)
	local main = state.mainAgent
	local playerRoot = getPlayerRoot()
	local ignore = getIgnoreList()

	if main then
		if state.techDrill.running then
			local event = BotTechDrill.update(state.techDrill, main, dt, ignore)
			if event then
				pushLog(event.message)
				state.status = event.message
				if event.kind == "Mastered" then
					saveMemory(true, "focused tech drill mastery")
				end
			end
		elseif state.techDrill.mastered then
			main.humanoid:Move(Vector3.zero, false)
		elseif state.manualRun and state.manualTarget then
			updateManualTimeTrial(main, dt, ignore)
		elseif state.duelMode and state.opponentAgent then
			BotAgent.update(
				main,
				dt,
				state.opponentAgent.rootPart,
				ignore,
				nil,
				Config.plannerDuelAgentBudgetSeconds
			)
			BotAgent.update(
				state.opponentAgent,
				dt,
				main.rootPart,
				ignore,
				nil,
				Config.plannerDuelAgentBudgetSeconds
			)
			tryBotVsBotTag(main, state.opponentAgent)
			tryBotVsBotTag(state.opponentAgent, main)
		elseif playerRoot then
			BotAgent.update(main, dt, playerRoot, ignore, nil, Config.plannerMainAgentBudgetSeconds)
			tryBotVsPlayerTag(main, playerRoot)
		end
	end
	BotExplorationSwarm.update(state.swarm, dt, state.graph, state.memory, ignore)
	BotTelemetry.observeAgent(state.telemetry, main)
	BotTelemetry.observeAgent(state.telemetry, state.opponentAgent)
	for _, entry in state.swarm.entries do BotTelemetry.observeAgent(state.telemetry, entry.agent) end
end

local function updatePlayerRouteLearning()
	local graph = state.graph
	local character = localPlayer.Character
	local playerRoot = getPlayerRoot()
	local observation = BotPlayerLearningObserver.update(state.playerObserver, graph, character, playerRoot)
	if not observation then return end
	if graph and state.routeTeaching.recording then
		BotRouteTeaching.observe(state.routeTeaching, graph, observation)
	end
	if not graph or not BotTrainingRecorder.isEnabled(state.recorder) then return end
	local agent = state.mainAgent
	if not agent or not character or not playerRoot then return end
	local currentDistance = (playerRoot.Position - agent.rootPart.Position).Magnitude
	local previousDistance = state.lastPlayerLearningDistance
	state.lastPlayerLearningDistance = currentDistance
	if not previousDistance then return end

	local roleName = character:GetAttribute("Role")
	local role = if typeof(roleName) == "string" then normalizeRole(roleName) else nil
	if not role then role = state.selectedRole end
	local distanceAdvantage = if role == "Runner"
		then currentDistance - previousDistance
		else previousDistance - currentDistance
	distanceAdvantage = math.clamp(distanceAdvantage, -8, 8)
	local advantage = distanceAdvantage
	local transitionDistance = (observation.toPosition - observation.fromPosition).Magnitude
	local observedSpeed = transitionDistance / math.max(0.01, observation.duration)
	local playerReliance = BotRouteMemory.getPlayerReliance(state.memory)
	local isFrequentTech = observation.edgeId ~= nil
		and observation.frequency >= Config.playerFrequentTechMinimumCount
	local minimumAdvantage = Config.playerDemonstrationMinAdvantage * (1 - playerReliance * 0.6)
	if isFrequentTech then minimumAdvantage = -Config.playerFrequentTechMaximumDisadvantage end
	if advantage < minimumAdvantage and observedSpeed < Config.playerRouteMinimumObservedSpeed then return end

	local frequencyWeight = 1 + math.min(
		Config.playerFrequentTechMaximumWeight,
		math.max(0, observation.frequency - 1) * Config.playerFrequentTechWeightPerUse
	)
	local trustedTeacherWeight = if BotAccess.userIds[localPlayer.UserId]
		then BotAccess.trustedTeacherWeight
		else 1
	local sampleWeight = getPlayerSampleWeight() * trustedTeacherWeight * playerReliance * frequencyWeight
	BotRouteMemory.recordPlayerTransition(
		state.memory,
		observation.fromPosition,
		observation.toPosition,
		observation.duration,
		sampleWeight * math.clamp(if isFrequentTech then 1 else advantage, 0.25, 4)
	)
	if not observation.edgeId then return end
	local edge = graph.edges[observation.edgeId]
	local reward = advantage + 1
	BotRouteMemory.recordEdge(
		state.memory,
		edge,
		true,
		reward,
		observation.duration,
		observation.timing,
		sampleWeight
	)
	local awayDelta = observation.toPosition - agent.rootPart.Position
	local demonstrationGoal = if role == "Tagger"
		then agent.rootPart.Position
		elseif awayDelta.Magnitude > 0.01
		then observation.toPosition + awayDelta.Unit * 64
		else observation.toPosition
	recordExperience(
		graph,
		observation.edgeId,
		role,
		true,
		reward,
		observation.duration,
		demonstrationGoal,
		"Player",
		trustedTeacherWeight * playerReliance * frequencyWeight
	)
	pushLog(
		`Learned player {edge.action} x{observation.frequency}: advantage {math.floor(advantage * 10) / 10}, teacher weight {math.floor(sampleWeight * 10) / 10}.`
	)
end

local function refreshDebug()
	local now = os.clock()
	if now - state.lastVisualRefreshAt < Config.debugRefreshSeconds then return end
	state.lastVisualRefreshAt = now
	local agent = state.mainAgent
	local planId = if agent and agent.plan then agent.plan.id else 0
	local opponent = state.opponentAgent
	local opponentPlanId = if opponent and opponent.plan then opponent.plan.id else 0
	local graphVersion = if state.graph then state.graph.buildVersion else 0
	local swarmPlans = BotExplorationSwarm.getPlans(state.swarm)
	local swarmPlanIds: { string } = {}
	for index, plan in swarmPlans do swarmPlanIds[index] = tostring(plan.id) end
	local signature = `{graphVersion}:{planId}:{opponentPlanId}:{table.concat(swarmPlanIds, ",")}:{state.renderer.visible}:{state.renderer.showAllNodes}:{state.renderer.showEdges}:{state.renderer.showWalkEdges}:{state.renderer.showVerticalEdges}:{state.renderer.showAdvancedEdges}`
	if signature == state.visualSignature then return end
	state.visualSignature = signature
	BotDebugRenderer.request(
		state.renderer,
		state.graph,
		if agent then agent.plan else nil,
		if opponent then opponent.plan else nil,
		swarmPlans
	)
end

function BotRuntime.buildGraph()
	BotTechDrill.stop(state.techDrill, state.mainAgent, "Graph rebuild stopped focused tech drill")
	BotRouteTeaching.cancel(state.routeTeaching)
	loadMemory()
	state.lastPlayerLearningDistance = nil
	BotPlayerLearningObserver.reset(state.playerObserver)
	state.graph = nil
	state.graphActionSummary = "building"
	state.affordanceJob = nil
	state.mapJob = BotMapModel.createBuildJob()
	attachGraph(state.mainAgent)
	attachGraph(state.opponentAgent)
	BotExplorationSwarm.clear(state.swarm)
	state.status = "Starting incremental map model"
	pushLog("Loading global learning while the incremental map model builds.")
	return true, "incremental map and affordance build started"
end

function BotRuntime.spawnBot()
	BotTechDrill.stop(state.techDrill, state.mainAgent, "Bot reset stopped focused tech drill")
	spawnMainAgent()
	if state.duelMode then spawnOpponentAgent() end
	return true, if state.duelMode then "reset both duel agents" else "reset main agent"
end

function BotRuntime.spawnExplorationBots(count: number)
	local graph = state.graph
	if not graph or not graph.ready then
		pushLog("Build the navigation graph before spawning route explorers.")
		return false, "navigation graph is not ready"
	end
	local botCount = math.clamp(math.floor(count), 1, Config.swarmMaximumBots)
	loadMemory()
	BotTrainingRecorder.setEnabled(state.recorder, true)
	BotExplorationSwarm.spawn(state.swarm, botCount, graph, state.memory, function(
		experienceGraph: RAffordanceGraph,
		edgeId: number,
		role: BotRole,
		succeeded: boolean,
		reward: number,
		duration: number,
		weightMultiplier: number?,
		goalPosition: Vector3?
	)
		recordExperience(
			experienceGraph,
			edgeId,
			role,
			succeeded,
			reward,
			duration,
			goalPosition,
			if weightMultiplier then "ExplorerTrial" else "Explorer",
			weightMultiplier
		)
	end, true)
	state.enabled = true
	if state.mainAgent then BotAgent.setEnabled(state.mainAgent, true) end
	if state.opponentAgent then BotAgent.setEnabled(state.opponentAgent, true) end
	pushLog(`Spawning {botCount} balanced route explorers; learning and recording enabled.`)
	return true, `spawning {botCount} explorers`
end

function BotRuntime.clearExplorationBots()
	local removedCount = #state.swarm.entries
	BotExplorationSwarm.clear(state.swarm)
	pushLog(`Removed {removedCount} independent route explorers.`)
	return true, `removed {removedCount} explorers`
end

function BotRuntime.toggleDuelMode()
	state.duelMode = not state.duelMode
	if state.duelMode then
		if not state.mainAgent then spawnMainAgent() end
		spawnOpponentAgent()
	elseif state.opponentAgent then
		destroyAgent(state.opponentAgent, state.opponentAnimationCleanup)
		state.opponentAgent = nil
		state.opponentAnimationCleanup = nil
	end
	pushLog(if state.duelMode then "Bot-vs-bot mode enabled." else "Bot-vs-player mode enabled.")
	return true, if state.duelMode then "bot-vs-bot enabled" else "bot-vs-player enabled"
end

function BotRuntime.setEnabled(enabled: boolean)
	state.enabled = enabled
	if enabled then loadMemory() end
	if state.mainAgent then BotAgent.setEnabled(state.mainAgent, enabled) end
	if state.opponentAgent then BotAgent.setEnabled(state.opponentAgent, enabled) end
	BotExplorationSwarm.setEnabled(state.swarm, enabled)
	if not enabled then saveMemory(true, "training paused") end
	pushLog(if enabled then "Training started." else "Training paused.")
	return true, if enabled then "agents running" else "agents paused"
end

function BotRuntime.toggleEnabled()
	return BotRuntime.setEnabled(not state.enabled)
end

function BotRuntime.toggleRole()
	state.selectedRole = if state.selectedRole == "Tagger" then "Runner" else "Tagger"
	if state.mainAgent then
		BotAgent.setRole(state.mainAgent, state.selectedRole)
		BotPresentation.applyRole(state.mainAgent.character, state.selectedRole)
	end
	pushLog(`Main role changed to {state.selectedRole}.`)
	return true, `main role is {state.selectedRole}`
end

function BotRuntime.toggleLearningMode()
	local enabled = not BotTrainingRecorder.isEnabled(state.recorder)
	BotTrainingRecorder.setEnabled(state.recorder, enabled)
	state.lastPlayerLearningDistance = nil
	BotPlayerLearningObserver.reset(state.playerObserver)
	if state.mainAgent then BotAgent.setLearningEnabled(state.mainAgent, enabled) end
	if state.opponentAgent then BotAgent.setLearningEnabled(state.opponentAgent, enabled) end
	BotExplorationSwarm.setLearningEnabled(state.swarm, enabled)
	pushLog(if enabled then "Learning enabled: bots will test valid local tech up to three times." else "Learning disabled.")
	return true, if enabled then "learning and recording enabled" else "learning and recording disabled"
end

function BotRuntime.toggleRouteTeaching()
	local graph = state.graph
	if state.routeTeaching.recording then
		if not graph or not graph.ready then
			BotRouteTeaching.cancel(state.routeTeaching)
			return false, "navigation graph disappeared while recording"
		end
		local succeeded, detail = BotRouteTeaching.finish(state.routeTeaching, graph, state.memory)
		if succeeded then
			saveMemory(true, "player-taught map route")
			pushLog(`Route teaching completed: {detail}.`)
		else
			pushLog(`Route teaching rejected: {detail}.`)
		end
		return succeeded, detail
	end
	if not graph or not graph.ready then return false, "build the navigation graph first" end
	if not localPlayer.Character or not getPlayerRoot() then return false, "player character is unavailable" end
	BotPlayerLearningObserver.reset(state.playerObserver)
	state.lastPlayerLearningDistance = nil
	BotRouteTeaching.start(state.routeTeaching)
	pushLog("Route teaching started. Run the route once, then press Finish Teaching Route.")
	return true, "recording executable route transitions"
end

function BotRuntime.toggleCopyPlayerMode()
	pushLog("Player tech is recorded when movement state completes a compatible map affordance; raw inputs are ignored.")
end

function BotRuntime.togglePolicyRecorder()
	BotRuntime.toggleLearningMode()
end

function BotRuntime.exportPolicySamples()
	local count = BotTrainingRecorder.count(state.recorder)
	if count == 0 then
		pushLog("No policy samples are available to export.")
		return false, "sample buffer is empty"
	end
	BotTrainingRecorder.printJsonChunks(state.recorder, "BotPolicySamplesV2")
	pushLog(
		`Exported {BotTrainingRecorder.count(state.recorder)} weighted samples: {BotTrainingRecorder.getActionSummary(state.recorder)}.`
	)
	return true, `exported {count} samples to Output`
end

function BotRuntime.clearPolicySamples()
	local count = BotTrainingRecorder.count(state.recorder)
	BotTrainingRecorder.clear(state.recorder)
	pushLog(`Cleared {count} offline training samples.`)
	return true, `cleared {count} samples`
end

function BotRuntime.trainRuntimePolicy()
	if state.policyJob then
		pushLog("Runtime policy calibration is already running.")
		return false, "policy calibration is already running"
	end
	local count = BotTrainingRecorder.count(state.recorder)
	local actionSummary = BotTrainingRecorder.getActionSummary(state.recorder)
	pushLog(`Policy calibration preflight: {count} samples | {actionSummary}.`)
	if count < Config.onlinePolicyMinimumSamples then
		local reason = `needs at least {Config.onlinePolicyMinimumSamples} samples; recorder has {count}`
		pushLog(`Policy calibration rejected: {reason}.`)
		return false, reason
	end
	local representedActions = 0
	for _ in state.recorder.actionCounts do representedActions += 1 end
	if representedActions < 2 then
		local reason = `needs at least 2 represented actions; current samples are {actionSummary}`
		pushLog(`Policy calibration rejected: {reason}.`)
		return false, reason
	end
	local success, job = pcall(function()
		return BotOnlinePolicyTrainer.create(table.clone(state.recorder.samples))
	end)
	if not success then
		pushLog(`Could not start runtime policy calibration: {tostring(job)}`)
		return false, tostring(job)
	end
	state.policyJob = job
	state.policyTrainingStatus = "baseline validation"
	pushLog(`Started frame-budgeted runtime policy calibration from {count} samples.`)
	return true, `calibrating from {count} samples`
end

function BotRuntime.toggleVisuals()
	state.renderer.visible = not state.renderer.visible
	if state.renderer.visible then
		state.renderer.showAllNodes = false
		state.renderer.showEdges = false
		state.renderer.showWalkEdges = false
		state.renderer.showVerticalEdges = false
		state.renderer.showAdvancedEdges = false
	end
	state.visualSignature = ""
	refreshDebug()
	return true, if state.renderer.visible then "route visuals visible" else "route visuals hidden"
end

function BotRuntime.toggleGraphNodes()
	state.renderer.visible = true
	state.renderer.showAllNodes = not state.renderer.showAllNodes
	state.visualSignature = ""
	refreshDebug()
	return true, if state.renderer.showAllNodes then "all graph nodes visible" else "graph nodes hidden"
end

function BotRuntime.toggleAllGraphNodes()
	return BotRuntime.toggleGraphNodes()
end

function BotRuntime.toggleGraphEdges()
	state.renderer.visible = true
	local enableAll = not (
		state.renderer.showWalkEdges and state.renderer.showVerticalEdges and state.renderer.showAdvancedEdges
	)
	state.renderer.showEdges = enableAll
	state.renderer.showWalkEdges = enableAll
	state.renderer.showVerticalEdges = enableAll
	state.renderer.showAdvancedEdges = enableAll
	state.visualSignature = ""
	refreshDebug()
	return true, if enableAll then "all affordance edges visible" else "all affordance edges hidden"
end

function BotRuntime.toggleWalkEdges()
	state.renderer.visible = true
	state.renderer.showWalkEdges = not state.renderer.showWalkEdges
	state.renderer.showEdges = state.renderer.showWalkEdges
		or state.renderer.showVerticalEdges
		or state.renderer.showAdvancedEdges
	state.visualSignature = ""
	refreshDebug()
	return true, `walk edges visible {state.renderer.showWalkEdges}`
end

function BotRuntime.toggleVerticalEdges()
	state.renderer.visible = true
	state.renderer.showVerticalEdges = not state.renderer.showVerticalEdges
	state.renderer.showEdges = state.renderer.showWalkEdges
		or state.renderer.showVerticalEdges
		or state.renderer.showAdvancedEdges
	state.visualSignature = ""
	refreshDebug()
	return true, `vertical edges visible {state.renderer.showVerticalEdges}`
end

function BotRuntime.toggleAdvancedEdges()
	state.renderer.visible = true
	state.renderer.showAdvancedEdges = not state.renderer.showAdvancedEdges
	state.renderer.showEdges = state.renderer.showWalkEdges
		or state.renderer.showVerticalEdges
		or state.renderer.showAdvancedEdges
	state.visualSignature = ""
	refreshDebug()
	return true, `advanced edges visible {state.renderer.showAdvancedEdges}`
end

function BotRuntime.setStartAtBot()
	if not state.mainAgent then
		pushLog("Cannot set manual start: no main bot exists.")
		return false, "spawn the main bot first"
	end
	state.manualStart = state.mainAgent.rootPart.Position
	if state.manualStartMarker then state.manualStartMarker:Destroy() end
	state.manualStartMarker = createManualMarker(
		"ManualStartMarker",
		state.manualStart,
		Color3.fromRGB(70, 255, 120),
		"START"
	)
	pushLog("Manual start set at bot.")
	return true, `start {state.manualStart}`
end

function BotRuntime.setStartAtPlayer()
	local root = getPlayerRoot()
	if not root then
		pushLog("Cannot set manual start: player root is unavailable.")
		return false, "player root is unavailable"
	end
	state.manualStart = root.Position
	if state.manualStartMarker then state.manualStartMarker:Destroy() end
	state.manualStartMarker = createManualMarker(
		"ManualStartMarker",
		state.manualStart,
		Color3.fromRGB(70, 255, 120),
		"START"
	)
	pushLog("Manual start set at player.")
	return true, `start {state.manualStart}`
end

function BotRuntime.setGoalAtPlayer()
	local root = getPlayerRoot()
	if not root then
		pushLog("Cannot set manual goal: player root is unavailable.")
		return false, "player root is unavailable"
	end
	state.manualGoal = root.Position
	if state.manualTarget then state.manualTarget:Destroy() end
	if state.manualGoalMarker then state.manualGoalMarker:Destroy() end
	local target = Instance.new("Part")
	target.Name = "BotManualGoal"
	target.Size = Vector3.one
	target.Position = root.Position
	target.Anchored = true
	target.CanCollide = false
	target.Transparency = 1
	target.Parent = state.renderer.folder
	state.manualTarget = target
	state.manualGoalMarker = createManualMarker(
		"ManualGoalMarker",
		state.manualGoal,
		Color3.fromRGB(255, 80, 210),
		"GOAL"
	)
	pushLog("Manual goal set at player position.")
	return true, `goal {state.manualGoal}`
end

function BotRuntime.startManualRun()
	if not state.mainAgent or not state.manualStart or not state.manualTarget then
		pushLog("Cannot start manual run: bot, start, and goal are all required.")
		return false, "bot, start, or goal is missing"
	end
	local goalPosition = state.manualGoal or state.manualTarget.Position
	local directDistance = (goalPosition - state.manualStart).Magnitude
	local verticalRise = math.max(0, goalPosition.Y - state.manualStart.Y)
	state.manualTimeLimit = math.max(
		Config.manualTrialInitialMinimumSeconds,
		directDistance / Config.botWalkSpeed * Config.manualTrialInitialDistanceScale
			+ verticalRise * Config.manualTrialVerticalSecondsPerStud
			+ Config.manualTrialBaseSetupSeconds
	)
	state.manualTimeFloor = math.max(
		1,
		directDistance / (Config.botWalkSpeed * Config.manualTrialMinimumSpeedMultiplier)
	)
	state.manualBestTime = nil
	state.manualAttemptCount = 0
	state.manualSuccessCount = 0
	state.manualFailureCount = 0
	state.manualAttemptActive = false
	state.manualResetAt = 0
	state.manualRun = true
	BotTechDrill.stop(state.techDrill, state.mainAgent, "Progressive time trial replaced focused tech drill")
	BotRuntime.setEnabled(true)
	beginManualAttempt(state.mainAgent)
	pushLog("Manual start-to-goal progressive time trial started.")
	return true, `time trial started at {math.floor(state.manualTimeLimit * 100) / 100}s`
end

local function startTechDrill(actionName: string, rapid: boolean): (boolean, string)
	local graph = state.graph
	local agent = state.mainAgent
	local startPosition = state.manualStart
	local goalPosition = state.manualGoal
	if not graph or not graph.ready then
		pushLog("Cannot start focused tech drill: build the navigation graph first.")
		return false, "navigation graph is not ready"
	end
	if not agent or not startPosition or not goalPosition then
		pushLog("Cannot start focused tech drill: bot, start, and goal are required.")
		return false, "spawn a bot and set start and goal"
	end
	local started, detail = BotTechDrill.start(
		state.techDrill,
		graph,
		actionName,
		startPosition,
		goalPosition,
		rapid
	)
	if not started then
		pushLog(`Focused tech drill rejected: {detail}. Rebuild after changing the obstacle or move the markers.`)
		return false, detail
	end
	state.manualRun = false
	BotTrainingRecorder.setEnabled(state.recorder, true)
	BotAgent.setLearningEnabled(agent, true)
	BotRuntime.setEnabled(true)
	state.status = detail
	pushLog(
		`{if rapid then "Rapid" else "Focused"} tech drill started: {detail}. Only this transition owns the main bot.`
	)
	return true, detail
end

function BotRuntime.startTechDrill(actionName: string)
	return startTechDrill(actionName, false)
end

function BotRuntime.startRapidTechDrill(actionName: string)
	return startTechDrill(actionName, true)
end

function BotRuntime.stopTechDrill()
	local wasRunning = state.techDrill.running
	BotTechDrill.stop(state.techDrill, state.mainAgent, "Focused tech drill stopped by user")
	if wasRunning then saveMemory(true, "focused tech drill stopped") end
	pushLog(if wasRunning then "Focused tech drill stopped and learning queued for save." else "Focused tech drill was already inactive.")
	return true, if wasRunning then "focused drill stopped" else "focused drill already inactive"
end

function BotRuntime.clearManualPositions()
	local resetPosition = state.manualStart
	state.manualStart = nil
	state.manualGoal = nil
	state.manualRun = false
	state.manualAttemptActive = false
	BotTechDrill.stop(state.techDrill, state.mainAgent, "Manual positions removed")
	if state.manualTarget then state.manualTarget:Destroy() end
	state.manualTarget = nil
	if state.manualStartMarker then state.manualStartMarker:Destroy() end
	if state.manualGoalMarker then state.manualGoalMarker:Destroy() end
	state.manualStartMarker = nil
	state.manualGoalMarker = nil
	if state.mainAgent and resetPosition then
		BotAgent.resetNavigation(state.mainAgent, "Manual time trial stopped")
		state.mainAgent.character:PivotTo(CFrame.new(resetPosition))
		state.mainAgent.rootPart.AssemblyLinearVelocity = Vector3.zero
		state.mainAgent.rootPart.AssemblyAngularVelocity = Vector3.zero
	end
	pushLog("Manual positions removed.")
	return true, "manual start and goal removed"
end

function BotRuntime.getStatus(): string
	return state.status
end

function BotRuntime.getStats(): (number, number, boolean, string, number)
	local nodes = if state.graph then #state.graph.mapModel.nodes else if state.mapJob then #state.mapJob.model.nodes else 0
	local pathNodes = if state.mainAgent and state.mainAgent.plan then #state.mainAgent.plan.nodeIds else 0
	local reward = if state.mainAgent then state.mainAgent.rewardTotal else 0
	return nodes, pathNodes, state.enabled, state.selectedRole, reward
end

function BotRuntime.getThoughtInfo(): string
	local agent = state.mainAgent
	local opponent = state.opponentAgent
	local graphText = if state.graph
		then `{#state.graph.mapModel.nodes} nodes / {#state.graph.edges} transitions`
		else "not ready"
	return table.concat({
		`Bot A: {if agent then agent.thought else "No bot spawned"}`,
		if opponent then `Bot B: {opponent.thought}` else "Bot B: disabled",
		`Graph: {graphText}`,
		`Affordances: {state.graphActionSummary}`,
		`Edge layers: walk {state.renderer.showWalkEdges} | vertical {state.renderer.showVerticalEdges} | advanced {state.renderer.showAdvancedEdges}`,
		`Mode: {if state.techDrill.running or state.techDrill.mastered then "focused tech drill" elseif state.duelMode then "bot vs bot" elseif state.manualRun then "manual goal" else "bot vs player"}`,
		BotTechDrill.getSummary(state.techDrill),
		BotRouteTeaching.getSummary(state.routeTeaching),
		if state.manualRun
			then `Manual trial: #{state.manualAttemptCount} | {state.manualSuccessCount} success / {state.manualFailureCount} fail | elapsed {math.floor((if state.manualAttemptActive then os.clock() - state.manualAttemptStartedAt else 0) * 100) / 100}s / {math.floor(state.manualTimeLimit * 100) / 100}s | best {if state.manualBestTime then tostring(math.floor(state.manualBestTime * 100) / 100) .. "s" else "none"}`
			else "Manual trial: inactive",
		`Exploration swarm: {BotExplorationSwarm.getSummary(state.swarm)}`,
		`Recorder: {BotTrainingRecorder.isEnabled(state.recorder)} / {BotTrainingRecorder.count(state.recorder)} samples / weight {math.floor(getPlayerSampleWeight() * 100) / 100}`,
		`Sample sources: {BotTrainingRecorder.getSourceSummary(state.recorder)}`,
		`Actions: {BotTrainingRecorder.getActionSummary(state.recorder)}`,
		`Runtime policy: {state.policyTrainingStatus}`,
		`Global memory: loaded {state.memoryLoaded} / dirty {state.memory.dirty} / saving {state.memorySaving}`,
	}, "\n")
end

function BotRuntime.getLogs(): { string }
	return state.logs
end

function BotRuntime.getTelemetryDashboard(): BotTelemetry.RDashboard
	return BotTelemetry.getDashboard(state.telemetry)
end

function BotRuntime.resetTelemetry()
	state.telemetry = BotTelemetry.create()
	pushLog("Reset objective session telemetry and chart history.")
	return true, "session metrics reset"
end

function BotRuntime.recordUiAction(actionName: string, succeeded: boolean, detail: string?)
	BotTelemetry.recordButton(state.telemetry, succeeded)
	local status = if succeeded then "OK" else "ERROR"
	local suffix = if detail then ` | {detail}` else ""
	local message = `UI {status}: {actionName}{suffix}`
	pushLog(message)
	if not succeeded then warn(`[BotTrainer] {message}`) end
end

function BotRuntime.logUiClick(actionName: string)
	pushLog(`UI CLICK: {actionName}`)
end

function BotRuntime.init()
	if state.connection then return end
	local localBotTagged = ReplicatedStorage:FindFirstChild("LocalBotTagged")
	if not localBotTagged then
		localBotTagged = Instance.new("BindableEvent")
		localBotTagged.Name = "LocalBotTagged"
		localBotTagged.Parent = ReplicatedStorage
	end
	assert(localBotTagged:IsA("BindableEvent"), "[BotRuntime.init] LocalBotTagged must be a BindableEvent")
	state.localBotTaggedConnection = localBotTagged.Event:Connect(function(bot: Model, roleName: string)
		local role = normalizeRole(roleName)
		if not role then return end
		local agent = if state.mainAgent and state.mainAgent.character == bot
			then state.mainAgent
			elseif state.opponentAgent and state.opponentAgent.character == bot
			then state.opponentAgent
			else BotExplorationSwarm.findAgent(state.swarm, bot)
		if not agent then return end
		if agent.role == "Runner" then BotAgent.recordTagOutcome(agent, false) end
		BotAgent.setRole(agent, role)
		BotPresentation.applyRole(bot, role)
		applyBotTagLockout(bot)
		pushLog(`Player tagged bot; role is now {role}.`)
	end)
	Workspace.ChildAdded:Connect(function(child)
		if child.Name ~= "Map" then return end
		state.status = "Map available; graph build is manual"
		pushLog("Map loaded. Use Build Map Model + Affordances when ready.")
	end)
	Workspace.ChildRemoved:Connect(function(child)
		if child.Name ~= "Map" then return end
		BotTechDrill.stop(state.techDrill, state.mainAgent, "Map removal stopped focused tech drill")
		BotRouteTeaching.cancel(state.routeTeaching)
		state.mapJob = nil
			state.affordanceJob = nil
			state.graph = nil
			state.graphActionSummary = "not ready"
		attachGraph(state.mainAgent)
		attachGraph(state.opponentAgent)
		BotExplorationSwarm.clear(state.swarm)
		state.status = "Waiting for workspace.Map"
	end)
	if Workspace:FindFirstChild("Map") then
		state.status = "Map available; graph build is manual"
		pushLog("Automatic graph construction is disabled.")
	end

	local accumulator = 0
	state.connection = RunService.Heartbeat:Connect(function(dt)
		local building = state.mapJob ~= nil or state.affordanceJob ~= nil
		local debugging = state.renderer.visible or state.renderer.clearTail > 0
		local policyTraining = state.policyJob ~= nil
		local agentsRunning = state.enabled
			and (state.mainAgent ~= nil or #state.swarm.entries > 0 or state.swarm.spawning)
		local teachingRoute = state.routeTeaching.recording
		if not agentsRunning and not building and not debugging and not policyTraining and not teachingRoute then return end

		if building then updateBuildJobs() end
		if policyTraining then updatePolicyTraining() end
		if debugging then
			BotDebugRenderer.update(state.renderer)
			if state.renderer.visible then refreshDebug() end
		end
		if not agentsRunning and not teachingRoute then return end

		accumulator += dt
		local updateStep = 1 / Config.updateHz
		if accumulator < updateStep then return end
		local updateDt = math.min(accumulator, updateStep * 2)
		accumulator = 0
		updatePlayerRouteLearning()
		saveMemory(false)
		if agentsRunning and state.enabled then updateAgents(updateDt) end
		local telemetrySummary = BotTelemetry.consumeEventSummary(state.telemetry)
		if telemetrySummary then pushLog(telemetrySummary) end
	end)
end

return table.freeze(BotRuntime)
