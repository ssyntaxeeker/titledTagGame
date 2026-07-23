--!strict
--[[
    BotRuntime (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Lazy runtime owner for map builds, agents, tags, memory persistence, logs,
    and incremental route debug rendering.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Packages.Net)
local BotAffordances = require(ReplicatedStorage.Modules.Bot.BotAffordances)
local BotAgent = require(ReplicatedStorage.Modules.Bot.BotAgent)
local Config = require(ReplicatedStorage.Modules.Bot.BotConfig)
local BotKnowledge = require(ReplicatedStorage.Modules.Bot.BotKnowledge)
local BotPresentation = require(ReplicatedStorage.Modules.Bot.BotPresentation)
local BotRouteVisuals = require(ReplicatedStorage.Modules.Bot.BotRouteVisuals)
local BotTaughtRoutes = require(ReplicatedStorage.Modules.Bot.BotTaughtRoutes)
local BotWorld = require(ReplicatedStorage.Modules.Bot.BotWorld)
local BotSearch = require(ReplicatedStorage.Shared.Bot.BotSearch)
local Types = require(ReplicatedStorage.Modules.Bot.BotTypes)

type BotRole = Types.BotRole
type RAgent = BotAgent.RAgent
type RWorld = Types.RWorld

local localPlayer = Players.LocalPlayer
local BotTag = Net:RemoteFunction("BotTag")
local RouteLabCount = Net:RemoteEvent("BotRouteLabCount")
local BotRuntime = {}
local RANK_WEIGHTS = table.freeze({
	X = 2.5, S = 2.2, ["A+"] = 2, A = 1.8, ["A-"] = 1.6,
	["B+"] = 1.4, B = 1.25, ["B-"] = 1.1, C = 1,
})

local state = {
	initialized = false,
	enabled = false,
	duel = false,
	role = "Tagger" :: BotRole,
	world = nil :: RWorld?,
	mapJob = nil :: BotWorld.RBuildJob?,
	graphJob = nil :: BotAffordances.RBuildJob?,
	memory = BotKnowledge.create(),
	main = nil :: RAgent?,
	opponent = nil :: RAgent?,
	cleanups = {} :: { [Model]: () -> () },
	lastTagAt = {} :: { [Model]: number },
	logs = {} :: { string },
	visuals = false,
	debugFolder = nil :: Folder?,
	visualVersion = 0,
	lastVisualAt = 0,
	visualSignature = "",
	accumulator = 0,
	connection = nil :: RBXScriptConnection?,
	lastPlayerNodeId = nil :: number?,
	lastPlayerNodeAt = 0,
	lastMemorySaveAt = 0,
	lastPlayerObservationAt = 0,
	taughtRoutesApplied = false,
	taughtVaultStart = nil :: Vector3?,
	routeLabPlans = {} :: { Types.RPlan },
	routeLabIndex = 1,
	routeLabBuildVersion = 0,
	routeLabDebugFolder = nil :: Folder?,
	routeLabRevision = 0,
}

local function log(message: string)
	state.logs[#state.logs + 1] = `{os.date("!%H:%M:%S")} {message}`
	if #state.logs > 80 then table.remove(state.logs, 1) end
end

local function playerRoot(): BasePart?
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function destroyAgent(agent: RAgent?)
	if not agent then return end
	BotAgent.setEnabled(agent, false)
	local cleanup = state.cleanups[agent.character]
	if cleanup then cleanup() end
	state.cleanups[agent.character] = nil
	if agent.character.Parent then agent.character:Destroy() end
end

local function spawn(role: BotRole, offset: Vector3): RAgent?
	local root = playerRoot()
	if not root then return nil end
	local bot, humanoid, botRoot, cleanup = BotPresentation.spawn(root.CFrame + offset, role)
	local agent = BotAgent.create(bot, humanoid, botRoot, role, state.memory)
	BotAgent.setWorld(agent, state.world)
	BotAgent.setEnabled(agent, state.enabled)
	state.cleanups[bot] = cleanup
	return agent
end

local function applyRole(agent: RAgent, role: BotRole)
	BotAgent.setRole(agent, role)
	BotPresentation.applyRole(agent.character, role)
end

local function knockback(root: BasePart, origin: Vector3)
	local away = root.Position - origin
	local flat = Vector3.new(away.X, 0, away.Z)
	if flat.Magnitude < 0.1 then flat = root.CFrame.LookVector end
	root.AssemblyLinearVelocity = flat.Unit * 30 + Vector3.yAxis * 15
	task.delay(0.25, function()
		if root.Parent then
			root.AssemblyAngularVelocity = Vector3.zero
			root.AssemblyLinearVelocity = Vector3.new(
				math.clamp(root.AssemblyLinearVelocity.X, -45, 45),
				math.clamp(root.AssemblyLinearVelocity.Y, -55, 45),
				math.clamp(root.AssemblyLinearVelocity.Z, -45, 45)
			)
		end
	end)
end

local function tryTagPlayer(agent: RAgent, target: BasePart)
	if agent.role ~= "Tagger" or os.clock() - (state.lastTagAt[agent.character] or 0) < Config.tagLockoutSeconds then return end
	if (agent.root.Position - target.Position).Magnitude > Config.tagRange then return end
	state.lastTagAt[agent.character] = os.clock()
	task.spawn(function()
		local success, response = pcall(function()
			return BotTag:InvokeServer("Tagger", target, agent.root.Position)
		end)
		if not success or typeof(response) ~= "table" or response.success ~= true then return end
		local botRole = response.botRole
		if botRole ~= "Tagger" and botRole ~= "Runner" then return end
		applyRole(agent, botRole)
		BotPresentation.applyNtb(agent.character)
		knockback(agent.root, target.Position)
		log(`Bot tagged player; bot role is now {botRole}.`)
	end)
end

local function tryBotTag(tagger: RAgent, runner: RAgent)
	if tagger.role ~= "Tagger" or runner.role ~= "Runner" then return end
	if os.clock() - (state.lastTagAt[tagger.character] or 0) < Config.tagLockoutSeconds then return end
	if (tagger.root.Position - runner.root.Position).Magnitude > Config.tagRange then return end
	state.lastTagAt[tagger.character] = os.clock()
	local origin = tagger.root.Position
	state.lastTagAt[runner.character] = os.clock()
	applyRole(tagger, "Runner")
	applyRole(runner, "Tagger")
	BotPresentation.applyNtb(tagger.character)
	BotPresentation.applyNtb(runner.character)
	knockback(tagger.root, runner.root.Position)
	knockback(runner.root, origin)
	log("Duel tag: roles reversed.")
end

local function clearDebug()
	state.visualVersion += 1
	if state.debugFolder then state.debugFolder:Destroy() end
	state.debugFolder = nil
end

local function clearRouteLabDebug()
	if state.routeLabDebugFolder then state.routeLabDebugFolder:Destroy() end
	state.routeLabDebugFolder = nil
end

local function routeLabMarkers(): (Folder?, BasePart?, BasePart?)
	local folder = Workspace:FindFirstChild("BotRouteLab")
	if not folder or not folder:IsA("Folder") then return nil, nil, nil end
	local start = folder:FindFirstChild("Start")
	local goal = folder:FindFirstChild("Goal")
	return folder,
		if start and start:IsA("BasePart") then start else nil,
		if goal and goal:IsA("BasePart") then goal else nil
end

local function renderRouteLab()
	clearRouteLabDebug()
	local world = state.world
	local _, start, goal = routeLabMarkers()
	if not world or not start or not goal or #state.routeLabPlans == 0 then return end
	state.routeLabIndex = math.clamp(state.routeLabIndex, 1, #state.routeLabPlans)
	state.routeLabDebugFolder = BotRouteVisuals.renderAlternatives(
		world,
		start,
		goal,
		state.routeLabPlans,
		state.routeLabIndex
	)
end

local function renderPlans()
	clearDebug()
	if not state.visuals then return end
	local world = state.world
	if not world then return end
	state.debugFolder = BotRouteVisuals.render(world, { state.main, state.opponent })
end

local function visualSignature(): string
	local mainPlan = if state.main then BotAgent.getPlan(state.main) else nil
	local opponentPlan = if state.opponent then BotAgent.getPlan(state.opponent) else nil
	local mainCursor = if state.main then state.main.planCursor else 0
	local opponentCursor = if state.opponent then state.opponent.planCursor else 0
	local mainPhase = if state.main then state.main.motion.phase else ""
	local opponentPhase = if state.opponent then state.opponent.motion.phase else ""
	return `{if mainPlan then mainPlan.id else 0}:{mainCursor}:{mainPhase}:{if opponentPlan then opponentPlan.id else 0}:{opponentCursor}:{opponentPhase}:{state.visuals}`
end

local function update(dt: number)
	if state.mapJob then
		if BotWorld.stepBuild(state.mapJob) then
			state.world = state.mapJob.world
			state.mapJob = nil
			state.graphJob = BotAffordances.createBuildJob(state.world)
			log(`Map sampled: {#state.world.nodes} nodes. Building transitions.`)
		end
	elseif state.graphJob and BotAffordances.stepBuild(state.graphJob) then
		state.graphJob = nil
		if state.main then BotAgent.setWorld(state.main, state.world) end
		if state.opponent then BotAgent.setWorld(state.opponent, state.world) end
		log(`Navigation ready: {#(state.world :: RWorld).nodes} nodes, {#(state.world :: RWorld).edges} transitions.`)
	end
	if state.world and state.world.graphReady and state.memory.loaded and not state.taughtRoutesApplied then
		local added = BotTaughtRoutes.apply(state.world, state.memory)
		state.taughtRoutesApplied = true
		if added > 0 then log(`Loaded {added} taught map transitions.`) end
	end
	local routeFolder = Workspace:FindFirstChild("BotRouteLab")
	if routeFolder then
		local revision = routeFolder:GetAttribute("Revision")
		if typeof(revision) == "number" and revision ~= state.routeLabRevision then
			if state.routeLabRevision ~= 0 and #state.routeLabPlans > 0 then
				state.routeLabBuildVersion += 1
				state.routeLabPlans = {}
				state.routeLabIndex = 1
				clearRouteLabDebug()
				log("Route markers moved; marker routes need rebuilding.")
			end
			state.routeLabRevision = revision
		end
		local routeIndex = routeFolder:GetAttribute("RouteIndex")
		if typeof(routeIndex) == "number"
			and #state.routeLabPlans > 0
			and routeIndex ~= state.routeLabIndex
		then
			state.routeLabIndex = math.clamp(math.floor(routeIndex), 1, #state.routeLabPlans)
			renderRouteLab()
		end
	end
	if not state.enabled then return end
	if os.clock() - state.lastMemorySaveAt >= 30 then
		state.lastMemorySaveAt = os.clock()
		BotKnowledge.save(state.memory)
	end
	state.accumulator += dt
	if state.accumulator < 1 / Config.updateRate then return end
	local stepDt = math.min(0.1, state.accumulator)
	state.accumulator = 0
	local root = playerRoot()
	if root and state.world and state.world.graphReady and not state.duel
		and os.clock() - state.lastPlayerObservationAt >= Config.playerObservationInterval
	then
		state.lastPlayerObservationAt = os.clock()
		local nearest = BotWorld.findNearest(state.world, root.Position, Config.climbNeighborRadius)
		if nearest and nearest.id ~= state.lastPlayerNodeId then
			local previousId = state.lastPlayerNodeId
			if previousId then
				local elapsed = math.max(0.05, os.clock() - state.lastPlayerNodeAt)
				local previous = state.world.nodes[previousId]
				for _, edgeId in previous.edges do
					local edge = state.world.edges[edgeId]
					if edge.to ~= nearest.id then continue end
					local rank = tostring(localPlayer:GetAttribute("Rank") or "C")
					local stars = tonumber(localPlayer:GetAttribute("Stars")) or 0
					local rankWeight = (RANK_WEIGHTS[rank] or 1) + math.clamp(stars, 0, 10) * 0.04
					local speedQuality = math.clamp(edge.time / elapsed, 0.25, 2)
					BotKnowledge.recordPlayerRoute(state.memory, edge, rankWeight * speedQuality)
					break
				end
			end
			state.lastPlayerNodeId = nearest.id
			state.lastPlayerNodeAt = os.clock()
		end
	end
	if state.duel and state.main and state.opponent then
		BotAgent.update(state.main, stepDt, state.opponent.root)
		BotAgent.update(state.opponent, stepDt, state.main.root)
		tryBotTag(state.main, state.opponent)
		tryBotTag(state.opponent, state.main)
	elseif state.main and root then
		BotAgent.update(state.main, stepDt, root)
		tryTagPlayer(state.main, root)
	end
	if state.visuals and os.clock() - state.lastVisualAt >= 0.25 then
		state.lastVisualAt = os.clock()
		local signature = visualSignature()
		if signature ~= state.visualSignature then
			state.visualSignature = signature
			renderPlans()
		end
	end
end

function BotRuntime.init()
	if state.initialized then return end
	state.initialized = true
	BotKnowledge.load(state.memory)
	state.connection = RunService.Heartbeat:Connect(update)
	local taggedEvent = ReplicatedStorage:FindFirstChild("LocalBotTagged")
	if not taggedEvent then
		taggedEvent = Instance.new("BindableEvent")
		taggedEvent.Name = "LocalBotTagged"
		taggedEvent.Parent = ReplicatedStorage
	end
	(taggedEvent :: BindableEvent).Event:Connect(function(bot: Model, role: BotRole)
		for _, agent in { state.main, state.opponent } do
			if agent and agent.character == bot then
				applyRole(agent, role)
				state.lastTagAt[bot] = os.clock()
			end
		end
	end)
	log("New bot runtime initialized. No map work runs until Build Navigation is pressed.")
end

function BotRuntime.buildGraph(): (boolean, string)
	clearDebug()
	clearRouteLabDebug()
	state.routeLabBuildVersion += 1
	state.routeLabPlans = {}
	state.routeLabIndex = 1
	state.world = nil
	state.graphJob = nil
	state.mapJob = BotWorld.createBuildJob()
	state.lastPlayerNodeId = nil
	state.taughtRoutesApplied = false
	if state.main then BotAgent.setWorld(state.main, nil) end
	if state.opponent then BotAgent.setWorld(state.opponent, nil) end
	BotKnowledge.load(state.memory)
	log("Started incremental 3D map build.")
	return true, "incremental map build started"
end

function BotRuntime.teachVault(): (boolean, string)
	local root = playerRoot()
	if not root then return false, "player character is unavailable" end
	if not state.world or not state.world.graphReady then return false, "build navigation first" end
	if not state.taughtVaultStart then
		state.taughtVaultStart = root.Position
		log("Vault teaching start marked. Perform the vault, then press the button again at the landing.")
		return true, "start marked; press again after landing"
	end
	local startPosition = state.taughtVaultStart
	local targetPosition = root.Position
	if (targetPosition - startPosition).Magnitude < 3 then
		return false, "landing must be at least 3 studs from the start"
	end
	state.taughtVaultStart = nil
	local action = BotTaughtRoutes.recordVault(state.memory, startPosition, targetPosition)
	local added = BotTaughtRoutes.apply(state.world, state.memory)
	BotKnowledge.save(state.memory)
	log(`Taught {action}: saved map transition and injected {added} new edge(s).`)
	return true, `{action} saved globally`
end

function BotRuntime.spawnBot(): (boolean, string)
	destroyAgent(state.main)
	destroyAgent(state.opponent)
	state.main = spawn(state.role, Vector3.new(5, 2, 0))
	state.opponent = if state.duel then spawn(if state.role == "Tagger" then "Runner" else "Tagger", Vector3.new(-5, 2, 0)) else nil
	if not state.main then return false, "player character is unavailable" end
	log(if state.duel then "Spawned bot duel." else "Spawned training bot.")
	return true, "bot spawned"
end

function BotRuntime.toggleEnabled(): (boolean, string)
	state.enabled = not state.enabled
	if state.main then BotAgent.setEnabled(state.main, state.enabled) end
	if state.opponent then BotAgent.setEnabled(state.opponent, state.enabled) end
	if not state.enabled then BotKnowledge.save(state.memory) end
	log(if state.enabled then "Agents started." else "Agents paused; learning save queued.")
	return true, if state.enabled then "agents running" else "agents paused"
end

function BotRuntime.toggleRole(): (boolean, string)
	state.role = if state.role == "Tagger" then "Runner" else "Tagger"
	if state.main then applyRole(state.main, state.role) end
	log(`Main role changed to {state.role}.`)
	return true, state.role
end

function BotRuntime.toggleDuelMode(): (boolean, string)
	state.duel = not state.duel
	BotRuntime.spawnBot()
	return true, if state.duel then "bot duel enabled" else "player training enabled"
end

function BotRuntime.toggleVisuals(): (boolean, string)
	state.visuals = not state.visuals
	state.visualSignature = visualSignature()
	renderPlans()
	return true, if state.visuals then "route visuals enabled" else "route visuals disabled"
end

function BotRuntime.buildRouteLabRoutes(): (boolean, string)
	local world = state.world
	if not world or not world.graphReady then return false, "build navigation first" end
	local folder, start, goal = routeLabMarkers()
	if not folder or not start or not goal then return false, "server route markers are unavailable" end
	local revision = folder:GetAttribute("Revision")
	if typeof(revision) == "number" then state.routeLabRevision = revision end
	state.routeLabBuildVersion += 1
	local buildVersion = state.routeLabBuildVersion
	state.routeLabPlans = {}
	state.routeLabIndex = 1
	clearRouteLabDebug()
	log("Searching for the four fastest distinct marker routes.")
	task.spawn(function()
		local signatures: { [string]: boolean } = {}
		local excludedCandidates: { number } = { 0 }
		local candidateCursor = 1
		local attempts = 0
		while #state.routeLabPlans < 4 and candidateCursor <= #excludedCandidates and attempts < 13 do
			if buildVersion ~= state.routeLabBuildVersion then return end
			local excludedEdge = excludedCandidates[candidateCursor]
			candidateCursor += 1
			attempts += 1
			local excluded = {}
			if excludedEdge > 0 then excluded[excludedEdge] = true end
			local job = BotSearch.create(
				world,
				state.memory,
				start.Position,
				goal.Position,
				"Tagger",
				nil,
				Vector3.zero,
				Vector3.zero,
				{
					excludedEdges = excluded,
					maximumSearchSeconds = 1,
					timeOnly = true,
					heuristicWeight = 1,
				}
			)
			if not job then break end
			while not BotSearch.step(job, Config.plannerUrgentBudget * 2) do
				if buildVersion ~= state.routeLabBuildVersion then return end
				RunService.Heartbeat:Wait()
			end
			local plan = job.plan
			local complete = plan ~= nil and plan.nodes[#plan.nodes] == job.goalId
			if plan and complete and #plan.edges > 0 then
				local signature = table.concat(plan.edges, ",")
				if not signatures[signature] then
					signatures[signature] = true
					state.routeLabPlans[#state.routeLabPlans + 1] = plan
					if #state.routeLabPlans == 1 then
						local sampleCount = math.min(12, #plan.edges)
						for sampleIndex = 1, sampleCount do
							local edgeIndex = math.clamp(
								math.floor(sampleIndex / (sampleCount + 1) * #plan.edges + 0.5),
								1,
								#plan.edges
							)
							excludedCandidates[#excludedCandidates + 1] = plan.edges[edgeIndex]
						end
					end
				end
			end
			RunService.Heartbeat:Wait()
		end
		if buildVersion ~= state.routeLabBuildVersion then return end
		table.sort(state.routeLabPlans, function(a, b) return a.time < b.time end)
		RouteLabCount:FireServer(#state.routeLabPlans)
		if #state.routeLabPlans == 0 then
			log("Route lab found no complete path between the markers.")
			return
		end
		log(`Route lab found {#state.routeLabPlans} route(s); fastest is {string.format("%.2f", state.routeLabPlans[1].time)}s.`)
		renderRouteLab()
	end)
	return true, "route search started"
end

function BotRuntime.cycleRouteLab(): (boolean, string)
	if #state.routeLabPlans == 0 then return false, "build marker routes first" end
	state.routeLabIndex = state.routeLabIndex % #state.routeLabPlans + 1
	renderRouteLab()
	local plan = state.routeLabPlans[state.routeLabIndex]
	log(`Viewing marker route {state.routeLabIndex}/{#state.routeLabPlans}: {string.format("%.2f", plan.time)}s.`)
	return true, `route {state.routeLabIndex}/{#state.routeLabPlans}`
end

function BotRuntime.getStatus(): string
	local build = if state.mapJob
		then `sampling part {state.mapJob.partIndex}/{#state.mapJob.parts}, {#state.mapJob.world.nodes} nodes`
		elseif state.graphJob
		then `transitions node {state.graphJob.nodeIndex}/{#state.graphJob.world.nodes}, {#state.graphJob.world.edges} edges`
		elseif state.world and state.world.graphReady
		then `{#state.world.nodes} nodes / {#state.world.edges} transitions`
		else "navigation not built"
	local main = state.main
	local plan = if main then BotAgent.getPlan(main) else nil
	local route = if plan and main
		then `plan {plan.id} {main.planCursor}/{#plan.edges}, {math.floor(plan.time * 100) / 100}s, {math.floor(plan.success * 100)}%`
		else "direct / waiting"
	local agent = if main
		then `{main.role}: {main.decision}; {route}\n{main.motion.phase}: {main.motion.reason}; reward {math.floor(main.reward * 10) / 10}`
		else "no bot"
	local routeLab = if #state.routeLabPlans > 0
		then `marker routes {state.routeLabIndex}/{#state.routeLabPlans}, {string.format("%.2f", state.routeLabPlans[state.routeLabIndex].time)}s`
		else "marker routes not built"
	return `{build}\n{agent}\n{routeLab}`
end

function BotRuntime.getLogs(): string
	return table.concat(state.logs, "\n")
end

return table.freeze(BotRuntime)
