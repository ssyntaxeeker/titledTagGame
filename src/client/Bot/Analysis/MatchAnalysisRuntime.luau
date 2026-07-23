--!strict
--[[
    MatchAnalysisRuntime (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/21

    Lazy whitelisted orchestration for pair selection, observation, global
    persistence, candidate prediction, logs, and debug visualization.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisConfig)
local Predictor = require(ReplicatedStorage.Modules.Bot.Analysis.MatchLinePredictor)
local Recorder = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisRecorder)
local Types = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisTypes)
local Visuals = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisVisuals)
local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Net = require(ReplicatedStorage.Packages.Net)

type RBatch = Types.RBatch
type RMemory = Types.RMemory
type RRecorder = Recorder.RState
type RCandidate = Predictor.RCandidate
type ObservedRole = Types.ObservedRole

local LoadAnalysis = Net:RemoteFunction("LoadMatchAnalysis")
local LoadAnalysisRoutes = Net:RemoteFunction("LoadMatchAnalysisRoutes")
local SaveAnalysis = Net:RemoteFunction("SaveMatchAnalysisBatch")
local LoadAuthoredLines = Net:RemoteFunction("LoadAuthoredPlannerLines")
local MatchAnalysisRuntime = {}

local state = {
	initialized = false,
	chaser = nil :: Player?,
	runner = nil :: Player?,
	recorder = nil :: RRecorder?,
	memory = nil :: RMemory?,
	memorySummary = nil :: string?,
	candidates = nil :: { RCandidate }?,
	pending = {} :: { RBatch },
	saving = false,
	loading = false,
	routesLoading = false,
	routeLoadGeneration = 0,
	loadedRouteCount = 0,
	accumulator = 0,
	lastFlushAt = 0,
	logs = {} :: { string },
	visualFolder = nil :: Folder?,
	visualMode = nil :: ("Live" | "Full")?,
	visualAccumulator = 0,
	crownPairAccumulator = 0,
	visualSignature = nil :: string?,
	liveRecommendationCount = 0,
	janitor = Janitor.new(),
}

