--!strict
--[[
    BotRuntime (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Thin runtime coordinator for the lightweight bot stack.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Packages.Net)
local BotAffordanceGraph = require(ReplicatedStorage.Modules.Bot.BotAffordanceGraph)
local BotAnimator = require(ReplicatedStorage.Modules.Bot.BotAnimator)
local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotLearning = require(ReplicatedStorage.Modules.Bot.BotLearning)
local BotMapScanner = require(ReplicatedStorage.Modules.Bot.BotMapScanner)
local BotMotor = require(ReplicatedStorage.Modules.Bot.BotMotor)
local BotPlanner = require(ReplicatedStorage.Modules.Bot.BotPlanner)
local BotPolicy = require(ReplicatedStorage.Modules.Bot.BotPolicy)
local BotTrainingRecorder = require(ReplicatedStorage.Modules.Bot.BotTrainingRecorder)
local KnockbackVelocity = require(ReplicatedStorage.Modules.FX.KnockbackVelocity)

type RuntimeState = {
	graph: any?,
	graphMapRoot: Instance?,
	scanJob: any?,
	plannerJob: any?,
	path: { number },
	pathCursor: number,
	pathCommittedNodeId: number?,
	pathCommittedNodeTime: number,
	pathCommittedNodeBestDistance: number,
	pathGoalPosition: Vector3?,
	pathActionTarget: Vector3?,
	pathAttemptKey: string?,
	pathAttemptCount: number,
	plannerTargetPosition: Vector3?,
	memory: BotLearning.RLearningMemory,
	bot: Model?,
	humanoid: Humanoid?,
	rootPart: BasePart?,
	animationCleanup: (() -> ())?,
	opponentBot: Model?,
	opponentHumanoid: Humanoid?,
	opponentRootPart: BasePart?,
	opponentAnimationCleanup: (() -> ())?,
	opponentMotorState: BotMotor.RMotorState,
	opponentRole: "Tagger" | "Runner",
	duelMode: boolean,
	lastBotTagTime: number,
	localBotTaggedConnection: RBXScriptConnection?,
	localRoleConnection: RBXScriptConnection?,
	motorState: BotMotor.RMotorState,
	enabled: boolean,
	learningMode: boolean,
	copyPlayerMode: boolean,
	policyRecorder: BotTrainingRecorder.RRecorder,
	lastCopyPlayerSampleTime: number,
	lastCopyPlayerPosition: Vector3?,
	lastCopyPlayerNodeId: number?,
	lastCopyPlayerDistance: number?,
	lastDecisionTime: number,
	lastPlannerTime: number,
	lastRewardTime: number,
	lastRewardDistance: number?,
	rewardTotal: number,
	role: "Tagger" | "Runner",
	runnerEscapeCursor: number,
	runnerGoalPosition: Vector3?,
	lastRunnerEscapeTime: number,
	lastDirectLineTime: number,
	cachedDirectLine: boolean,
	lastStuckReplanTime: number,
	backtrackTarget: Vector3?,
	backtrackUntil: number,
	lastMoveTarget: Vector3?,
	lastPathAction: string,
	manualStartPosition: Vector3?,
	manualGoalPosition: Vector3?,
	manualRunActive: boolean,
	manualReached: boolean,
	visualize: boolean,
	visualizeGraphNodes: boolean,
	visualizeAllGraphNodes: boolean,
	visualizeGraphEdges: boolean,
	lastVisualizationTime: number,
	visualBuildId: number,
	visualBuildRunning: boolean,
	visualClearRunning: boolean,
	lastStuckLogTime: number,
	lastWallLogTime: number,
	lastTechExploreTime: number,
	techExperimentCursor: number,
	activeTechExperiment: {
		actionName: string,
		startPosition: Vector3,
		startDistance: number,
		startY: number,
		startTime: number,
	}?,
	memoryLoaded: boolean,
	memoryDirty: boolean,
	memorySaving: boolean,
	lastMemorySaveTime: number,
	logs: { string },
	status: string,
	connection: RBXScriptConnection?,
}

local BotRuntime = {}

local localPlayer = Players.LocalPlayer
local visualInstancesThisBuild = 0

local state: RuntimeState = {
	graph = nil,
	graphMapRoot = nil,
	scanJob = nil,
	plannerJob = nil,
	path = {},
	pathCursor = 1,
	pathCommittedNodeId = nil,
	pathCommittedNodeTime = 0,
	pathCommittedNodeBestDistance = math.huge,
	pathGoalPosition = nil,
	pathActionTarget = nil,
	pathAttemptKey = nil,
	pathAttemptCount = 0,
	plannerTargetPosition = nil,
	memory = BotLearning.createMemory(),
	bot = nil,
	humanoid = nil,
	rootPart = nil,
	animationCleanup = nil,
	opponentBot = nil,
	opponentHumanoid = nil,
	opponentRootPart = nil,
	opponentAnimationCleanup = nil,
	opponentMotorState = BotMotor.createState(),
	opponentRole = "Runner",
	duelMode = false,
	lastBotTagTime = 0,
	localBotTaggedConnection = nil,
	localRoleConnection = nil,
	motorState = BotMotor.createState(),
	enabled = false,
	learningMode = Config.learningModeEnabled,
	copyPlayerMode = false,
	policyRecorder = BotTrainingRecorder.create(Config.policyRecorderMaxSamples),
	lastCopyPlayerSampleTime = 0,
	lastCopyPlayerPosition = nil,
	lastCopyPlayerNodeId = nil,
	lastCopyPlayerDistance = nil,
	lastDecisionTime = 0,
	lastPlannerTime = 0,
	lastRewardTime = 0,
	lastRewardDistance = nil,
	rewardTotal = 0,
	role = "Tagger",
	runnerEscapeCursor = 1,
	runnerGoalPosition = nil,
	lastRunnerEscapeTime = 0,
	lastDirectLineTime = 0,
	cachedDirectLine = false,
	lastStuckReplanTime = 0,
	backtrackTarget = nil,
	backtrackUntil = 0,
	lastMoveTarget = nil,
	lastPathAction = "Walk",
	manualStartPosition = nil,
	manualGoalPosition = nil,
	manualRunActive = false,
	manualReached = false,
	visualize = false,
	visualizeGraphNodes = false,
	visualizeAllGraphNodes = false,
	visualizeGraphEdges = false,
	lastVisualizationTime = 0,
	visualBuildId = 0,
	visualBuildRunning = false,
	visualClearRunning = false,
	lastStuckLogTime = 0,
	lastWallLogTime = 0,
	lastTechExploreTime = 0,
	techExperimentCursor = 1,
	activeTechExperiment = nil,
	memoryLoaded = false,
	memoryDirty = false,
	memorySaving = false,
	lastMemorySaveTime = 0,
	logs = {},
	status = "Idle",
	connection = nil,
}

local function pushLog(message: string)
	local line = `{math.floor(os.clock() * 10) / 10}s [{state.role}] {message}`
	state.logs[#state.logs + 1] = line
	if #state.logs > 90 then table.remove(state.logs, 1) end
end

local RetrieveBotLightweightMemoryRF = Net:RemoteFunction("RetrieveBotLightweightMemory")
local SaveBotLightweightMemoryRF = Net:RemoteFunction("SaveBotLightweightMemory")
local BotTagRF = Net:RemoteFunction("BotTag")
local refreshBotHighlights: () -> ()

local function copyNumberMap(source: any, maxEntries: number): { [string]: number }
	local result = {}
	local count = 0

	if typeof(source) ~= "table" then return result end

	for key, value in source do
		if count >= maxEntries then break end
		if typeof(key) ~= "string" then continue end

		local numberValue = tonumber(value)
		if not numberValue then continue end

		result[string.sub(key, 1, 96)] = numberValue
		count += 1
	end

	return result
end

local function exportMemory(): { [string]: any }
	return {
		edgeScores = copyNumberMap(state.memory.edgeScores, 350),
		edgeAttempts = copyNumberMap(state.memory.edgeAttempts, 350),
		techScores = copyNumberMap(state.memory.techScores, 350),
		techAttempts = copyNumberMap(state.memory.techAttempts, 350),
		deadEndScores = copyNumberMap(state.memory.deadEndScores, 350),
		areaScores = copyNumberMap(state.memory.areaScores, 350),
		areaAttempts = copyNumberMap(state.memory.areaAttempts, 350),
		playerRouteScores = copyNumberMap(state.memory.playerRouteScores, 350),
	}
end

local function applyMemory(memory: any)
	if typeof(memory) ~= "table" then return end

	state.memory.edgeScores = copyNumberMap(memory.edgeScores, 350)
	state.memory.edgeAttempts = copyNumberMap(memory.edgeAttempts, 350)
	state.memory.techScores = copyNumberMap(memory.techScores, 350)
	state.memory.techAttempts = copyNumberMap(memory.techAttempts, 350)
	state.memory.deadEndScores = copyNumberMap(memory.deadEndScores, 350)
	state.memory.areaScores = copyNumberMap(memory.areaScores, 350)
	state.memory.areaAttempts = copyNumberMap(memory.areaAttempts, 350)
	state.memory.playerRouteScores = copyNumberMap(memory.playerRouteScores, 350)
end

local function markMemoryDirty()
	state.memoryDirty = true
end

local function loadGlobalMemory()
	if state.memoryLoaded then return end
	state.memoryLoaded = true

	task.spawn(function()
		local success, result = pcall(function()
			return RetrieveBotLightweightMemoryRF:InvokeServer()
		end)

		if not success or typeof(result) ~= "table" then
			pushLog("Global bot memory load failed; using local session memory.")
			return
		end

		applyMemory(result)
		pushLog("Loaded global bot memory.")
	end)
end

local function listenForLocalRoleChanges()
	if state.localRoleConnection then
		state.localRoleConnection:Disconnect()
		state.localRoleConnection = nil
	end

	local character = localPlayer.Character
	if not character then return end

	state.localRoleConnection = character:GetAttributeChangedSignal("Role"):Connect(refreshBotHighlights)
	refreshBotHighlights()
end

local function saveGlobalMemory(force: boolean?)
	if state.memorySaving then return end
	if not force and not state.memoryDirty then return end

	local now = os.clock()
	if not force and now - state.lastMemorySaveTime < Config.memorySaveIntervalSeconds then return end

	state.memorySaving = true
	state.lastMemorySaveTime = now
	local payload = exportMemory()

	task.spawn(function()
		local success, result = pcall(function()
			return SaveBotLightweightMemoryRF:InvokeServer(payload)
		end)

		state.memorySaving = false
		if not success or typeof(result) ~= "table" then
			pushLog("Global bot memory save failed.")
			return
		end

		applyMemory(result)
		state.memoryDirty = false
		pushLog("Saved global bot memory.")
	end)
end

local function destroyScripts(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then descendant:Destroy() end
	end
end

local function getBotsFolder(): Folder
	local folder = workspace:FindFirstChild("Bots")
	if folder and folder:IsA("Folder") then return folder end

	local newFolder = Instance.new("Folder")
	newFolder.Name = "Bots"
	newFolder.Parent = workspace
	return newFolder
end

local function getRoleConfig(roleName: string): { [string]: any }?
	local roleModule = ReplicatedStorage.Shared.Configs.Roles:FindFirstChild(roleName)
	if not roleModule or not roleModule:IsA("ModuleScript") then return nil end

	return require(roleModule)
end

local function setBodyRoleColor(bot: Model, roleName: string)
	local roleConfig = getRoleConfig(roleName)
	local color = if roleConfig and typeof(roleConfig.Color) == "Color3" then roleConfig.Color else Color3.new(1, 1, 1)
	local bodyColors = bot:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.TorsoColor3 = color
		bodyColors.LeftLegColor3 = color
		bodyColors.RightLegColor3 = color
	end

	for _, descendant in bot:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		if descendant.Name == "Torso" or descendant.Name == "UpperTorso" or descendant.Name == "LowerTorso" then
			descendant.Color = color
		elseif string.find(descendant.Name, "Leg") then
			descendant.Color = color
		end
	end
end

local function clearBotHighlight(bot: Model)
	local existing = bot:FindFirstChild("BotRoleHighlight")
	if existing then existing:Destroy() end
end

local function shouldHighlightBotRole(roleName: string): boolean
	local character = localPlayer.Character
	if not character then return false end

	local playerRole = character:GetAttribute("Role")
	if typeof(playerRole) ~= "string" then return false end

	local roleConfig = getRoleConfig(playerRole)
	if not roleConfig or typeof(roleConfig.canTagRoles) ~= "table" then return false end

	return table.find(roleConfig.canTagRoles, roleName) ~= nil
end

local function updateBotHighlight(bot: Model, roleName: string)
	clearBotHighlight(bot)
	if not shouldHighlightBotRole(roleName) then return end

	local roleConfig = getRoleConfig(roleName)
	if not roleConfig or typeof(roleConfig.Color) ~= "Color3" then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "BotRoleHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = roleConfig.Color
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = roleConfig.Color
	highlight.OutlineTransparency = 0.25
	highlight.Parent = bot
end

refreshBotHighlights = function()
	if state.bot then updateBotHighlight(state.bot, state.role) end
	if state.opponentBot then updateBotHighlight(state.opponentBot, state.opponentRole) end
end

local function applyBotRole(bot: Model, roleName: "Tagger" | "Runner")
	bot:SetAttribute("Role", roleName)
	setBodyRoleColor(bot, roleName)
	if bot == state.bot then
		state.role = roleName
	elseif bot == state.opponentBot then
		state.opponentRole = roleName
	end
	updateBotHighlight(bot, roleName)
end

local function grantBotNtb(bot: Model)
	bot:SetAttribute("NTBDurability", 3)
	task.delay(3, function()
		if bot.Parent then bot:SetAttribute("NTBDurability", 0) end
	end)
end

local function lockBotTagging(bot: Model, seconds: number)
	if seconds <= 0 then return end

	bot:SetAttribute("BotTagDisabledUntil", os.clock() + seconds)
end

local function botCanTag(bot: Model): boolean
	local disabledUntil = bot:GetAttribute("BotTagDisabledUntil")
	return typeof(disabledUntil) ~= "number" or os.clock() >= disabledUntil
end

local function canRoleTag(taggerRole: string, targetRole: string): (boolean, string?, string?)
	local roleConfig = getRoleConfig(taggerRole)
	if not roleConfig then return false, nil, nil end
	if typeof(roleConfig.canTagRoles) ~= "table" or not table.find(roleConfig.canTagRoles, targetRole) then return false, nil, nil end
	if typeof(roleConfig.onTagGives) ~= "string" or typeof(roleConfig.onTagBecomes) ~= "string" then return false, nil, nil end

	return true, roleConfig.onTagBecomes, roleConfig.onTagGives
end

local function normalizeBotRole(roleName: string): ("Tagger" | "Runner")?
	if roleName == "Tagger" then return "Tagger" end
	if roleName == "Runner" then return "Runner" end
	return nil
end

local function destroyCurrentBot()
	if state.animationCleanup then
		state.animationCleanup()
		state.animationCleanup = nil
	end
	if state.bot then
		state.bot:Destroy()
		state.bot = nil
	end
	state.humanoid = nil
	state.rootPart = nil
end

local function destroyOpponentBot()
	if state.opponentAnimationCleanup then
		state.opponentAnimationCleanup()
		state.opponentAnimationCleanup = nil
	end
	if state.opponentBot then
		state.opponentBot:Destroy()
		state.opponentBot = nil
	end
	state.opponentHumanoid = nil
	state.opponentRootPart = nil
end

local function getPlayerRoot(): BasePart?
	local character = localPlayer.Character
	if not character then return nil end

	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getTargetRoot(): BasePart?
	if state.duelMode and state.opponentRootPart and state.opponentRootPart.Parent then return state.opponentRootPart end
	return getPlayerRoot()
end

local function getIgnoreList(): { Instance }
	local ignore = {}
	local character = localPlayer.Character
	if character then ignore[#ignore + 1] = character end
	if state.bot then ignore[#ignore + 1] = state.bot end
	if state.opponentBot then ignore[#ignore + 1] = state.opponentBot end
	return ignore
end

local function clearPath()
	state.plannerJob = nil
	table.clear(state.path)
	state.pathCursor = 1
	state.pathCommittedNodeId = nil
	state.pathCommittedNodeTime = 0
	state.pathCommittedNodeBestDistance = math.huge
	state.pathGoalPosition = nil
	state.pathActionTarget = nil
	state.pathAttemptKey = nil
	state.pathAttemptCount = 0
	state.plannerTargetPosition = nil
end

local function getDebugFolder(): Folder
	local folder = workspace:FindFirstChild("BotDebug")
	if folder and folder:IsA("Folder") then return folder end

	local newFolder = Instance.new("Folder")
	newFolder.Name = "BotDebug"
	newFolder.Parent = workspace
	return newFolder
end

local function clearDebugFolderYielding(folder: Instance)
	local children = folder:GetChildren()
	for childIndex, child in children do
		child:Destroy()
		if childIndex % 24 == 0 then task.wait() end
	end
end

local function clearVisuals()
	if state.visualClearRunning then return end
	state.visualClearRunning = true
	state.visualBuildId += 1

	task.spawn(function()
		local folder = workspace:FindFirstChild("BotDebug")
		if folder then clearDebugFolderYielding(folder) end
		state.visualClearRunning = false
	end)
end

local function makeBillboard(part: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Info"
	billboard.Size = UDim2.new(0, 220, 0, 74)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(235, 238, 244)
	label.TextSize = 10
	label.TextWrapped = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = billboard

	visualInstancesThisBuild += 2
	if visualInstancesThisBuild % 28 == 0 then task.wait() end
end

local function getActionColor(actionName: string): Color3
	if actionName == "Vault" or actionName == "HighVault" then return Color3.fromRGB(255, 190, 80) end
	if actionName == "Swing" then return Color3.fromRGB(110, 255, 210) end
	if string.find(actionName, "SlideBoost") == 1 then return Color3.fromRGB(255, 100, 220) end
	if actionName == "RollBoost" then return Color3.fromRGB(180, 120, 255) end
	if actionName == "Roll" or actionName == "Drop" then return Color3.fromRGB(80, 220, 255) end
	if actionName == "Jump" then return Color3.fromRGB(255, 255, 120) end
	return Color3.fromRGB(80, 160, 255)
end

local function createDebugPart(name: string, position: Vector3, size: Vector3, color: Color3, folder: Folder): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Parent = folder
	visualInstancesThisBuild += 1
	if visualInstancesThisBuild % 28 == 0 then task.wait() end
	return part
end

local function createDebugLine(name: string, fromPosition: Vector3, toPosition: Vector3, color: Color3, thickness: number, folder: Folder)
	local delta = toPosition - fromPosition
	local length = delta.Magnitude
	if length <= 0.05 then return end

	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, length, thickness)
	part.CFrame = CFrame.lookAt(fromPosition:Lerp(toPosition, 0.5), toPosition) * CFrame.Angles(math.rad(90), 0, 0)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.35
	part.Parent = folder
	visualInstancesThisBuild += 1
	if visualInstancesThisBuild % 28 == 0 then task.wait() end
end

local function getNodeColor(node: any): Color3
	if node.wallPenalty >= 2 then return Color3.fromRGB(255, 90, 90) end
	if node.verticalScore >= 24 then return Color3.fromRGB(110, 255, 140) end
	if node.verticalScore >= 10 then return Color3.fromRGB(120, 210, 255) end
	return Color3.fromRGB(70, 115, 170)
end

local function getVisualCenter(): Vector3?
	if state.rootPart then return state.rootPart.Position end
	local targetRoot = getTargetRoot()
	if targetRoot then return targetRoot.Position end
	if state.manualStartPosition then return state.manualStartPosition end
	return nil
end

local function buildVisuals(buildId: number)
	if buildId ~= state.visualBuildId then return end
	if not state.visualize then
		clearVisuals()
		return
	end
	visualInstancesThisBuild = 0

	local folder = getDebugFolder()
	clearDebugFolderYielding(folder)
	if buildId ~= state.visualBuildId or not state.visualize then return end

	if state.manualStartPosition then
		local startPart = createDebugPart(
			"ManualStart",
			state.manualStartPosition,
			Vector3.new(1.8, 1.8, 1.8),
			Color3.fromRGB(80, 255, 160),
			folder
		)
		makeBillboard(startPart, "START")
	end
	if buildId ~= state.visualBuildId or not state.visualize then return end

	if state.manualGoalPosition then
		local goalPart = createDebugPart(
			"ManualGoal",
			state.manualGoalPosition,
			Vector3.new(2, 2, 2),
			Color3.fromRGB(255, 80, 120),
			folder
		)
		makeBillboard(goalPart, "GOAL")
	end
	if buildId ~= state.visualBuildId or not state.visualize then return end

	if state.lastMoveTarget then
		local target = createDebugPart(
			"CurrentTarget",
			state.lastMoveTarget,
			Vector3.new(1.6, 1.6, 1.6),
			Color3.fromRGB(255, 220, 80),
			folder
		)
		local experimentText = if state.activeTechExperiment then `\nTrying: {state.activeTechExperiment.actionName}` else ""
		local intent = if state.backtrackTarget and os.clock() < state.backtrackUntil then "Backtrack" else state.lastPathAction
		makeBillboard(target, `Next: {intent}{experimentText}\n{state.motorState.lastTechResult}`)
	end
	if buildId ~= state.visualBuildId or not state.visualize then return end

	local visualGraph = state.graph or (if state.scanJob then state.scanJob.graph else nil)
	if not visualGraph then return end
	local visualCenter = getVisualCenter()
	local radiusSquared = Config.visualGraphRadius * Config.visualGraphRadius

	if state.visualizeGraphEdges and state.graph then
		local edgeCount = 0
		for nodeIndex = 1, #state.graph.nodes do
			local node = state.graph.nodes[nodeIndex]
			if not node then continue end
			if visualCenter and (node.position - visualCenter).Magnitude ^ 2 > radiusSquared then continue end

			for _, edge in node.edges do
				local nextNode = state.graph.nodes[edge.to]
				if not nextNode then continue end
				if visualCenter and (nextNode.position - visualCenter).Magnitude ^ 2 > radiusSquared then continue end

				edgeCount += 1
				createDebugLine(
					`GraphEdge{edgeCount}`,
					node.position,
					nextNode.position,
					getActionColor(edge.action),
					0.08,
					folder
				)
				if edgeCount >= Config.visualGraphEdgeCap then break end
			end
			if edgeCount >= Config.visualGraphEdgeCap then break end
		end
	end
	if buildId ~= state.visualBuildId or not state.visualize then return end

	if state.visualizeGraphNodes or state.visualizeAllGraphNodes then
		local visualIndex = 0
		for nodeIndex = 1, #visualGraph.nodes do
			local node = visualGraph.nodes[nodeIndex]
			if not node then continue end
			if not state.visualizeAllGraphNodes and visualCenter and (node.position - visualCenter).Magnitude ^ 2 > radiusSquared then continue end

			visualIndex += 1
			local part = createDebugPart(
				if state.visualizeAllGraphNodes then `GraphAllNode{node.id}` else `GraphNode{node.id}`,
				node.position,
				if state.visualizeAllGraphNodes then Vector3.new(0.26, 0.26, 0.26) else Vector3.new(0.34, 0.34, 0.34),
				getNodeColor(node),
				folder
			)
			part.Transparency = 0.2
			if not state.visualizeAllGraphNodes and visualIndex >= Config.visualGraphNodeCap then break end
		end

		if visualIndex <= 0 and not state.visualizeAllGraphNodes then
			local stride = math.max(1, math.ceil(#visualGraph.nodes / Config.visualGraphOverviewNodeCap))
			for nodeIndex = 1, #visualGraph.nodes, stride do
				local node = visualGraph.nodes[nodeIndex]
				if not node then continue end

				visualIndex += 1
				local part = createDebugPart(
					`GraphOverviewNode{node.id}`,
					node.position,
					Vector3.new(0.5, 0.5, 0.5),
					getNodeColor(node),
					folder
				)
				part.Transparency = 0.1
				if visualIndex >= Config.visualGraphOverviewNodeCap then break end
			end
		end
	end
	if buildId ~= state.visualBuildId or not state.visualize then return end
	if not state.graph then return end

	local plannerJob = state.plannerJob
	if plannerJob then
		local startNodeId = plannerJob.startNodeId
		local goalNodeId = plannerJob.goalNodeId
		local bestNodeId = plannerJob.bestNodeId
		local bestHeuristic = plannerJob.bestHeuristic
		local startNode = state.graph.nodes[startNodeId]
		local goalNode = state.graph.nodes[goalNodeId]
		local bestNode = state.graph.nodes[bestNodeId]
		if startNode then
			local marker = createDebugPart("PlannerStartNode", startNode.position + Vector3.yAxis * 0.75, Vector3.new(1, 1, 1), Color3.fromRGB(80, 255, 160), folder)
			makeBillboard(marker, `PLAN START\n#{startNode.id}`)
		end
		if goalNode then
			local marker = createDebugPart("PlannerGoalNode", goalNode.position + Vector3.yAxis * 0.75, Vector3.new(1, 1, 1), Color3.fromRGB(255, 90, 130), folder)
			makeBillboard(marker, `PLAN GOAL\n#{goalNode.id}`)
		end
		if bestNode and bestNode ~= startNode and bestNode ~= goalNode then
			local marker = createDebugPart("PlannerBestNode", bestNode.position + Vector3.yAxis * 0.75, Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(255, 245, 90), folder)
			makeBillboard(marker, `BEST SO FAR\n#{bestNode.id}\nH {math.floor(bestHeuristic * 10) / 10}`)
		end
	end

	for pathIndex = state.pathCursor, math.min(#state.path, state.pathCursor + Config.visualPathNodeCap) do
		local node = state.graph.nodes[state.path[pathIndex]]
		if not node then continue end

		local action = BotPlanner.getPathAction(state.graph, state.path, pathIndex)
		local edge = BotPlanner.getPathEdge(state.graph, state.path, pathIndex)
		local techScore = BotLearning.getTechScore(state.memory, node.position, action)
		local reason = "walk"
		if edge then
			if edge.heightDelta > Config.maxWalkHeight then
				reason = "verticality"
			elseif edge.heightDelta < -Config.minFastDropHeight then
				reason = "drop/roll speed"
			elseif techScore > 0 then
				reason = "learned good"
			elseif techScore < 0 then
				reason = "learned risky"
			elseif action ~= "Walk" then
				reason = "tech option"
			end
		end
		local previousNode = if pathIndex > 1 then state.graph.nodes[state.path[pathIndex - 1]] else nil
		if previousNode then
			createDebugLine(
				`PathEdge{pathIndex}`,
				previousNode.position + Vector3.yAxis * 0.25,
				node.position + Vector3.yAxis * 0.25,
				getActionColor(action),
				0.22,
				folder
			)
		end
		local part = createDebugPart(
			`PathNode{pathIndex}`,
			node.position,
			Vector3.new(0.75, 0.75, 0.75),
			if pathIndex == state.pathCursor then Color3.fromRGB(80, 255, 160) else getActionColor(action),
			folder
		)
		local maxBillboardOffset = if state.enabled then 4 else 12
		if pathIndex <= state.pathCursor + maxBillboardOffset then
			local edgeCost = if edge then edge.cost else 0
			local heightDelta = if edge then edge.heightDelta else 0
			makeBillboard(
				part,
				`#{pathIndex} {action} | {reason}\nCost {math.floor(edgeCost * 10) / 10} | {math.floor(edgeCost / Config.botWalkSpeed * 10) / 10}s\nY {math.floor(heightDelta * 10) / 10} | learned {math.floor(techScore * 10) / 10}`
			)
		end
	end
end

local function refreshVisuals()
	if not state.visualize then
		clearVisuals()
		return
	end
	if os.clock() - state.lastVisualizationTime < Config.visualRefreshSeconds then return end
	state.lastVisualizationTime = os.clock()
	state.visualBuildId += 1

	if state.visualBuildRunning then return end
	state.visualBuildRunning = true

	task.spawn(function()
		local buildId = state.visualBuildId
		buildVisuals(buildId)
		state.visualBuildRunning = false
		if state.visualize and buildId ~= state.visualBuildId then refreshVisuals() end
	end)
end

local function updateScan()
	if not state.scanJob then return end

	local done = BotMapScanner.step(state.scanJob, Config.scanBudgetSeconds)
	local fallbackParts = state.scanJob.fallbackParts
	state.status = if state.scanJob.fallbackActive
		then
			`Surface graph: {state.scanJob.nodesCreated} nodes | part {state.scanJob.fallbackPartIndex}/{if fallbackParts then #fallbackParts else 0} | step {math.floor(state.scanJob.fallbackStep * 10) / 10} | columns {state.scanJob.sampledColumnCount} | samples {state.scanJob.samples}`
		else
			`Scanning {state.scanJob.mapRootName}: {state.scanJob.nodesCreated} nodes | walkable {state.scanJob.walkablePartCount} | samples {state.scanJob.samples} | hits {state.scanJob.hits}`
	if state.visualizeAllGraphNodes then refreshVisuals() end
	if done then
		state.graph = state.scanJob.graph
		state.graphMapRoot = state.scanJob.mapRoot
		local nodesCreated = #state.graph.nodes
		local samples = state.scanJob.samples
		local hits = state.scanJob.hits
		local rejectedSlope = state.scanJob.rejectedSlope
		local rejectedBarrier = state.scanJob.rejectedBarrier
		local missingMap = state.scanJob.missingMap
		local walkablePartCount = state.scanJob.walkablePartCount
		local mapRootName = state.scanJob.mapRootName
		state.scanJob = nil
		if missingMap then
			state.status = "Graph failed: workspace.Map missing"
			pushLog("Graph failed: no server-spawned workspace.Map exists yet.")
		elseif walkablePartCount <= 0 then
			state.status = `Graph failed: no walkable parts in {mapRootName}`
			pushLog(state.status)
		elseif nodesCreated <= 0 then
			state.status =
				`Graph failed: 0 nodes | {mapRootName} | walkable {walkablePartCount} | samples {samples} | hits {hits} | rejected {rejectedSlope} | barriers {rejectedBarrier}`
			pushLog(state.status)
		else
			state.status = `Graph ready: {nodesCreated} nodes | {mapRootName} | center {math.floor(state.graph.boundsCenter.X)}, {math.floor(state.graph.boundsCenter.Y)}, {math.floor(state.graph.boundsCenter.Z)}`
			pushLog(state.status)
		end
	end
end

local function commitPlannerPath(rootPart: BasePart)
	local plannerJob = state.plannerJob
	if not plannerJob then return end

	table.clear(state.path)
	for _, nodeId in plannerJob.path do
		state.path[#state.path + 1] = nodeId
	end

	local closestIndex = 1
	local closestDistance = math.huge
	if state.graph then
		for pathIndex, nodeId in state.path do
			local node = state.graph.nodes[nodeId]
			if not node then continue end

			local distance = (node.position - rootPart.Position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestIndex = pathIndex
			end
		end
	end

	if closestDistance <= Config.pathCommitNearestDistance then
		state.pathCursor = math.clamp(closestIndex + 1, 2, math.max(2, #state.path))
	else
		state.pathCursor = 2
	end
	state.pathCommittedNodeId = nil
	state.pathCommittedNodeTime = 0
	state.pathCommittedNodeBestDistance = math.huge

	state.pathGoalPosition = state.plannerTargetPosition
	state.plannerTargetPosition = nil
	state.pathAttemptKey = table.concat(state.path, ">")
	state.pathAttemptCount = 0
end

local function updatePlanner(rootPart: BasePart, targetPosition: Vector3)
	if not state.graph or #state.graph.nodes <= 0 then return end

	local now = os.clock()
	if state.plannerJob then
		if state.plannerTargetPosition and (targetPosition - state.plannerTargetPosition).Magnitude >= Config.replanTargetMoveDistance then
			state.plannerJob = nil
			state.plannerTargetPosition = nil
			state.status = "Planner retargeted"
			return
		end

		local done = BotPlanner.step(state.plannerJob, state.graph, state.memory, Config.plannerBudgetSeconds)
		state.status = `Planning: {state.plannerJob.expansions} expansions`
		if done then
			if state.plannerJob.failed then
				BotLearning.recordDeadEnd(state.memory, rootPart.Position, -4)
				markMemoryDirty()
				state.status = "Planner failed"
				pushLog("Planner failed; penalized current area and keeping last graph target.")
				state.plannerJob = nil
				state.plannerTargetPosition = nil
				return
			end

			local wasPartial = state.plannerJob.partial
			commitPlannerPath(rootPart)
			state.plannerJob = nil
			state.status = if wasPartial then `Partial path ready: {#state.path} nodes` else `Path ready: {#state.path} nodes`
			pushLog(state.status)
		end
		return
	end

	if #state.path > 1 then
		local goalMoved = state.pathGoalPosition and (targetPosition - state.pathGoalPosition).Magnitude >= Config.replanTargetMoveDistance
		local nearPathEnd = state.pathCursor >= #state.path
		local endNode = state.graph.nodes[state.path[#state.path]]
		local farFromPathEnd = endNode and (endNode.position - targetPosition).Magnitude >= Config.replanPathEndDistance
		if not goalMoved and not nearPathEnd and not farFromPathEnd then return end
	end

	if now - state.lastPlannerTime < 1 / Config.plannerHz then return end
	state.lastPlannerTime = now
	state.plannerTargetPosition = targetPosition
	state.plannerJob = BotPlanner.createJob(state.graph, rootPart.Position, targetPosition, state.role)
	if state.plannerJob then
		pushLog(`Planner started toward {math.floor(targetPosition.X)}, {math.floor(targetPosition.Y)}, {math.floor(targetPosition.Z)}.`)
	else
		state.plannerTargetPosition = nil
	end
end

local function getFallbackGraphTarget(rootPart: BasePart, targetPosition: Vector3): (Vector3?, string)
	if not state.graph then return nil, "Walk" end

	local currentNode = BotAffordanceGraph.findNearestNode(state.graph, rootPart.Position, Config.maxTechNeighborRadius)
	if not currentNode then return nil, "Walk" end

	local needsVerticalRoute = targetPosition.Y - rootPart.Position.Y >= Config.verticalRouteHeight
	local currentGoalDistance = (currentNode.position - targetPosition).Magnitude
	local bestPosition: Vector3? = nil
	local bestAction = "Walk"
	local bestScore = -math.huge
	local checkedEdges = 0

	for _, edge in currentNode.edges do
		checkedEdges += 1
		if checkedEdges > Config.fallbackGraphLookaheadEdges * (if needsVerticalRoute then 3 else 1) then break end

		local node = state.graph.nodes[edge.to]
		if not node then continue end

		local moveDistance = (node.position - rootPart.Position).Magnitude
		if moveDistance < Config.minUsefulMoveTargetDistance then continue end

		local nextGoalDistance = (node.position - targetPosition).Magnitude
		local progress = currentGoalDistance - nextGoalDistance
		local deadEndPenalty = BotLearning.getDeadEndPenalty(state.memory, node.position)
		local areaScore = BotLearning.getAreaScore(state.memory, node.position)
		local techScore = BotLearning.getTechScore(state.memory, currentNode.position, edge.action)
		local score = progress - edge.cost * 0.18 - deadEndPenalty * 4 + techScore
			+ math.clamp(areaScore, -8, 8) * 0.35
			+ (node.openness or 0) * 2
			+ (node.escapeScore or 0) * 0.15
			- math.max(0, 3 - (node.openDirections or 0)) * 2
		if needsVerticalRoute then
			score += math.clamp(edge.heightDelta, -4, 10) * 1.25
			if edge.action == "Vault" or edge.action == "Jump" or edge.action == "Swing" or edge.action == "SlideBoost" then
				score += 3 + math.clamp(currentNode.climbScore or 0, 0, 3)
			end
		end

		if edge.action == "Walk" then
			score += 0.5
		elseif edge.action == "Vault" or edge.action == "HighVault" or edge.action == "Swing" then
			score += 1.5
		elseif edge.action == "Roll" or edge.action == "Drop" then
			score += 1
		end

		if score > bestScore then
			bestScore = score
			bestPosition = node.position
			bestAction = edge.action
		end
	end

	return bestPosition, bestAction
end

local function getBacktrackTarget(rootPart: BasePart, targetPosition: Vector3): Vector3?
	if not state.graph then return nil end

	local currentNode = BotAffordanceGraph.findNearestNode(state.graph, rootPart.Position, Config.maxTechNeighborRadius)
	if not currentNode then return nil end

	local targetDistance = (rootPart.Position - targetPosition).Magnitude
	local bestPosition: Vector3? = nil
	local bestScore = -math.huge
	local checked = 0
	local stride = math.max(1, math.floor(#state.graph.nodes / Config.backtrackMaxNodesChecked))

	for nodeIndex = 1, #state.graph.nodes, stride do
		local node = state.graph.nodes[nodeIndex]
		if not node then continue end

		checked += 1
		if checked > Config.backtrackMaxNodesChecked then break end

		local distanceFromRoot = (node.position - rootPart.Position).Magnitude
		if distanceFromRoot < Config.graphStep * 2 or distanceFromRoot > Config.backtrackSearchRadius then continue end

		local targetPenalty = math.max(0, (node.position - targetPosition).Magnitude - targetDistance) * 0.06
		local deadEndPenalty = BotLearning.getDeadEndPenalty(state.memory, node.position) * 5
		local areaScore = BotLearning.getAreaScore(state.memory, node.position)
		local openness = math.min(10, #node.edges) * 0.9
		local heightHelp = if targetPosition.Y - rootPart.Position.Y > Config.verticalRouteHeight
			then math.clamp(node.position.Y - rootPart.Position.Y, -4, 10) * 0.35
			else 0
		local score = openness
			+ distanceFromRoot * 0.08
			+ heightHelp
			+ (node.openness or 0) * 2.5
			+ (node.escapeScore or 0) * 0.18
			+ math.clamp(areaScore, -8, 8) * 0.35
			- targetPenalty
			- deadEndPenalty
			- node.wallPenalty * 0.35
			- math.max(0, 3 - (node.openDirections or 0)) * 3

		if score > bestScore then
			bestScore = score
			bestPosition = node.position
		end
	end

	return bestPosition
end

local function getPathTarget(rootPart: BasePart, targetPosition: Vector3, ignore: { Instance }): Vector3
	state.lastPathAction = "Walk"
	state.pathActionTarget = nil
	if not state.graph then return targetPosition end
	if state.pathGoalPosition and (targetPosition - state.pathGoalPosition).Magnitude >= Config.stalePathGoalDistance then
		clearPath()
		return targetPosition
	end
	if #state.path <= 0 then
		local node = nil
		if state.plannerJob and state.plannerJob.bestNodeId then node = state.graph.nodes[state.plannerJob.bestNodeId] end
		if node and (node.position - rootPart.Position).Magnitude >= Config.minUsefulMoveTargetDistance then return node.position end
		local fallbackPosition, fallbackAction = getFallbackGraphTarget(rootPart, targetPosition)
		if fallbackPosition then
			state.lastPathAction = fallbackAction
			return fallbackPosition
		end
		return targetPosition
	end

	local nodePosition: Vector3? = nil
	local cursor = state.pathCursor
	for _ = 1, 4 do
		nodePosition, cursor = BotPlanner.getNextPathPosition(state.graph, state.path, cursor)
		if not nodePosition then
			state.pathCursor = cursor
			return targetPosition
		end

		local nodeId = state.path[cursor]
		local distance = (nodePosition - rootPart.Position).Magnitude
		if state.pathCommittedNodeId ~= nodeId then
			state.pathCommittedNodeId = nodeId
			state.pathCommittedNodeTime = os.clock()
			state.pathCommittedNodeBestDistance = distance
		else
			state.pathCommittedNodeBestDistance = math.min(state.pathCommittedNodeBestDistance, distance)
		end

		local reached = distance <= Config.pathReachDistance
		local overshot = state.pathCommittedNodeBestDistance <= Config.pathReachDistance + 1
			and distance >= state.pathCommittedNodeBestDistance + Config.pathOvershootDistance
		local timedOut = os.clock() - state.pathCommittedNodeTime >= Config.pathNodeTimeoutSeconds
			and state.pathCommittedNodeBestDistance <= Config.graphStep * 1.35
		if not reached and not overshot and not timedOut then
			state.pathCursor = cursor
			state.lastPathAction = BotPlanner.getPathAction(state.graph, state.path, state.pathCursor)
			if state.lastPathAction == "Walk" then
				local lookaheadPosition = nodePosition
				local lookaheadCursor = cursor
				local baseDirection = Vector3.new(nodePosition.X - rootPart.Position.X, 0, nodePosition.Z - rootPart.Position.Z)
				local checkedNodes = 0
				while checkedNodes < Config.pathLookaheadNodes do
					local nextCursor = lookaheadCursor + 1
					local nextNodeId = state.path[nextCursor]
					if not nextNodeId then break end
					local action = BotPlanner.getPathAction(state.graph, state.path, nextCursor)
					if action ~= "Walk" then break end

					local nextNode = state.graph.nodes[nextNodeId]
					if not nextNode then break end
					local nextDistance = (nextNode.position - rootPart.Position).Magnitude
					local nextDirection = Vector3.new(nextNode.position.X - rootPart.Position.X, 0, nextNode.position.Z - rootPart.Position.Z)
					if nextDistance > Config.pathLookaheadDistance then break end
					if baseDirection.Magnitude > 0.1 and nextDirection.Magnitude > 0.1 and baseDirection.Unit:Dot(nextDirection.Unit) < Config.pathLookaheadMinDot then break end
					if not BotMotor.hasDirectLine(rootPart, nextNode.position, ignore) then break end

					lookaheadPosition = nextNode.position
					lookaheadCursor = nextCursor
					checkedNodes += 1
				end

				if lookaheadCursor ~= cursor then
					state.pathCursor = lookaheadCursor
					state.pathCommittedNodeId = state.path[lookaheadCursor]
					state.pathCommittedNodeTime = os.clock()
					state.pathCommittedNodeBestDistance = (lookaheadPosition - rootPart.Position).Magnitude
				end
				return lookaheadPosition
			end
			local edge = BotPlanner.getPathEdge(state.graph, state.path, state.pathCursor)
			if edge and edge.contactPosition and (state.lastPathAction == "SlideBoost" or state.lastPathAction == "Vault" or state.lastPathAction == "HighVault" or state.lastPathAction == "Swing") then
				state.pathActionTarget = nodePosition
				return edge.contactPosition
			end
			return nodePosition
		end

		cursor += 1
		state.pathCursor = cursor
		state.pathCommittedNodeId = nil
		state.pathCommittedNodeTime = 0
		state.pathCommittedNodeBestDistance = math.huge
	end

	return targetPosition
end

local function penalizeCurrentPathEdge(rootPart: BasePart, actionName: string)
	if not state.graph or #state.path <= 1 then return end

	local fromId = state.path[math.max(1, state.pathCursor - 1)]
	local toId = state.path[state.pathCursor]
	if fromId and toId then BotLearning.recordEdge(state.memory, fromId, toId, -8) end
	BotLearning.recordTech(state.memory, rootPart.Position, actionName, -6)
	BotLearning.recordDeadEnd(state.memory, rootPart.Position, -2)
	markMemoryDirty()
	clearPath()
end

local function registerDifficultRouteFailure(rootPart: BasePart, actionName: string, reason: string): boolean
	if not state.learningMode or not state.pathAttemptKey or #state.path <= 1 then
		if state.graph and #state.path > 1 then
			penalizeCurrentPathEdge(rootPart, actionName)
		else
			BotLearning.recordDeadEnd(state.memory, rootPart.Position, -2)
			BotLearning.recordTech(state.memory, rootPart.Position, actionName, -3)
			markMemoryDirty()
			clearPath()
		end
		return true
	end

	state.pathAttemptCount += 1
	if state.pathAttemptCount < Config.learningModeMaxRouteAttempts then
		if os.clock() - state.lastWallLogTime > 0.45 then
			state.lastWallLogTime = os.clock()
			pushLog(`Learning retry {state.pathAttemptCount}/{Config.learningModeMaxRouteAttempts} for route: {reason}.`)
		end
		return false
	end

	penalizeCurrentPathEdge(rootPart, actionName)
	state.pathAttemptKey = nil
	state.pathAttemptCount = 0
	if os.clock() - state.lastWallLogTime > 0.45 then
		state.lastWallLogTime = os.clock()
		pushLog(`Learning abandoned route after {Config.learningModeMaxRouteAttempts} tries: {reason}.`)
	end
	return true
end

local function getRunnerEscapePosition(rootPart: BasePart, threatPosition: Vector3, motorState: BotMotor.RMotorState): Vector3
	if not state.graph or #state.graph.nodes <= 0 then
		local delta = rootPart.Position - threatPosition
		local flatDelta = Vector3.new(delta.X, 0, delta.Z)
		return rootPart.Position + (if flatDelta.Magnitude > 0.1 then flatDelta.Unit else rootPart.CFrame.LookVector) * 48
	end

	local threatDistanceFromRoot = (rootPart.Position - threatPosition).Magnitude
	if motorState.stuckSeconds >= 0.25 or threatDistanceFromRoot <= Config.runnerPanicDistance then
		local startNode = BotAffordanceGraph.findNearestNode(state.graph, rootPart.Position, Config.maxTechNeighborRadius)
		if startNode then
			local open = { startNode.id }
			local visited = { [startNode.id] = true }
			local bestPosition: Vector3? = nil
			local bestScore = -math.huge
			local checked = 0
			local openIndex = 1

			while open[openIndex] and checked < Config.runnerExitSearchNodes do
				local node = state.graph.nodes[open[openIndex]]
				openIndex += 1
				if not node then continue end

				checked += 1
				local selfDistance = (node.position - rootPart.Position).Magnitude
				if selfDistance > Config.runnerExitSearchRadius then continue end

				local threatDistance = (node.position - threatPosition).Magnitude
				local openDirections = node.openDirections or 0
				local deadEndPenalty = BotLearning.getDeadEndPenalty(state.memory, node.position)
				local areaScore = BotLearning.getAreaScore(state.memory, node.position)
				local score = threatDistance * 0.85
					+ (node.escapeScore or 0) * 0.75
					+ (node.openness or 0) * 10
					+ openDirections * 2
					+ math.clamp(areaScore, -8, 8) * 0.5
					- selfDistance * 0.18
					- deadEndPenalty * 10
					- math.max(0, 3 - openDirections) * 12

				if score > bestScore and selfDistance >= Config.graphStep * 2 then
					bestScore = score
					bestPosition = node.position
				end

				for _, edge in node.edges do
					if visited[edge.to] then continue end

					local nextNode = state.graph.nodes[edge.to]
					if not nextNode then continue end
					local nextDistance = (nextNode.position - rootPart.Position).Magnitude
					if nextDistance > Config.runnerExitSearchRadius then continue end

					visited[edge.to] = true
					open[#open + 1] = edge.to
				end
			end

			if bestPosition then
				state.runnerGoalPosition = bestPosition
				state.lastRunnerEscapeTime = os.clock()
				return bestPosition
			end
		end
	end

	local now = os.clock()
	if state.runnerGoalPosition and now - state.lastRunnerEscapeTime < Config.runnerEscapeRefreshSeconds then
		return state.runnerGoalPosition
	end
	state.lastRunnerEscapeTime = now

	local bestPosition = state.runnerGoalPosition or rootPart.Position
	local bestScore = -math.huge
	local sampleCount = math.min(#state.graph.nodes, Config.runnerEscapeSamplesPerTick)

	for _ = 1, sampleCount do
		local node = state.graph.nodes[state.runnerEscapeCursor]
		state.runnerEscapeCursor += 1
		if state.runnerEscapeCursor > #state.graph.nodes then state.runnerEscapeCursor = 1 end
		if not node then continue end

		local threatDistance = (node.position - threatPosition).Magnitude
		local selfDistance = (node.position - rootPart.Position).Magnitude
		if selfDistance > 220 then continue end

		local deadEndPenalty = BotLearning.getDeadEndPenalty(state.memory, node.position)
		local areaScore = BotLearning.getAreaScore(state.memory, node.position)
		local escapeScore = node.escapeScore or 0
		local openDirections = node.openDirections or 0
		local openness = node.openness or 0
		local score = threatDistance * 1.05
			+ node.verticalScore * 0.035
			+ escapeScore * 0.45
			+ openness * 8
			+ openDirections * 1.2
			+ math.clamp(areaScore, -8, 8) * 0.4
			- node.wallPenalty * 3
			- deadEndPenalty * 8
			- selfDistance * 0.08
			- math.max(0, 3 - openDirections) * 10
		if score > bestScore then
			bestScore = score
			bestPosition = node.position
		end
	end

	state.runnerGoalPosition = bestPosition
	return bestPosition
end

local function updateRewards(rootPart: BasePart, targetRoot: BasePart)
	local now = os.clock()
	if now - state.lastRewardTime < 0.25 then return end
	state.lastRewardTime = now

	local distance = (rootPart.Position - targetRoot.Position).Magnitude
	local previousDistance = state.lastRewardDistance
	state.lastRewardDistance = distance
	if not previousDistance then return end

	local reward = 0
	if state.role == "Tagger" then
		reward = (previousDistance - distance) * 0.8
		if distance <= Config.tagRange then reward += 45 end
		if state.motorState.stuckSeconds > 0.4 then reward -= 3 end
	else
		reward = (distance - previousDistance) * 0.7
		reward += math.clamp(rootPart.AssemblyLinearVelocity.Magnitude / 32, 0, 1.5)
		if state.motorState.stuckSeconds > 0.4 then reward -= 4 end
		if BotLearning.getDeadEndPenalty(state.memory, rootPart.Position) > 0 then reward -= 2 end
	end

	state.rewardTotal += reward
	if math.abs(reward) >= 0.7 then
		BotLearning.recordArea(state.memory, rootPart.Position, reward)
		markMemoryDirty()
	end
	if BotTrainingRecorder.isEnabled(state.policyRecorder) and state.graph then
		local currentNode = BotAffordanceGraph.findNearestNode(state.graph, rootPart.Position, Config.copyPlayerMaxNodeDistance)
		local targetNode = BotAffordanceGraph.findNearestNode(state.graph, targetRoot.Position, Config.copyPlayerMaxNodeDistance)
		if currentNode and targetNode then
			local actionName = state.lastPathAction
			local edge = {
				action = actionName,
				cost = (targetNode.position - currentNode.position).Magnitude,
				heightDelta = targetNode.position.Y - currentNode.position.Y,
				to = targetNode.id,
			}
			BotTrainingRecorder.record(state.policyRecorder, {
				role = state.role,
				action = actionName,
				reward = math.clamp(reward, -8, 8),
				nodeId = currentNode.id,
				targetNodeId = targetNode.id,
				features = BotPolicy.makeFeatures(
					state.role,
					currentNode,
					targetNode,
					edge,
					targetNode,
					BotLearning.getDeadEndPenalty(state.memory, targetNode.position),
					BotLearning.getAreaScore(state.memory, targetNode.position),
					rootPart.AssemblyLinearVelocity.Magnitude
				),
				createdAt = os.time(),
			})
		end
	end
	if math.abs(reward) >= 1 or state.motorState.stuckSeconds > 0.4 then
		pushLog(`Reward {math.floor(reward * 10) / 10}; total {math.floor(state.rewardTotal * 10) / 10}; distance {math.floor(distance * 10) / 10}; tech {state.motorState.lastTechName} {state.motorState.lastTechResult}.`)
	end
end

local function getEdgeAction(fromNode: any, toNodeId: number): string?
	for _, edge in fromNode.edges do
		if edge.to == toNodeId then return edge.action end
	end

	return nil
end

local function updateCopyPlayerLearning()
	if not state.copyPlayerMode then return end
	if not state.graph or #state.graph.nodes <= 0 then return end

	local now = os.clock()
	if now - state.lastCopyPlayerSampleTime < Config.copyPlayerSampleSeconds then return end
	state.lastCopyPlayerSampleTime = now

	local playerRoot = getPlayerRoot()
	if not playerRoot then return end

	local playerNode = BotAffordanceGraph.findNearestNode(state.graph, playerRoot.Position, Config.copyPlayerMaxNodeDistance)
	if not playerNode then return end

	local previousPosition = state.lastCopyPlayerPosition
	local previousNodeId = state.lastCopyPlayerNodeId
	local botRoot = state.rootPart
	local distanceToBot = if botRoot then (playerRoot.Position - botRoot.Position).Magnitude else nil
	local previousDistanceToBot = state.lastCopyPlayerDistance

	state.lastCopyPlayerPosition = playerRoot.Position
	state.lastCopyPlayerNodeId = playerNode.id
	state.lastCopyPlayerDistance = distanceToBot

	if not previousPosition or not previousNodeId or previousNodeId == playerNode.id then return end

	local moved = (playerRoot.Position - previousPosition).Magnitude
	if moved < Config.copyPlayerMinMoveDistance then return end

	local previousNode = state.graph.nodes[previousNodeId]
	if not previousNode then return end

	local reward = math.clamp(moved / 4, 0, 4)
	local heightGain = playerRoot.Position.Y - previousPosition.Y
	if heightGain > Config.maxWalkHeight then reward += math.clamp(heightGain * 0.35, 1, 5) end
	if playerRoot.AssemblyLinearVelocity.Magnitude >= Config.botWalkSpeed then reward += 1.5 end

	if distanceToBot and previousDistanceToBot then
		local distanceChange = distanceToBot - previousDistanceToBot
		if state.role == "Runner" then
			reward += math.clamp(distanceChange * 0.35, -3, 4)
		else
			reward += math.clamp(-distanceChange * 0.25, -2, 3)
		end
	end

	BotLearning.recordArea(state.memory, playerRoot.Position, reward * 0.5)

	local actionName = getEdgeAction(previousNode, playerNode.id)
	if actionName then
		BotLearning.recordEdge(state.memory, previousNodeId, playerNode.id, reward)
		if actionName ~= "Walk" then
			BotLearning.recordTech(state.memory, previousPosition, actionName, reward)
		end
	end

	markMemoryDirty()
	if os.clock() - state.lastWallLogTime > 1 then
		state.lastWallLogTime = os.clock()
		pushLog(`Copied player route {previousNodeId}->{playerNode.id}; reward {math.floor(reward * 10) / 10}; action {actionName or "Walk"}.`)
	end
end

local function finishTechExperiment(rootPart: BasePart, goalPosition: Vector3)
	local experiment = state.activeTechExperiment
	if not experiment then return end
	if os.clock() - experiment.startTime < Config.techAttemptScoreSeconds then return end

	state.activeTechExperiment = nil
	local endDistance = (rootPart.Position - goalPosition).Magnitude
	local distanceGain = experiment.startDistance - endDistance
	local heightGain = rootPart.Position.Y - experiment.startY
	local reward = 0

	if distanceGain >= Config.techSuccessDistanceGain then reward += 8 + distanceGain end
	if heightGain >= Config.techSuccessHeightGain then reward += 6 + heightGain * 0.5 end
	if distanceGain < 0.5 and heightGain < 1 then reward -= 6 end
	if (rootPart.Position - experiment.startPosition).Magnitude < 2 then reward -= 5 end

	BotLearning.recordTech(state.memory, experiment.startPosition, experiment.actionName, reward)
	markMemoryDirty()
	if reward > 0 then
		pushLog(
			`Learned {experiment.actionName} worked: reward {math.floor(reward * 10) / 10}, gain {math.floor(distanceGain * 10) / 10}, height {math.floor(heightGain * 10) / 10}.`
		)
	else
		pushLog(
			`Learned {experiment.actionName} failed here: reward {math.floor(reward * 10) / 10}, gain {math.floor(distanceGain * 10) / 10}, height {math.floor(heightGain * 10) / 10}.`
		)
	end
end

local function makeSlideBoostActionName(holdSeconds: number, jumpDelaySeconds: number, jumpWallClearance: number, backoffDistance: number): string
	return `SlideBoost@{math.floor(holdSeconds * 1000 + 0.5)}:{math.floor(jumpDelaySeconds * 1000 + 0.5)}:{math.floor(jumpWallClearance + 0.5)}:{math.floor(backoffDistance + 0.5)}`
end

local function getBestSlideBoostAction(rootPart: BasePart): string?
	local bestAction: string? = nil
	local bestScore = -math.huge
	local holdSeconds = Config.slideBoostHoldMinSeconds

	while holdSeconds <= Config.slideBoostHoldMaxSeconds + 0.001 do
		local jumpDelaySeconds = Config.slideBoostJumpDelayMinSeconds
		while jumpDelaySeconds <= Config.slideBoostJumpDelayMaxSeconds + 0.001 do
			local jumpWallClearance = Config.slideBoostJumpWallClearanceMin
			while jumpWallClearance <= Config.slideBoostJumpWallClearanceMax + 0.001 do
				local backoffDistance = Config.slideBoostBackoffMinDistance
				while backoffDistance <= Config.slideBoostBackoffMaxDistance + 0.001 do
					local actionName = makeSlideBoostActionName(holdSeconds, jumpDelaySeconds, jumpWallClearance, backoffDistance)
					local attempts = state.memory.techAttempts[BotLearning.techKey(rootPart.Position, actionName)] or 0
					local score = BotLearning.getTechScore(state.memory, rootPart.Position, actionName)
						+ (if attempts <= 0 then 3 else math.max(0, 1.5 - attempts * 0.25))

					if score > bestScore then
						bestScore = score
						bestAction = actionName
					end

					backoffDistance += Config.slideBoostBackoffStepDistance
				end
				jumpWallClearance += Config.slideBoostJumpWallClearanceStep
			end

			jumpDelaySeconds += Config.slideBoostJumpDelayStepSeconds
		end
		holdSeconds += Config.slideBoostHoldStepSeconds
	end

	return bestAction
end

local function addSlideBoostTimingActions(actions: { string }, rootPart: BasePart)
	local bestAction = getBestSlideBoostAction(rootPart)
	if bestAction then actions[#actions + 1] = bestAction end
end

local function chooseExperimentalAction(rootPart: BasePart, goalPosition: Vector3): string
	local actions = { "Vault", "Swing", "Jump", "Roll" }
	addSlideBoostTimingActions(actions, rootPart)
	local rollDelay = os.clock() - state.motorState.lastRollTime
	if rollDelay >= Config.rollBoostMinDelaySeconds and rollDelay <= Config.rollBoostMaxDelaySeconds then
		actions[#actions + 1] = "RollBoost"
	end
	if state.techExperimentCursor > #actions then state.techExperimentCursor = 1 end
	local bestAction = actions[state.techExperimentCursor]
	local bestScore = -math.huge
	local goalDelta = goalPosition - rootPart.Position
	local needsVerticality = goalDelta.Y > Config.maxWalkHeight

	for actionIndex, actionName in actions do
		local attempts = state.memory.techAttempts[BotLearning.techKey(rootPart.Position, actionName)] or 0
		local learnedScore = BotLearning.getTechScore(state.memory, rootPart.Position, actionName)
		local exploreBonus = if attempts <= 0 then 5 else math.max(0, 2 - attempts * 0.35)
		local score = learnedScore + exploreBonus

		if string.find(actionName, "SlideBoost") == 1 then
			score += if needsVerticality or state.motorState.stuckSeconds > 0.2 then 4 else 0.8
		elseif actionName == "Vault" then
			score += if needsVerticality or state.motorState.stuckSeconds > 0.2 then 3 else 1
		elseif actionName == "Swing" then
			score += if needsVerticality or state.motorState.stuckSeconds > 0.2 then 3 else 0.5
		elseif actionName == "RollBoost" then
			score += if needsVerticality then 1 else 0.5
		elseif actionName == "Jump" then
			score += 0.25
		end

		if actionIndex == state.techExperimentCursor then score += 0.5 end

		if score > bestScore then
			bestScore = score
			bestAction = actionName
		end
	end

	state.techExperimentCursor += 1
	if state.techExperimentCursor > #actions then state.techExperimentCursor = 1 end
	return bestAction
end

local function tryExploreTech(rootPart: BasePart, humanoid: Humanoid, goalPosition: Vector3, moveTarget: Vector3, ignore: { Instance }): boolean
	if state.activeTechExperiment then return false end
	if os.clock() - state.lastTechExploreTime < Config.techExploreCooldownSeconds then return false end
	if (moveTarget - rootPart.Position).Magnitude < Config.minUsefulMoveTargetDistance then return false end
	local flatMoveTargetDistance = Vector3.new(moveTarget.X - rootPart.Position.X, 0, moveTarget.Z - rootPart.Position.Z).Magnitude
	if flatMoveTargetDistance < Config.minUsefulMoveTargetDistance and moveTarget.Y - rootPart.Position.Y > Config.maxWalkHeight then return false end
	if state.motorState.stuckSeconds < 0.18 and moveTarget.Y - rootPart.Position.Y <= Config.maxWalkHeight then return false end

	local actionName = chooseExperimentalAction(rootPart, goalPosition)
	local delta = moveTarget - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	local direction = if flatDelta.Magnitude > 0.1 then flatDelta.Unit else rootPart.CFrame.LookVector
	local experimentTarget = moveTarget
	if string.find(actionName, "SlideBoost") == 1 then
		local clearance = BotMotor.getForwardClearance(rootPart, direction, ignore)
		if clearance > Config.slideBoostMaxWallClearance then
			BotLearning.recordTech(state.memory, rootPart.Position, actionName, -2)
			markMemoryDirty()
			if os.clock() - state.lastWallLogTime > 0.45 then
				state.lastWallLogTime = os.clock()
				pushLog(`Experiment {actionName} skipped: wall clearance {if clearance == math.huge then "none" else math.floor(clearance * 10) / 10}.`)
			end
			state.lastTechExploreTime = os.clock()
			return false
		end
		experimentTarget = rootPart.Position + direction * 12 + Vector3.yAxis * math.max(12, moveTarget.Y - rootPart.Position.Y)
	elseif actionName == "RollBoost" then
		experimentTarget = rootPart.Position + direction * 10
	end

	local startDistance = (rootPart.Position - goalPosition).Magnitude
	local didStart = BotMotor.executeExperimentalAction(state.motorState, rootPart, humanoid, experimentTarget, actionName, ignore)
	state.lastTechExploreTime = os.clock()

	if not didStart then
		if state.motorState.lastTechResult == "Cooldown" then return false end
		BotLearning.recordTech(state.memory, rootPart.Position, actionName, -2)
		markMemoryDirty()
		if os.clock() - state.lastWallLogTime > 0.45 then
			state.lastWallLogTime = os.clock()
			pushLog(`Experiment {actionName} blocked: {state.motorState.lastTechResult}.`)
		end
		return false
	end

	state.activeTechExperiment = {
		actionName = actionName,
		startPosition = rootPart.Position,
		startDistance = startDistance,
		startY = rootPart.Position.Y,
		startTime = os.clock(),
	}
	pushLog(`Experimenting with {actionName}; scoring in {Config.techAttemptScoreSeconds}s.`)
	return true
end

local function rotateFlatDirection(direction: Vector3, degrees: number): Vector3
	local radians = math.rad(degrees)
	local cos = math.cos(radians)
	local sin = math.sin(radians)
	return Vector3.new(direction.X * cos - direction.Z * sin, 0, direction.X * sin + direction.Z * cos)
end

local function getLocalAvoidanceTarget(rootPart: BasePart, moveTarget: Vector3, goalPosition: Vector3, ignore: { Instance }): Vector3?
	local delta = moveTarget - rootPart.Position
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	if flatDelta.Magnitude < Config.minUsefulMoveTargetDistance then return nil end

	local forwardDirection = flatDelta.Unit
	local forwardClearance = BotMotor.getForwardClearance(rootPart, forwardDirection, ignore)
	if forwardClearance > Config.wallProbeDistance then return nil end

	local currentGoalDistance = (rootPart.Position - goalPosition).Magnitude
	local bestTarget: Vector3? = nil
	local bestScore = -math.huge

	for _, angle in { 45, -45, 75, -75, 105, -105, 135, -135 } do
		local direction = rotateFlatDirection(forwardDirection, angle)
		local clearance = BotMotor.getForwardClearance(rootPart, direction, ignore)
		if clearance <= Config.wallProbeDistance then continue end

		local distance = math.min(clearance - 1, Config.localAvoidanceTargetDistance)
		if distance < Config.minUsefulMoveTargetDistance then continue end

		local candidate = rootPart.Position + direction * distance
		local progress = currentGoalDistance - (candidate - goalPosition).Magnitude
		local score = progress * Config.localAvoidanceProgressWeight
			+ math.min(clearance, Config.localAvoidanceTargetDistance) * Config.localAvoidanceClearanceWeight
			- math.abs(angle) * 0.015

		if score > bestScore then
			bestScore = score
			bestTarget = candidate
		end
	end

	if bestTarget then
		BotLearning.recordDeadEnd(state.memory, rootPart.Position, -1)
		markMemoryDirty()
	end

	return bestTarget
end

local function getLocalBotTaggedEvent(): BindableEvent
	local event = ReplicatedStorage:FindFirstChild("LocalBotTagged")
	if event and event:IsA("BindableEvent") then return event end

	local newEvent = Instance.new("BindableEvent")
	newEvent.Name = "LocalBotTagged"
	newEvent.Parent = ReplicatedStorage
	return newEvent
end

local function applyAiTagKnockback(taggerRoot: BasePart, targetRoot: BasePart)
	KnockbackVelocity.apply({
		targetRootPart = targetRoot,
		originPosition = taggerRoot.Position,
		sourceVelocity = taggerRoot.AssemblyLinearVelocity,
		sourceRightVector = taggerRoot.CFrame.RightVector,
		knockbackType = "LocalBotTag",
	})
	KnockbackVelocity.apply({
		targetRootPart = taggerRoot,
		originPosition = targetRoot.Position,
		sourceVelocity = targetRoot.AssemblyLinearVelocity,
		sourceRightVector = targetRoot.CFrame.RightVector,
		knockbackType = "LocalBotTag",
	})
end

local function tryBotTagBot(taggerBot: Model, taggerRoot: BasePart, taggerRole: "Tagger" | "Runner", targetBot: Model, targetRoot: BasePart, targetRole: "Tagger" | "Runner"): boolean
	if os.clock() - state.lastBotTagTime < Config.taggerRestartDelaySeconds then return false end
	if not botCanTag(taggerBot) then return false end
	if (taggerRoot.Position - targetRoot.Position).Magnitude > Config.tagRange then return false end

	local canTag, taggerNewRole, targetNewRole = canRoleTag(taggerRole, targetRole)
	if not canTag or not taggerNewRole or not targetNewRole then return false end

	local durability = targetBot:GetAttribute("NTBDurability")
	if typeof(durability) == "number" and durability > 0 then
		targetBot:SetAttribute("NTBDurability", durability - 1)
		state.lastBotTagTime = os.clock()
		return false
	end

	local nextTaggerRole = normalizeBotRole(taggerNewRole)
	local nextTargetRole = normalizeBotRole(targetNewRole)
	if not nextTaggerRole or not nextTargetRole then return false end

	applyBotRole(taggerBot, nextTaggerRole)
	applyBotRole(targetBot, nextTargetRole)
	grantBotNtb(taggerBot)
	grantBotNtb(targetBot)
	lockBotTagging(targetBot, Config.botTagLockoutAfterTaggedSeconds)
	applyAiTagKnockback(taggerRoot, targetRoot)
	state.lastBotTagTime = os.clock()
	clearPath()
	pushLog(`Bot tag: {taggerBot.Name} -> {targetBot.Name}.`)
	return true
end

local function tryBotTagPlayer(bot: Model, rootPart: BasePart, roleName: "Tagger" | "Runner", targetRoot: BasePart): boolean
	if os.clock() - state.lastBotTagTime < Config.taggerRestartDelaySeconds then return false end
	if not botCanTag(bot) then return false end
	if (rootPart.Position - targetRoot.Position).Magnitude > Config.tagRange then return false end

	local success, result = pcall(function()
		return BotTagRF:InvokeServer(roleName, targetRoot, rootPart.Position)
	end)
	if not success or typeof(result) ~= "table" then return false end
	if result.success ~= true then return false end
	local nextBotRole = normalizeBotRole(tostring(result.botRole))
	if nextBotRole then applyBotRole(bot, nextBotRole) end
	grantBotNtb(bot)
	KnockbackVelocity.apply({
		targetRootPart = rootPart,
		originPosition = targetRoot.Position,
		sourceVelocity = targetRoot.AssemblyLinearVelocity,
		sourceRightVector = targetRoot.CFrame.RightVector,
		knockbackType = "LocalBotTag",
	})
	state.lastBotTagTime = os.clock()
	clearPath()
	pushLog(`Bot tagged player; bot is now {tostring(result.botRole)}.`)
	return true
end

local function createBotClone(name: string, cframe: CFrame, roleName: "Tagger" | "Runner"): (Model?, Humanoid?, BasePart?)
	local character = localPlayer.Character
	if not character then return nil, nil, nil end

	local oldArchivable = character.Archivable
	character.Archivable = true
	local bot = character:Clone()
	character.Archivable = oldArchivable

	bot.Name = name
	destroyScripts(bot)
	bot.Parent = getBotsFolder()

	local rootPart = bot:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = bot:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then
		bot:Destroy()
		return nil, nil, nil
	end

	rootPart.CFrame = cframe
	humanoid.WalkSpeed = Config.botWalkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.botJumpPower
	bot:SetAttribute("MinRunSpeed", Config.botWalkSpeed)
	bot:SetAttribute("MaxRunSpeed", Config.botWalkSpeed)
	bot:SetAttribute("MinJumpPower", Config.botJumpPower)
	bot:SetAttribute("MaxJumpPower", Config.botJumpPower)
	applyBotRole(bot, roleName)
	grantBotNtb(bot)

	return bot, humanoid, rootPart
end

local function updateManualRun(dt: number)
	local rootPart = state.rootPart
	local humanoid = state.humanoid
	local goalPosition = state.manualGoalPosition
	if not rootPart or not humanoid or not rootPart.Parent or not humanoid.Parent or not goalPosition then return end

	local ignore = getIgnoreList()
	if state.pathGoalPosition and (goalPosition - state.pathGoalPosition).Magnitude >= Config.stalePathGoalDistance then
		clearPath()
	end
	BotMotor.updateProgress(state.motorState, rootPart, goalPosition, dt)
	finishTechExperiment(rootPart, goalPosition)
	updatePlanner(rootPart, goalPosition)

	local moveTarget = getPathTarget(rootPart, goalPosition, ignore)
	local avoidanceTarget = getLocalAvoidanceTarget(rootPart, moveTarget, goalPosition, ignore)
	if avoidanceTarget then
		moveTarget = avoidanceTarget
		state.lastPathAction = "Walk"
	end
	state.lastMoveTarget = moveTarget
	BotMotor.moveToward(rootPart, humanoid, moveTarget)
	BotMotor.faceMoveDirection(rootPart, moveTarget, dt)

	if (goalPosition - rootPart.Position).Magnitude <= Config.graphStep * 1.5 then
		state.manualReached = true
		state.manualRunActive = false
		state.enabled = false
		state.status = "Manual goal reached"
		pushLog("Manual test reached goal.")
		refreshVisuals()
		return
	end

	local moveTargetDistance = (moveTarget - rootPart.Position).Magnitude
	if
		state.lastPathAction ~= "Walk"
		and moveTargetDistance <= math.max(Config.graphStep * 1.8, 7)
		and (state.lastPathAction == "SlideBoost" or moveTargetDistance >= Config.minUsefulMoveTargetDistance)
	then
		local actionName = if state.lastPathAction == "SlideBoost" then getBestSlideBoostAction(rootPart) or "SlideBoost" else state.lastPathAction
		local actionTarget = state.pathActionTarget or moveTarget
		local executed = if actionName == state.lastPathAction
			then BotMotor.executePlannedAction(state.motorState, rootPart, humanoid, actionTarget, state.lastPathAction, ignore)
			else BotMotor.executeExperimentalAction(state.motorState, rootPart, humanoid, actionTarget, actionName, ignore)
		if executed and os.clock() - state.lastWallLogTime > 0.45 then
			state.lastWallLogTime = os.clock()
			pushLog(`Manual action {actionName}: {state.motorState.lastTechResult}.`)
		elseif not executed and state.motorState.lastTechResult ~= "Cooldown" then
			registerDifficultRouteFailure(rootPart, actionName, state.motorState.lastTechResult)
		end
	end

	tryExploreTech(rootPart, humanoid, goalPosition, moveTarget, ignore)

	refreshVisuals()
end

local function updateOpponentBot(dt: number)
	if not state.duelMode then return end
	local rootPart = state.opponentRootPart
	local humanoid = state.opponentHumanoid
	local mainRoot = state.rootPart
	local mainBot = state.bot
	if not rootPart or not humanoid or not mainRoot or not mainBot then return end
	if not rootPart.Parent or not humanoid.Parent or not mainRoot.Parent then return end

	local ignore = getIgnoreList()
	local targetPosition = if state.opponentRole == "Runner"
		then getRunnerEscapePosition(rootPart, mainRoot.Position, state.opponentMotorState)
		else mainRoot.Position
	BotMotor.updateProgress(state.opponentMotorState, rootPart, targetPosition, dt)
	BotMotor.tryTrampoline(state.opponentMotorState, rootPart, humanoid, ignore)
	local avoidanceTarget = getLocalAvoidanceTarget(rootPart, targetPosition, targetPosition, ignore)
	if avoidanceTarget then targetPosition = avoidanceTarget end
	BotMotor.moveToward(rootPart, humanoid, targetPosition)
	BotMotor.faceMoveDirection(rootPart, targetPosition, dt)

	if state.opponentRole == "Tagger" then
		local opponentBot = state.opponentBot
		if opponentBot then tryBotTagBot(opponentBot, rootPart, state.opponentRole, mainBot, mainRoot, state.role) end
	end
end

local function updateBot(dt: number)
	if state.manualRunActive then
		updateManualRun(dt)
		return
	end

	if state.graph and (not state.graphMapRoot or state.graphMapRoot.Parent == nil or state.graphMapRoot ~= workspace:FindFirstChild("Map")) then
		state.graph = nil
		state.graphMapRoot = nil
		clearPath()
		state.status = "Graph cleared: active workspace.Map changed"
		pushLog("Graph cleared because the server map changed. Rebuild the graph.")
	end

	local rootPart = state.rootPart
	local humanoid = state.humanoid
	if not rootPart or not humanoid or not rootPart.Parent or not humanoid.Parent then return end

	local targetRoot = getTargetRoot()
	if not targetRoot then return end

	local now = os.clock()
	local targetPosition = if state.role == "Runner" then getRunnerEscapePosition(rootPart, targetRoot.Position, state.motorState) else targetRoot.Position
	local ignore = getIgnoreList()
	local activeTargetPosition = targetPosition
	if state.pathGoalPosition and (targetPosition - state.pathGoalPosition).Magnitude >= Config.stalePathGoalDistance then
		clearPath()
		state.backtrackTarget = nil
		state.backtrackUntil = 0
	end
	if state.backtrackTarget then
		if now >= state.backtrackUntil or (state.backtrackTarget - rootPart.Position).Magnitude <= Config.graphStep * 1.5 then
			state.backtrackTarget = nil
			state.backtrackUntil = 0
		else
			activeTargetPosition = state.backtrackTarget
		end
	end
	if state.role == "Tagger" and now - state.lastDirectLineTime >= Config.directLineRefreshSeconds then
		state.lastDirectLineTime = now
		state.cachedDirectLine = BotMotor.hasDirectLine(rootPart, targetRoot.Position, ignore)
	elseif state.role ~= "Tagger" then
		state.cachedDirectLine = false
	end
	local directLine = state.cachedDirectLine
	local distance = (activeTargetPosition - rootPart.Position).Magnitude
	local needsVerticalRoute = activeTargetPosition.Y - rootPart.Position.Y >= Config.verticalRouteHeight
	local targetDelta = activeTargetPosition - rootPart.Position
	local flatTargetDelta = Vector3.new(targetDelta.X, 0, targetDelta.Z)
	if state.role == "Tagger" and needsVerticalRoute and flatTargetDelta.Magnitude <= Config.verticalUnderTargetFlatDistance then
		local verticalEscapeTarget = getBacktrackTarget(rootPart, activeTargetPosition)
		if verticalEscapeTarget then
			activeTargetPosition = verticalEscapeTarget
			state.backtrackTarget = verticalEscapeTarget
			state.backtrackUntil = now + Config.backtrackSeconds
			targetDelta = activeTargetPosition - rootPart.Position
			flatTargetDelta = Vector3.new(targetDelta.X, 0, targetDelta.Z)
			distance = (activeTargetPosition - rootPart.Position).Magnitude
			needsVerticalRoute = activeTargetPosition.Y - rootPart.Position.Y >= Config.verticalRouteHeight
			if os.clock() - state.lastStuckLogTime > 0.75 then
				state.lastStuckLogTime = os.clock()
				pushLog("Target is above; choosing an outward route instead of running underneath.")
			end
		end
	end
	local wallAhead = false
	if flatTargetDelta.Magnitude >= Config.minUsefulMoveTargetDistance then
		wallAhead = BotMotor.getForwardClearance(rootPart, flatTargetDelta.Unit, ignore) <= Config.wallProbeDistance
	end
	updateRewards(rootPart, targetRoot)
	finishTechExperiment(rootPart, activeTargetPosition)

	BotMotor.updateProgress(state.motorState, rootPart, activeTargetPosition, dt)
	BotMotor.tryTrampoline(state.motorState, rootPart, humanoid, ignore)

	if state.motorState.stuckSeconds >= Config.stuckSeconds and now - state.lastStuckReplanTime >= Config.stuckReplanCooldownSeconds then
		state.lastStuckReplanTime = now
		local abandonedRoute = registerDifficultRouteFailure(rootPart, state.lastPathAction, "stuck/no progress")
		if abandonedRoute then
			local backtrackTarget = getBacktrackTarget(rootPart, targetPosition)
			if backtrackTarget then
				state.backtrackTarget = backtrackTarget
				state.backtrackUntil = now + Config.backtrackSeconds
				activeTargetPosition = backtrackTarget
			end
			if os.clock() - state.lastStuckLogTime > 0.75 then
				state.lastStuckLogTime = os.clock()
				pushLog(if backtrackTarget then "Learning picked a different route; backtracking through graph." else "Learning marked route bad and forced a replan.")
			end
		end
	end

	local shouldPlan = state.role == "Runner"
		or needsVerticalRoute
		or wallAhead
		or not directLine
		or distance > Config.directChaseDistance
		or state.motorState.stuckSeconds > 0.12
		or (state.graph ~= nil and distance > 28 and now - state.lastPlannerTime > 0.8)
	if shouldPlan then updatePlanner(rootPart, activeTargetPosition) end

	local moveTarget = if shouldPlan then getPathTarget(rootPart, activeTargetPosition, ignore) else activeTargetPosition
	local avoidanceTarget = getLocalAvoidanceTarget(rootPart, moveTarget, activeTargetPosition, ignore)
	if avoidanceTarget then
		moveTarget = avoidanceTarget
		state.lastPathAction = "Walk"
		if os.clock() - state.lastWallLogTime > 0.65 then
			state.lastWallLogTime = os.clock()
			pushLog("Wall ahead; using local avoidance while graph replans.")
		end
	end
	if
		state.lastPathAction == "Walk"
		and (needsVerticalRoute or wallAhead or state.motorState.stuckSeconds > 0.2)
	then
		local vaultTarget = BotMotor.findVaultableTarget(rootPart, activeTargetPosition, ignore)
		if vaultTarget then
			moveTarget = vaultTarget
			state.pathActionTarget = vaultTarget
			state.lastPathAction = "Vault"
		end
	end
	state.lastMoveTarget = moveTarget
	BotMotor.moveToward(rootPart, humanoid, moveTarget)
	BotMotor.faceMoveDirection(rootPart, moveTarget, dt)

	local executedPathAction = false
	local moveTargetDistance = (moveTarget - rootPart.Position).Magnitude
	if
		shouldPlan
		and state.lastPathAction ~= "Walk"
		and moveTargetDistance <= math.max(Config.graphStep * 1.8, 7)
		and (state.lastPathAction == "SlideBoost" or moveTargetDistance >= Config.minUsefulMoveTargetDistance)
	then
		local actionName = if state.lastPathAction == "SlideBoost" then getBestSlideBoostAction(rootPart) or "SlideBoost" else state.lastPathAction
		local actionTarget = state.pathActionTarget or moveTarget
		executedPathAction = if actionName == state.lastPathAction
			then BotMotor.executePlannedAction(state.motorState, rootPart, humanoid, actionTarget, state.lastPathAction, ignore)
			else BotMotor.executeExperimentalAction(state.motorState, rootPart, humanoid, actionTarget, actionName, ignore)
		if executedPathAction and os.clock() - state.lastWallLogTime > 0.45 then
			state.lastWallLogTime = os.clock()
			pushLog(`Executed path action {actionName}: {state.motorState.lastTechResult}.`)
		elseif not executedPathAction and state.motorState.lastTechResult ~= "Cooldown" then
			registerDifficultRouteFailure(rootPart, actionName, state.motorState.lastTechResult)
		end
	end

	if executedPathAction then
		local bot = state.bot
		if state.duelMode and bot and state.opponentBot and state.opponentRootPart and state.role == "Tagger" then
			tryBotTagBot(bot, rootPart, state.role, state.opponentBot, state.opponentRootPart, state.opponentRole)
		elseif not state.duelMode and state.bot and state.role == "Tagger" then
			tryBotTagPlayer(state.bot, rootPart, state.role, targetRoot)
		end
		refreshVisuals()
		return
	end

	if tryExploreTech(rootPart, humanoid, activeTargetPosition, moveTarget, ignore) then
		local bot = state.bot
		if state.duelMode and bot and state.opponentBot and state.opponentRootPart and state.role == "Tagger" then
			tryBotTagBot(bot, rootPart, state.role, state.opponentBot, state.opponentRootPart, state.opponentRole)
		elseif not state.duelMode and state.bot and state.role == "Tagger" then
			tryBotTagPlayer(state.bot, rootPart, state.role, targetRoot)
		end
		refreshVisuals()
		return
	end

	local flatMoveTargetDistance = Vector3.new(moveTarget.X - rootPart.Position.X, 0, moveTarget.Z - rootPart.Position.Z).Magnitude
	if
		moveTargetDistance >= Config.minUsefulMoveTargetDistance
		and flatMoveTargetDistance >= Config.minUsefulMoveTargetDistance
		and moveTarget.Y - rootPart.Position.Y > Config.maxWalkHeight
	then
		if not BotMotor.tryVault(state.motorState, rootPart, humanoid, moveTarget, ignore) then
			BotMotor.tryJump(state.motorState, humanoid)
		else
			pushLog(state.motorState.lastTechResult)
		end
	elseif state.motorState.stuckSeconds > 0.35 then
		if not BotMotor.tryVault(state.motorState, rootPart, humanoid, moveTarget, ignore) then
			if not BotMotor.tryJump(state.motorState, humanoid) then
				BotLearning.recordDeadEnd(state.memory, rootPart.Position, -3)
				markMemoryDirty()
				if os.clock() - state.lastWallLogTime > 0.5 then
					state.lastWallLogTime = os.clock()
					pushLog(`Wall recovery failed: {state.motorState.lastTechName} {state.motorState.lastTechResult}.`)
				end
			end
		else
			if os.clock() - state.lastWallLogTime > 0.5 then
				state.lastWallLogTime = os.clock()
				pushLog(`Wall recovery vault: {state.motorState.lastTechResult}.`)
			end
		end
	end

	local bot = state.bot
	if state.duelMode and bot and state.opponentBot and state.opponentRootPart and state.role == "Tagger" then
		tryBotTagBot(bot, rootPart, state.role, state.opponentBot, state.opponentRootPart, state.opponentRole)
	elseif not state.duelMode and state.bot and state.role == "Tagger" then
		tryBotTagPlayer(state.bot, rootPart, state.role, targetRoot)
	end
	updateOpponentBot(dt)
	refreshVisuals()
end

function BotRuntime.buildGraph()
	local map = workspace:FindFirstChild("Map")
	if not map or not (map:IsA("Model") or map:IsA("Folder")) then
		state.status = "Cannot build graph: workspace.Map is missing"
		pushLog("Cannot build graph: wait for the server-spawned workspace.Map.")
		return
	end

	state.scanJob = BotMapScanner.createJob()
	state.graph = nil
	state.graphMapRoot = nil
	clearPath()
	state.status = `Scanning graph from {map:GetFullName()}`
	pushLog(`Graph scan started from {map:GetFullName()}.`)
end

function BotRuntime.spawnBot()
	local targetRoot = getPlayerRoot()
	if not targetRoot then
		state.status = "No local character"
		return
	end

	local bot, humanoid, rootPart = createBotClone("LightweightBot", targetRoot.CFrame + targetRoot.CFrame.LookVector * 18 + Vector3.yAxis * 3, "Tagger")
	if not bot or not rootPart or not humanoid then
		state.status = "Clone missing humanoid/root"
		return
	end

	destroyCurrentBot()
	state.bot = bot
	state.humanoid = humanoid
	state.rootPart = rootPart
	applyBotRole(bot, "Tagger")
	state.animationCleanup = BotAnimator.attach(bot)
	state.motorState = BotMotor.createState()
	state.lastRewardDistance = nil
	state.rewardTotal = 0
	clearPath()
	state.status = "Bot spawned"
	pushLog("Bot spawned.")
end

function BotRuntime.toggleDuelMode()
	state.duelMode = not state.duelMode
	if not state.duelMode then
		destroyOpponentBot()
		clearPath()
		pushLog("Two-bot training disabled.")
		return
	end

	local playerRoot = getPlayerRoot()
	if not playerRoot then
		state.duelMode = false
		pushLog("Cannot start two-bot training: no player root.")
		return
	end

	if not state.bot then BotRuntime.spawnBot() end
	destroyOpponentBot()
	local bot, humanoid, rootPart = createBotClone("LightweightRunnerBot", playerRoot.CFrame - playerRoot.CFrame.LookVector * 18 + Vector3.yAxis * 3, "Runner")
	if not bot or not humanoid or not rootPart then
		state.duelMode = false
		pushLog("Cannot start two-bot training: clone failed.")
		return
	end

	state.opponentBot = bot
	state.opponentHumanoid = humanoid
	state.opponentRootPart = rootPart
	state.opponentRole = "Runner"
	state.opponentMotorState = BotMotor.createState()
	state.opponentAnimationCleanup = BotAnimator.attach(bot)
	applyBotRole(bot, "Runner")
	clearPath()
	pushLog("Two-bot training enabled.")
end

function BotRuntime.setEnabled(enabled: boolean)
	state.enabled = enabled
	state.status = if enabled then "Training enabled" else "Training paused"
	pushLog(state.status)
	if not enabled then saveGlobalMemory(true) end
	if not enabled and state.manualRunActive and state.manualStartPosition and state.rootPart then
		state.rootPart.CFrame = CFrame.new(state.manualStartPosition + Vector3.yAxis * 2)
		state.manualRunActive = false
		state.manualReached = false
		clearPath()
		pushLog("Manual run stopped; bot returned to start.")
	end
end

function BotRuntime.toggleEnabled()
	BotRuntime.setEnabled(not state.enabled)
end

function BotRuntime.getStatus(): string
	return state.status
end

function BotRuntime.getStats(): (number, number, boolean, string, number)
	local nodeCount = if state.graph then #state.graph.nodes else 0
	local pathCount = #state.path
	return nodeCount, pathCount, state.enabled, state.role, state.rewardTotal
end

function BotRuntime.getThoughtInfo(): string
	local pathCost = 0
	local pathDistance = 0
	if state.graph then pathCost, pathDistance = BotPlanner.estimatePathCost(state.graph, state.path, state.pathCursor) end

	local eta = if pathDistance > 0 then pathDistance / Config.botWalkSpeed else 0
	local targetText = if state.lastMoveTarget
		then `{math.floor(state.lastMoveTarget.X)}, {math.floor(state.lastMoveTarget.Y)}, {math.floor(state.lastMoveTarget.Z)}`
		else "none"
	local manualText = if state.manualRunActive then "manual" else "normal"
	local experimentText = if state.activeTechExperiment
		then `{state.activeTechExperiment.actionName} {math.floor((os.clock() - state.activeTechExperiment.startTime) * 10) / 10}s`
		else "none"
	local mapText = "none"
	if state.graph and state.rootPart then
		local node = BotAffordanceGraph.findNearestNode(state.graph, state.rootPart.Position, Config.maxTechNeighborRadius)
		if node then
			mapText = `open {node.openDirections}/8 | wall {math.floor((node.nearestWallDistance or 0) * 10) / 10} | escape {math.floor((node.escapeScore or 0) * 10) / 10} | drop {math.floor((node.dropHeight or 0) * 10) / 10}`
		end
	end

	return table.concat({
		`Mode: {manualText}`,
		`Two bots: {state.duelMode} | opponent {state.opponentRole}`,
		`Learning mode: {state.learningMode} | copy player {state.copyPlayerMode} | route tries {state.pathAttemptCount}/{Config.learningModeMaxRouteAttempts}`,
		`Policy recorder: {BotTrainingRecorder.isEnabled(state.policyRecorder)} | samples {BotTrainingRecorder.count(state.policyRecorder)}/{state.policyRecorder.maxSamples}`,
		`Visuals: {state.visualize} | nodes {state.visualizeGraphNodes} | all {state.visualizeAllGraphNodes} | edges {state.visualizeGraphEdges}`,
		`Global memory: loaded {state.memoryLoaded} | dirty {state.memoryDirty} | saving {state.memorySaving}`,
		`Next action: {state.lastPathAction}`,
		`Experiment: {experimentText}`,
		`Map state: {mapText}`,
		`Move target: {targetText}`,
		`Path cursor: {state.pathCursor}/{#state.path}`,
		`Cost: {math.floor(pathCost * 10) / 10}`,
		`Distance: {math.floor(pathDistance * 10) / 10}`,
		`ETA rough: {math.floor(eta * 10) / 10}s`,
		`Tech: {state.motorState.lastTechName} {state.motorState.lastTechResult}`,
		`Stuck: {math.floor(state.motorState.stuckSeconds * 10) / 10}s`,
	}, "\n")
end

function BotRuntime.getLogs(): { string }
	return state.logs
end

function BotRuntime.toggleRole()
	state.role = if state.role == "Tagger" then "Runner" else "Tagger"
	if state.bot then applyBotRole(state.bot, state.role) end
	state.lastRewardDistance = nil
	clearPath()
	pushLog(`Role changed to {state.role}.`)
end

function BotRuntime.toggleLearningMode()
	state.learningMode = not state.learningMode
	state.pathAttemptKey = nil
	state.pathAttemptCount = 0
	pushLog(if state.learningMode then "Learning mode enabled: routes retry up to 3 times." else "Learning mode disabled: route failures penalize immediately.")
end

function BotRuntime.toggleCopyPlayerMode()
	state.copyPlayerMode = not state.copyPlayerMode
	state.lastCopyPlayerSampleTime = 0
	state.lastCopyPlayerPosition = nil
	state.lastCopyPlayerNodeId = nil
	state.lastCopyPlayerDistance = nil
	pushLog(if state.copyPlayerMode then "Copy player mode enabled: your movement trains graph edges and tech." else "Copy player mode disabled.")
end

function BotRuntime.togglePolicyRecorder()
	BotTrainingRecorder.setEnabled(state.policyRecorder, not BotTrainingRecorder.isEnabled(state.policyRecorder))
	pushLog(
		if BotTrainingRecorder.isEnabled(state.policyRecorder)
			then "Policy recorder enabled: reward samples are being collected for offline training."
			else "Policy recorder disabled."
	)
end

function BotRuntime.exportPolicySamples()
	local sampleCount = BotTrainingRecorder.count(state.policyRecorder)
	if sampleCount <= 0 then
		pushLog("No policy samples to export.")
		return
	end

	BotTrainingRecorder.printJsonChunks(state.policyRecorder, "BotPolicySamples")
	pushLog(`Exported {sampleCount} policy samples to the output log.`)
end

function BotRuntime.clearPolicySamples()
	BotTrainingRecorder.clear(state.policyRecorder)
	pushLog("Cleared policy recorder samples.")
end

function BotRuntime.toggleVisuals()
	state.visualize = not state.visualize
	if not state.visualize then clearVisuals() end
	pushLog(if state.visualize then "Debug visuals enabled." else "Debug visuals disabled.")
end

function BotRuntime.toggleGraphNodes()
	state.visualize = true
	state.visualizeGraphNodes = not state.visualizeGraphNodes
	pushLog(if state.visualizeGraphNodes then "Graph node visuals enabled." else "Graph node visuals disabled.")
	refreshVisuals()
end

function BotRuntime.toggleAllGraphNodes()
	state.visualize = true
	state.visualizeAllGraphNodes = not state.visualizeAllGraphNodes
	pushLog(if state.visualizeAllGraphNodes then "All graph node visuals enabled; drawing every node asynchronously." else "All graph node visuals disabled.")
	refreshVisuals()
end

function BotRuntime.toggleGraphEdges()
	state.visualize = true
	state.visualizeGraphEdges = not state.visualizeGraphEdges
	pushLog(if state.visualizeGraphEdges then "Graph edge visuals enabled." else "Graph edge visuals disabled.")
	refreshVisuals()
end

function BotRuntime.setStartAtBot()
	local rootPart = state.rootPart
	if not rootPart then
		pushLog("Cannot set start: no bot.")
		return
	end

	state.manualStartPosition = rootPart.Position
	state.manualReached = false
	pushLog(`Manual start set at {math.floor(rootPart.Position.X)}, {math.floor(rootPart.Position.Y)}, {math.floor(rootPart.Position.Z)}.`)
	refreshVisuals()
end

function BotRuntime.setStartAtPlayer()
	local targetRoot = getTargetRoot()
	if not targetRoot then
		pushLog("Cannot set start: no player root.")
		return
	end

	state.manualStartPosition = targetRoot.Position
	state.manualReached = false
	pushLog(`Manual start set from player at {math.floor(targetRoot.Position.X)}, {math.floor(targetRoot.Position.Y)}, {math.floor(targetRoot.Position.Z)}.`)
	refreshVisuals()
end

function BotRuntime.setGoalAtPlayer()
	local targetRoot = getTargetRoot()
	if not targetRoot then
		pushLog("Cannot set goal: no player root.")
		return
	end

	state.manualGoalPosition = targetRoot.Position
	state.manualReached = false
	clearPath()
	pushLog(`Manual goal set at {math.floor(targetRoot.Position.X)}, {math.floor(targetRoot.Position.Y)}, {math.floor(targetRoot.Position.Z)}.`)
	refreshVisuals()
end

function BotRuntime.clearManualPositions()
	state.manualStartPosition = nil
	state.manualGoalPosition = nil
	state.manualRunActive = false
	state.manualReached = false
	clearPath()
	pushLog("Manual start/goal removed.")
	refreshVisuals()
end

function BotRuntime.startManualRun()
	local rootPart = state.rootPart
	if not rootPart then
		pushLog("Cannot start manual run: no bot.")
		return
	end
	if not state.manualStartPosition or not state.manualGoalPosition then
		pushLog("Cannot start manual run: set start and goal first.")
		return
	end

	rootPart.CFrame = CFrame.new(state.manualStartPosition + Vector3.yAxis * 2)
	state.manualRunActive = true
	state.manualReached = false
	state.lastRewardDistance = nil
	clearPath()
	BotRuntime.setEnabled(true)
	pushLog("Manual run started.")
end

function BotRuntime.init()
	if state.connection then return end
	loadGlobalMemory()
	listenForLocalRoleChanges()
	localPlayer.CharacterAdded:Connect(function()
		task.defer(listenForLocalRoleChanges)
	end)

	local localBotTaggedEvent = getLocalBotTaggedEvent()
	state.localBotTaggedConnection = localBotTaggedEvent.Event:Connect(function(bot: Model, roleName: string)
		local nextRole = normalizeBotRole(roleName)
		if not nextRole then return end
		if bot ~= state.bot and bot ~= state.opponentBot then return end

		applyBotRole(bot, nextRole)
		grantBotNtb(bot)
		lockBotTagging(bot, Config.botTagLockoutAfterTaggedSeconds)
		clearPath()
		pushLog(`Player tagged {bot.Name}; bot is now {nextRole}.`)
	end)

	local accumulator = 0
	state.connection = RunService.Heartbeat:Connect(function(dt)
		updateScan()
		saveGlobalMemory(false)
		updateCopyPlayerLearning()

		accumulator += dt
		local step = 1 / Config.updateHz
		if accumulator < step then return end
		local updateDt = math.min(accumulator, step * 2)
		accumulator = 0

		if state.enabled then updateBot(updateDt) end
	end)
end

return BotRuntime