local function log(message: string)
	local stamp = os.date("!%H:%M:%S")
	state.logs[#state.logs + 1] = `[{stamp}] {message}`
	while #state.logs > Config.maximumLogLines do table.remove(state.logs, 1) end
end

local function currentMap(): Instance?
	return Workspace:FindFirstChild("Map")
end

local function currentMapKey(): string?
	local map = currentMap()
	if not map then return nil end
	local mapAttribute = Workspace:GetAttribute("Map")
	local name = if typeof(mapAttribute) == "string" then mapAttribute else map.Name
	return `{game.PlaceId}:{string.sub(name, 1, 48)}`
end

local function emptyMemory(key: string): RMemory
	return {
		version = 3,
		mapKey = key,
		zones = {},
		transitions = {},
		techniques = {},
		techObservations = {},
		lines = {},
		routeReviews = {},
		updatedAt = 0,
	}
end

local function sortedPlayers(): { Player }
	local list = Players:GetPlayers()
	table.sort(list, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)
	return list
end

local function selectDefaults()
	local list = sortedPlayers()
	if #list == 0 then return end
	state.chaser = list[1]
	state.runner = if #list > 1 then list[2] else nil
	for _, player in list do
		local role = if player.Character then player.Character:GetAttribute("Role") else nil
		if role == "Tagger" or role == "Peasant" then state.chaser = player end
		if role == "Runner" or role == "Crown" then state.runner = player end
	end
	if state.chaser == state.runner then state.runner = nil end
end

local function count(dictionary: { [string]: any }): number
	local result = 0
	for _ in dictionary do result += 1 end
	return result
end

local function invalidateMemoryView()
	state.memorySummary = nil
	state.candidates = nil
	state.visualSignature = nil
	Predictor.invalidate()
end

local function invalidateRouteView()
	state.memorySummary = nil
	state.candidates = nil
	state.visualSignature = nil
	Predictor.invalidateRoutes()
end

local refreshFullVisuals: () -> ()

local function mergeUniqueLines(target: RMemory, source: { { [string]: any } }): number
	local signatures = {}
	for _, line in target.lines do
		if typeof(line.signature) == "string" then signatures[line.signature] = true end
	end
	local added = 0
	for _, line in source do
		local signature = line.signature
		if typeof(signature) == "string" and signatures[signature] then continue end
		target.lines[#target.lines + 1] = line
		if typeof(signature) == "string" then signatures[signature] = true end
		added += 1
	end
	return added
end

local function streamRouteCatalog(key: string, generation: number)
	state.routesLoading = true
	local manifestSuccess, manifest = pcall(function()
		return LoadAnalysisRoutes:InvokeServer({ mapKey = key })
	end)
	if not manifestSuccess or typeof(manifest) ~= "table" or typeof(manifest.buckets) ~= "table" then
		if generation == state.routeLoadGeneration then
			state.routesLoading = false
			log(`Route catalog load failed: {tostring(manifest)}`)
		end
		return
	end

	local loaded = 0
	for _, bucket in manifest.buckets do
		local cursor: number? = 1
		repeat
			if generation ~= state.routeLoadGeneration or key ~= currentMapKey() then return end
			local pageSuccess, page = pcall(function()
				return LoadAnalysisRoutes:InvokeServer({ mapKey = key, bucket = bucket, cursor = cursor })
			end)
			if not pageSuccess or typeof(page) ~= "table" or typeof(page.lines) ~= "table" then
				log(`Route catalog bucket {bucket} failed: {tostring(page)}`)
				break
			end
			local memory = state.memory
			if memory and memory.mapKey == key then
				loaded += mergeUniqueLines(memory, page.lines)
				state.loadedRouteCount = loaded
			end
			cursor = if typeof(page.nextCursor) == "number" then page.nextCursor else nil
			task.wait(Config.routeCatalogPagePause)
		until cursor == nil
	end
	if generation ~= state.routeLoadGeneration then return end
	state.routesLoading = false
	state.loadedRouteCount = loaded
	invalidateRouteView()
	refreshFullVisuals()
	log(`Route catalog ready: streamed {loaded} additional route families.`)
end

refreshFullVisuals = function()
	local memory = state.memory
	if state.visualMode ~= "Full" or not memory then return end
	if state.visualFolder then state.visualFolder:Destroy() end
	state.visualFolder = Visuals.renderFull(memory)
end

local function candidates(): { RCandidate }
	if state.candidates then return state.candidates end
	local memory = state.memory
	if not memory then return {} end
	local result = Predictor.build(memory, "Runner")
	for _, candidate in Predictor.build(memory, "Chaser") do result[#result + 1] = candidate end
	table.sort(result, function(a, b) return a.score > b.score end)
	state.candidates = result
	return result
end

local function queueCurrentBatch()
	local recorder = state.recorder
	if not recorder then return end
	local batch = Recorder.drain(recorder)
	if batch then state.pending[#state.pending + 1] = batch end
end

local function saveNext()
	if state.saving or #state.pending == 0 then return end
	state.saving = true
	local batch = state.pending[1]
	task.spawn(function()
		local success, response = pcall(function() return SaveAnalysis:InvokeServer(batch) end)
		if success and typeof(response) == "table" and response.success == true then
			table.remove(state.pending, 1)
			log(`Saved analysis batch: {count(batch.zones)} zones, {#batch.techniques} tech observations, {#batch.lines} lines, {#batch.routeReviews} runner route reviews.`)
			if batch.mapKey == currentMapKey() then
				local loaded, refreshed = pcall(function() return LoadAnalysis:InvokeServer(batch.mapKey) end)
				if loaded and typeof(refreshed) == "table" then
					local previousMemory = state.memory
					state.memory = refreshed :: RMemory
					if previousMemory then mergeUniqueLines(state.memory, previousMemory.lines) end
					local authoredLoaded, authoredLines = pcall(function() return LoadAuthoredLines:InvokeServer(batch.mapKey) end)
					if authoredLoaded and typeof(authoredLines) == "table" then
						for _, line in authoredLines do state.memory.lines[#state.memory.lines + 1] = line end
					end
					invalidateMemoryView()
					refreshFullVisuals()
				end
			end
		else
			local reason = if success and typeof(response) == "table" then tostring(response.reason) else tostring(response)
			log(`Analysis save failed: {reason}`)
		end
		state.saving = false
	end)
end

local function observedRole(character: Model?): ObservedRole?
	if not character then return nil end
	local role = character:GetAttribute("Role")
	if role == "Tagger" or role == "Peasant" or role == "Hunter" or role == "Bomb" or role == "Freezer" then
		return "Chaser"
	end
	if role == "Runner" or role == "Crown" or role == "Bounty" then return "Runner" end
	return nil
end

local function rootPart(player: Player?): BasePart?
	local character = if player then player.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Crown has one authoritative runner but potentially many Peasants. This
-- favors Peasants who are close and actively moving toward the Crown, with
-- hysteresis so nearby candidates do not make the recorder thrash.
local function crownPair(): (Player?, Player?)
	local gamemode = Workspace:GetAttribute("Gamemode")
	if gamemode ~= "Crown" and gamemode ~= "InfCrown" then return nil, nil end

	local crown: Player? = nil
	for _, player in Players:GetPlayers() do
		if player.Character and player.Character:GetAttribute("Role") == "Crown" then
			crown = player
			break
		end
	end
	local crownRoot = rootPart(crown)
	if not crown or not crownRoot then return nil, nil end

	local bestPeasant: Player? = nil
	local bestScore = -math.huge
	local currentScore = -math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character or character:GetAttribute("Role") ~= "Peasant" then continue end
		local peasantRoot = rootPart(player)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not peasantRoot or not humanoid or humanoid.Health <= 0 then continue end

		local offset = (crownRoot.Position - peasantRoot.Position) * Vector3.new(1, 0, 1)
		local distance = offset.Magnitude
		local direction = if distance > 0.05 then offset.Unit else Vector3.zero
		local velocity = peasantRoot.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local moveDirection = humanoid.MoveDirection * Vector3.new(1, 0, 1)
		local velocityTowardCrown = velocity:Dot(direction)
		local inputAlignment = if moveDirection.Magnitude > 0.05 then moveDirection.Unit:Dot(direction) else -0.25
		local score = velocityTowardCrown * 1.5
			+ inputAlignment * 6
			+ math.min(velocity.Magnitude, 40) * 0.08
			- distance * 0.12
		if player == state.chaser then currentScore = score end
		if score > bestScore then
			bestScore = score
			bestPeasant = player
		end
	end

	if state.chaser and state.chaser ~= bestPeasant and currentScore > -math.huge
		and bestScore < currentScore + Config.crownChaserSwitchScore
	then
		bestPeasant = state.chaser
	end
	return bestPeasant, crown
end

local function recommendationOpponent(role: ObservedRole, position: Vector3): BasePart?
	local localPlayer = Players.LocalPlayer
	local selected = if role == "Chaser" and state.chaser == localPlayer
		then state.runner
		elseif role == "Runner" and state.runner == localPlayer then state.chaser
		else nil
	local selectedRoot = rootPart(selected)
	if selectedRoot then return selectedRoot end

	local nearest: BasePart? = nil
	local nearestDistance = math.huge
	for _, player in Players:GetPlayers() do
		if player == localPlayer then continue end
		local playerRole = observedRole(player.Character)
		if not playerRole or playerRole == role then continue end
		local root = rootPart(player)
		if not root then continue end
		local distance = (root.Position - position).Magnitude
		if distance < nearestDistance then
			nearest = root
			nearestDistance = distance
		end
	end
	return nearest
end

local function updateLiveRecommendations()
	local folder = state.visualFolder
	local memory = state.memory
	local character = Players.LocalPlayer.Character
	local role = observedRole(character)
	if not role and state.chaser == Players.LocalPlayer then role = "Chaser" end
	if not role and state.runner == Players.LocalPlayer then role = "Runner" end
	local playerRoot = rootPart(Players.LocalPlayer)
	if not folder then return end
	if not memory or not role or not playerRoot then
		state.liveRecommendationCount = 0
		if state.visualSignature ~= "Unavailable" then
			state.visualSignature = "Unavailable"
			Visuals.updateRecommendations(folder, {})
		end
		return
	end
	local opponentRoot = recommendationOpponent(role, playerRoot.Position)
	local recommendations = Predictor.recommend(memory, role, {
		position = playerRoot.Position,
		look = playerRoot.CFrame.LookVector,
		opponentPosition = if opponentRoot then opponentRoot.Position else nil,
		opponentVelocity = if opponentRoot then opponentRoot.AssemblyLinearVelocity else nil,
		opponentLook = if opponentRoot then opponentRoot.CFrame.LookVector else nil,
	})
	local primary = recommendations[1]
	if primary and (primary.points[#primary.points] - playerRoot.Position).Magnitude <= Config.recommendationContinuationDistance then
		local endpoint = primary.points[#primary.points]
		local routeLook = if #primary.points >= 2
			then primary.points[#primary.points] - primary.points[#primary.points - 1]
			else playerRoot.CFrame.LookVector
		local continuations = Predictor.recommend(memory, role, {
			position = endpoint,
			look = routeLook,
			opponentPosition = if opponentRoot then opponentRoot.Position else nil,
			opponentVelocity = if opponentRoot then opponentRoot.AssemblyLinearVelocity else nil,
			opponentLook = if opponentRoot then opponentRoot.CFrame.LookVector else nil,
			predictionTimeOffset = primary.time,
		})
		for _, continuation in continuations do
			if (continuation.points[#continuation.points] - endpoint).Magnitude <= 4 then continue end
			continuation.continuation = true
			recommendations = { primary, continuation }
			break
		end
	end
	local signatureParts = { role }
	for _, candidate in recommendations do
		local first = candidate.points[1]
		local last = candidate.points[#candidate.points]
		local routeKind = if candidate.continuation then "N" else "R"
		signatureParts[#signatureParts + 1] = `{routeKind}:{math.round(first.X)}:{math.round(first.Y)}:{math.round(first.Z)}>{math.round(last.X)}:{math.round(last.Y)}:{math.round(last.Z)}:{math.round((candidate.tacticalGain or 0) / 2)}:{math.round(candidate.closestOpponentDistance or -1)}`
	end
	local signature = table.concat(signatureParts, "|")
	state.liveRecommendationCount = #recommendations
	if signature == state.visualSignature then return end
	state.visualSignature = signature
	Visuals.updateRecommendations(folder, recommendations)
end

local function stopRecording(reason: string)
	local recorder = state.recorder
	if not recorder then return end
	local finalBatch = Recorder.stop(recorder)
	if finalBatch then state.pending[#state.pending + 1] = finalBatch end
	for _, track in recorder.tracks do
		if track.role == "Chaser" then state.chaser = track.player else state.runner = track.player end
	end
	state.recorder = nil
	state.accumulator = 0
	log(`Stopped analysis: {reason}. Captured {recorder.samples} frames, {recorder.techniques} tech events, {recorder.lines} route episodes.`)
	saveNext()
end

local function beginRecording(chaser: Player, runner: Player, map: Instance, key: string)
	state.recorder = Recorder.create(map, key, chaser, runner)
	state.lastFlushAt = os.clock()
	state.accumulator = 0
	log(`Recording {chaser.Name} as chaser against {runner.Name} as runner on {key}.`)
end

local function updateCrownPair()
	local chaser, runner = crownPair()
	if not chaser or not runner then return end
	if state.chaser == chaser and state.runner == runner then return end

	local recorder = state.recorder
	if recorder then
		local hasChaser = false
		local hasRunner = false
		for _, track in recorder.tracks do
			if track.player == chaser then hasChaser = true end
			if track.player == runner then hasRunner = true end
		end
		if hasChaser and hasRunner then
			state.chaser = chaser
			state.runner = runner
			return
		end
	end

	local wasRecording = recorder ~= nil
	if wasRecording then stopRecording("Crown pursuit pair changed") end
	state.chaser = chaser
	state.runner = runner
	log(`Crown auto-pair selected {chaser.Name} chasing Crown {runner.Name}.`)
	if not wasRecording then return end

	local map = currentMap()
	local key = currentMapKey()
	if map and key then beginRecording(chaser, runner, map, key) end
end

local function heartbeat(dt: number)
	state.crownPairAccumulator += dt
	if state.crownPairAccumulator >= Config.crownPairInterval then
		state.crownPairAccumulator %= Config.crownPairInterval
		updateCrownPair()
	end
	if state.visualFolder and state.visualMode == "Live" then
		state.visualAccumulator += dt
		if state.visualAccumulator >= Config.recommendationInterval then
			state.visualAccumulator %= Config.recommendationInterval
			updateLiveRecommendations()
		end
	end
	local recorder = state.recorder
	if not recorder then return end
	if not recorder.map.Parent or currentMap() ~= recorder.map then
		stopRecording("map changed")
		return
	end
	if not recorder.tracks[1].player.Parent or not recorder.tracks[2].player.Parent then
		stopRecording("selected player left")
		return
	end
	state.accumulator += dt
	if state.accumulator < Config.sampleInterval then return end
	state.accumulator %= Config.sampleInterval
	if Recorder.shouldDrain(recorder) then
		queueCurrentBatch()
		state.lastFlushAt = os.clock()
		saveNext()
	end
	Recorder.step(recorder)
	if Recorder.shouldDrain(recorder) or os.clock() - state.lastFlushAt >= Config.flushInterval then
		queueCurrentBatch()
		state.lastFlushAt = os.clock()
		saveNext()
	end
end

local function cycle(selected: Player?, direction: number, avoid: Player?): Player?
	local list = sortedPlayers()
	if #list == 0 then return nil end
	local current = table.find(list, selected) or 1
	for offset = 1, #list do
		local index = ((current - 1 + direction * offset) % #list) + 1
		if list[index] ~= avoid then return list[index] end
	end
	return nil
end

function MatchAnalysisRuntime.init()
	if state.initialized then return end
	assert(BotAccess.userIds[Players.LocalPlayer.UserId] == true, "[MatchAnalysisRuntime.init] player is not authorized")
	state.initialized = true
	selectDefaults()
	state.janitor:Add(RunService.Heartbeat:Connect(heartbeat))
	state.janitor:Add(Players.PlayerRemoving:Connect(function(player)
		if player == state.chaser or player == state.runner then stopRecording("selected player left") end
	end))
	state.janitor:Add(Workspace.ChildAdded:Connect(function(child)
		if child.Name ~= "Map" then return end
		task.delay(1, function()
			if child.Parent and not state.loading then MatchAnalysisRuntime.loadMemory() end
		end)
	end))
	log("Match analyzer initialized. No bot agents or navigation jobs are running.")
	MatchAnalysisRuntime.loadMemory()
end

function MatchAnalysisRuntime.cycleChaser(direction: number): (boolean, string)
	if state.recorder then return false, "Stop recording before changing the pair." end
	state.chaser = cycle(state.chaser, direction, state.runner)
	local message = if state.chaser then `Chaser set to {state.chaser.Name}.` else "No chaser is available."
	log(message)
	return state.chaser ~= nil, message
end

function MatchAnalysisRuntime.cycleRunner(direction: number): (boolean, string)
	if state.recorder then return false, "Stop recording before changing the pair." end
	state.runner = cycle(state.runner, direction, state.chaser)
	local message = if state.runner then `Runner set to {state.runner.Name}.` else "No runner is available."
	log(message)
	return state.runner ~= nil, message
end

function MatchAnalysisRuntime.autoSelectPair(): (boolean, string)
	if state.recorder then return false, "Stop recording before changing the pair." end
	local crownChaser, crownRunner = crownPair()
	if crownChaser and crownRunner then
		state.chaser = crownChaser
		state.runner = crownRunner
	else
		selectDefaults()
	end
	local success = state.chaser ~= nil and state.runner ~= nil
	local message = if success
		then `Selected {state.chaser.Name} chasing {state.runner.Name} from current roles.`
		else "Could not find two distinct players from current roles."
	log(message)
	return success, message
end

function MatchAnalysisRuntime.toggleRecording(): (boolean, string)
	if state.recorder then
		stopRecording("requested by observer")
		return true, "Recording stopped; pending evidence is being saved."
	end
	local map = currentMap()
	local key = currentMapKey()
	if not map or not key then return false, "workspace.Map is unavailable." end
	if not state.chaser or not state.runner or state.chaser == state.runner then return false, "Select two distinct players." end
	beginRecording(state.chaser, state.runner, map, key)
	return true, "Recording started."
end

function MatchAnalysisRuntime.saveNow(): (boolean, string)
	queueCurrentBatch()
	if #state.pending == 0 then
		log("Save requested; there is no unsaved evidence.")
		return true, "Nothing new to save."
	end
	log(`Save requested with {#state.pending} batch(es) pending.`)
	saveNext()
	return true, "Saving analysis in the background."
end

function MatchAnalysisRuntime.loadMemory(): (boolean, string)
	if state.loading then return false, "Memory is already loading." end
	local key = currentMapKey()
	if not key then return false, "workspace.Map is unavailable." end
	state.loading = true
	state.routeLoadGeneration += 1
	local routeLoadGeneration = state.routeLoadGeneration
	state.loadedRouteCount = 0
	log(`Loading global analysis for {key}.`)
	task.spawn(function()
		local success, result = pcall(function() return LoadAnalysis:InvokeServer(key) end)
		local authoredSuccess, authoredLines = pcall(function() return LoadAuthoredLines:InvokeServer(key) end)
		if success and typeof(result) == "table" then
			state.memory = result :: RMemory
			if authoredSuccess and typeof(authoredLines) == "table" then
				for _, line in authoredLines do state.memory.lines[#state.memory.lines + 1] = line end
			end
			invalidateMemoryView()
			refreshFullVisuals()
			log(`Loaded {count(state.memory.zones)} zones, {count(state.memory.transitions)} transitions, {count(state.memory.techniques)} tech templates, {if authoredSuccess and typeof(authoredLines) == "table" then #authoredLines else 0} authored projections, and {#state.memory.lines} total lines.`)
			task.spawn(streamRouteCatalog, key, routeLoadGeneration)
		else
			state.memory = emptyMemory(key)
			if authoredSuccess and typeof(authoredLines) == "table" then
				for _, line in authoredLines do state.memory.lines[#state.memory.lines + 1] = line end
			end
			invalidateMemoryView()
			log(`Memory load failed; using an empty local view: {tostring(result)}`)
			task.spawn(streamRouteCatalog, key, routeLoadGeneration)
		end
		state.loading = false
	end)
	return true, "Loading global map memory."
end

function MatchAnalysisRuntime.toggleVisuals(): (boolean, string)
	if state.visualFolder and state.visualMode == "Live" then
		state.visualFolder:Destroy()
		state.visualFolder = nil
		state.visualMode = nil
		state.visualSignature = nil
		state.liveRecommendationCount = 0
		log("Analysis visualization hidden.")
		return true, "Visualization hidden."
	end
	local memory = state.memory
	if not memory then return false, "Load map memory first." end
	if state.visualFolder then state.visualFolder:Destroy() end
	state.visualFolder = Visuals.create()
	state.visualMode = "Live"
	state.visualAccumulator = 0
	state.visualSignature = nil
	updateLiveRecommendations()
	log("Live route recommendations enabled. Lines are ranked from the local role, position, heading, and nearest opponent.")
	return true, "Live routes shown."
end

function MatchAnalysisRuntime.toggleFullVisuals(): (boolean, string)
	if state.visualFolder and state.visualMode == "Full" then
		state.visualFolder:Destroy()
		state.visualFolder = nil
		state.visualMode = nil
		state.visualSignature = nil
		log("Full analysis visualization hidden.")
		return true, "Full visualization hidden."
	end
	local memory = state.memory
	if not memory then return false, "Load map memory first." end
	if state.visualFolder then state.visualFolder:Destroy() end
	state.visualFolder = Visuals.renderFull(memory)
	state.visualMode = "Full"
	state.visualSignature = nil
	state.liveRecommendationCount = 0
	log(`Rendering the complete loaded memory: {count(memory.zones)} zones, {#(memory.techObservations or {})} individual tech observations, and {#memory.lines} accepted routes.`)
	return true, "Full memory shown."
end

function MatchAnalysisRuntime.getSelection(): (string, string)
	if state.recorder then
		local chaser = "None"
		local runner = "None"
		for _, track in state.recorder.tracks do
			if track.role == "Chaser" then chaser = track.player.Name else runner = track.player.Name end
		end
		return chaser, runner
	end
	return if state.chaser then state.chaser.Name else "None", if state.runner then state.runner.Name else "None"
end

function MatchAnalysisRuntime.getStatus(): string
	local recorder = state.recorder
	local recording = if recorder then "RECORDING" else "IDLE"
	local samples = if recorder then recorder.samples else 0
	local techniques = if recorder then recorder.techniques else 0
	local lines = if recorder then recorder.lines else 0
	local visualMode = state.visualMode or "Off"
	return `{recording} | frames {samples} | tech {techniques} | lines {lines} | catalog {state.loadedRouteCount}{if state.routesLoading then "+" else ""} | suggested {state.liveRecommendationCount} | view {visualMode} | pending {#state.pending}`
end

function MatchAnalysisRuntime.getMemorySummary(): string
	local memory = state.memory
	if not memory then return if state.loading then "Loading memory..." else "No memory loaded." end
	if state.memorySummary then return state.memorySummary end
	local runnerCandidates = Predictor.build(memory, "Runner")
	local chaserCandidates = Predictor.build(memory, "Chaser")
	local lines = {
		`Map: {memory.mapKey}`,
		`Hotspots: {count(memory.zones)} | transitions: {count(memory.transitions)}`,
		`Tech templates: {count(memory.techniques)} | observations: {#(memory.techObservations or {})} | accepted lines: {#memory.lines}`,
		`Runner route reviews: {#(memory.routeReviews or {})}`,
		`Ranked candidates: runner {#runnerCandidates} | chaser {#chaserCandidates}`,
	}
	local techniques = {}
	for signature, info in memory.techniques do
		techniques[#techniques + 1] = { signature = signature, info = info, weight = tonumber(info.weight) or 0 }
	end
	table.sort(techniques, function(a, b) return a.weight > b.weight end)
	for index = 1, math.min(4, #techniques) do
		local entry = techniques[index]
		local info = entry.info
		local weight = math.max(entry.weight, 0.001)
		local speedGain = ((tonumber(info.postSpeed) or 0) - (tonumber(info.preSpeed) or 0)) / weight
		local advantage = (tonumber(info.advantage) or 0) / weight
		local timing = if (tonumber(info.techValueWeight) or 0) > 0
			then string.format(" | learned %.1f", (tonumber(info.techValue) or 0) / info.techValueWeight)
			else ""
		lines[#lines + 1] = `T{index} {info.action}/{info.role}: n={info.count}, speed {string.format("%+.1f", speedGain)}, advantage {string.format("%+.2f", advantage)}{timing}`
	end
	for index = 1, math.min(3, #runnerCandidates) do
		local candidate = runnerCandidates[index]
		local caught = if (candidate.uses or 0) > 0 then `, caught {candidate.catches or 0}/{candidate.uses or 0}` else ""
		lines[#lines + 1] = `R{index} {candidate.title or candidate.kind} {string.upper(candidate.verdict)}: score {string.format("%.1f", candidate.score)}, advantage {string.format("%+.1f", candidate.advantage)}, confidence {string.format("%.0f%%", candidate.confidence * 100)}, consistency {string.format("%.0f%%", candidate.consistency * 100)}, improvement {string.format("%+.0f%%", candidate.improvement * 100)}, {string.format("%.2f", candidate.time)}s{caught}`
	end
	for index = 1, math.min(3, #chaserCandidates) do
		local candidate = chaserCandidates[index]
		lines[#lines + 1] = `C{index} {candidate.title or candidate.kind} {string.upper(candidate.verdict)}: score {string.format("%.1f", candidate.score)}, advantage {string.format("%+.1f", candidate.advantage)}, confidence {string.format("%.0f%%", candidate.confidence * 100)}, consistency {string.format("%.0f%%", candidate.consistency * 100)}, improvement {string.format("%+.0f%%", candidate.improvement * 100)}, {string.format("%.2f", candidate.time)}s`
	end
	state.memorySummary = table.concat(lines, "\n")
	return state.memorySummary
end

function MatchAnalysisRuntime.getLogs(): string
	return table.concat(state.logs, "\n")
end

return table.freeze(MatchAnalysisRuntime)
