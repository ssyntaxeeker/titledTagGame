--!strict
--[[
    MatchAnalysisRecorder (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/21

    Compresses selected-player observations into map occupancy, transitions,
    technique evidence, and scored route episodes suitable for persistence.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisConfig)
local Inference = require(ReplicatedStorage.Modules.Bot.Analysis.MatchTechniqueInference)
local Types = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisTypes)

type ObservedRole = Types.ObservedRole
type RBatch = Types.RBatch
type RFrame = Types.RFrame
type RTrack = Types.RTrack

export type RState = {
	map: Instance,
	mapKey: string,
	startedAt: number,
	tracks: { RTrack },
	batch: RBatch,
	samples: number,
	techniques: number,
	lines: number,
}

local MatchAnalysisRecorder = {}

local function rounded(value: number, precision: number): number
	return math.floor(value / precision + 0.5) * precision
end

local function cell(position: Vector3): string
	return `{math.floor(position.X / Config.cellSize)}:{math.floor(position.Y / Config.cellSize)}:{math.floor(position.Z / Config.cellSize)}`
end

local function playerWeight(player: Player): number
	local rank = tostring(player:GetAttribute("Rank") or "C")
	local rankWeight = Config.rankWeights[rank] or 1
	local stars = math.clamp(tonumber(player:GetAttribute("Stars")) or 0, 0, 20)
	return rankWeight * (1 + stars * 0.025)
end

local function createTrack(player: Player, role: ObservedRole, opponentDistance: number): RTrack
	return {
		player = player,
		role = role,
		gameRole = if player.Character then player.Character:GetAttribute("Role") :: string? else nil,
		previous = nil,
		lastCell = nil,
		cellEnteredAt = os.clock(),
		episodeStartedAt = os.clock(),
		episodeStartDistance = opponentDistance,
		episodeDistance = 0,
		episodePoints = {},
		episodeActions = {},
		lastPoint = nil,
		lastAction = "Run",
		lastActionAt = 0,
	}
end

local function emptyBatch(mapKey: string): RBatch
	return {
		batchId = HttpService:GenerateGUID(false),
		mapKey = mapKey,
		zones = {},
		transitions = {},
		techniques = {},
		lines = {},
		routeReviews = {},
	}
end

local function routeAnchors(points: { { number } }): { { number } }
	local anchors = {}
	for anchor = 0, 4 do
		local index = math.clamp(math.round(1 + (#points - 1) * anchor / 4), 1, #points)
		local point = points[index]
		anchors[#anchors + 1] = { point[1], point[2], point[3] }
	end
	return anchors
end

-- Each accepted route retains a compact deterministic replay sample:
-- self pose/input/motion, opponent-relative state, and local geometry.
local function addPoint(track: RTrack, frame: RFrame, opponentFrame: RFrame)
	if #track.episodePoints >= Config.routeMaximumPoints then return end
	track.episodePoints[#track.episodePoints + 1] = {
		rounded(frame.position.X, 0.5),
		rounded(frame.position.Y, 0.5),
		rounded(frame.position.Z, 0.5),
		rounded(frame.time - track.episodeStartedAt, 0.05),
		rounded(frame.moveDirection.X, 0.02),
		rounded(frame.moveDirection.Y, 0.02),
		rounded(frame.moveDirection.Z, 0.02),
		rounded(frame.velocity.X, 0.25),
		rounded(frame.velocity.Y, 0.25),
		rounded(frame.velocity.Z, 0.25),
		rounded(frame.look.X, 0.02),
		rounded(frame.look.Y, 0.02),
		rounded(frame.look.Z, 0.02),
		if frame.grounded then 1 else 0,
		rounded(frame.walkSpeed, 0.25),
		rounded(opponentFrame.position.X - frame.position.X, 0.5),
		rounded(opponentFrame.position.Y - frame.position.Y, 0.5),
		rounded(opponentFrame.position.Z - frame.position.Z, 0.5),
		rounded(opponentFrame.velocity.X, 0.25),
		rounded(opponentFrame.velocity.Y, 0.25),
		rounded(opponentFrame.velocity.Z, 0.25),
		rounded(opponentFrame.look.X, 0.02),
		rounded(opponentFrame.look.Y, 0.02),
		rounded(opponentFrame.look.Z, 0.02),
		rounded(frame.geometry.floorY, 0.5),
		rounded(frame.geometry.headroom, 0.25),
		rounded(frame.geometry.wallDistance, 0.25),
		rounded(frame.geometry.wallHeight, 0.5),
		(if frame.geometry.nearSwingBar then 1 else 0) + (if frame.geometry.nearTrampoline then 2 else 0),
	}
	track.episodeActions[#track.episodeActions + 1] = frame.action
	track.lastPoint = frame.position
end

local function resetEpisode(track: RTrack, opponentDistance: number, now: number)
	track.episodeStartedAt = now
	track.episodeStartDistance = opponentDistance
	track.episodeDistance = 0
	table.clear(track.episodePoints)
	table.clear(track.episodeActions)
	track.lastPoint = nil
end

local function finishEpisode(state: RState, track: RTrack, frame: RFrame, opponentDistance: number, outcome: number?)
	local duration = frame.time - track.episodeStartedAt
	local displacement = if track.episodePoints[1]
		then (frame.position - Vector3.new(
			track.episodePoints[1][1],
			track.episodePoints[1][2],
			track.episodePoints[1][3]
		)).Magnitude
		else 0
	local movementRatio = displacement / math.max(track.episodeDistance, 1)
	local advantage = if track.role == "Runner"
		then opponentDistance - track.episodeStartDistance
		else track.episodeStartDistance - opponentDistance
	local techCount = 0
	local previousAction: string = "Run"
	for _, action in track.episodeActions do
		if action ~= previousAction and action ~= "Run" and action ~= "Drop" then techCount += 1 end
		previousAction = action
	end
	local averageSpeed = track.episodeDistance / math.max(duration, 0.1)
	local quality = movementRatio * 3
		+ averageSpeed * 0.12
		+ math.max(advantage, 0) * 0.6
		+ techCount * 0.35
		+ (outcome or 0) * 8
	if track.role == "Runner"
		and displacement >= Config.routeReviewMinimumDistance
		and #track.episodePoints >= 3
	then
		state.batch.routeReviews[#state.batch.routeReviews + 1] = {
			points = routeAnchors(track.episodePoints),
			uses = 1,
			catches = if outcome == -1 then 1 else 0,
			advantage = rounded(advantage, 0.1),
		}
	end
	local isGoodRoute = displacement >= Config.routeMinimumDistance
		and movementRatio >= Config.routeMinimumMovementRatio
		and averageSpeed >= Config.routeMinimumAverageSpeed
		and advantage >= Config.routeMinimumAdvantage
		and quality >= Config.routeMinimumQuality
		and #track.episodePoints >= 3
	if isGoodRoute then
		state.batch.lines[#state.batch.lines + 1] = {
			role = track.role,
			userId = track.player.UserId,
			weight = playerWeight(track.player),
			duration = rounded(duration, 0.05),
			distance = rounded(track.episodeDistance, 0.25),
			displacement = rounded(displacement, 0.25),
			advantage = rounded(advantage, 0.1),
			outcome = outcome or 0,
			techCount = techCount,
			quality = rounded(quality, 0.1),
			points = table.clone(track.episodePoints),
			actions = table.clone(track.episodeActions),
		}
		state.lines += 1
	end
	resetEpisode(track, opponentDistance, frame.time)
end

local function recordTechnique(state: RState, track: RTrack, frame: RFrame, advantageDelta: number)
	if frame.action == "Run" then
		track.lastAction = frame.action
		return
	end
	if frame.action == track.lastAction then return end
	if frame.action == "UnknownTech" and frame.time - track.lastActionAt < 0.18 then return end
	if #state.batch.techniques >= Config.maximumTechniquesPerBatch then return end
	local previous = track.previous
	state.batch.techniques[#state.batch.techniques + 1] = {
		action = frame.action,
		role = track.role,
		userId = track.player.UserId,
		weight = playerWeight(track.player),
		position = {
			rounded(frame.position.X, 0.5),
			rounded(frame.position.Y, 0.5),
			rounded(frame.position.Z, 0.5),
		},
		preSpeed = rounded(if previous then previous.velocity.Magnitude else frame.velocity.Magnitude, 0.25),
		postSpeed = rounded(frame.velocity.Magnitude, 0.25),
		preY = rounded(if previous then previous.velocity.Y else frame.velocity.Y, 0.25),
		postY = rounded(frame.velocity.Y, 0.25),
		floorY = rounded(frame.geometry.floorY, 0.5),
		wallDistance = rounded(frame.geometry.wallDistance, 0.25),
		wallHeight = rounded(frame.geometry.wallHeight, 0.5),
		headroom = rounded(frame.geometry.headroom, 0.5),
		nearSwingBar = frame.geometry.nearSwingBar,
		nearTrampoline = frame.geometry.nearTrampoline,
		techValue = frame.techValue,
		advantage = rounded(advantageDelta, 0.1),
	}
	track.lastAction = frame.action
	track.lastActionAt = frame.time
	state.techniques += 1
end

function MatchAnalysisRecorder.create(map: Instance, mapKey: string, chaser: Player, runner: Player): RState
	local chaserRoot = if chaser.Character then chaser.Character:FindFirstChild("HumanoidRootPart") else nil
	local runnerRoot = if runner.Character then runner.Character:FindFirstChild("HumanoidRootPart") else nil
	local distance = if chaserRoot and runnerRoot and chaserRoot:IsA("BasePart") and runnerRoot:IsA("BasePart")
		then (chaserRoot.Position - runnerRoot.Position).Magnitude
		else 0
	return {
		map = map,
		mapKey = mapKey,
		startedAt = os.clock(),
		tracks = { createTrack(chaser, "Chaser", distance), createTrack(runner, "Runner", distance) },
		batch = emptyBatch(mapKey),
		samples = 0,
		techniques = 0,
		lines = 0,
	}
end

function MatchAnalysisRecorder.step(state: RState)
	local first = state.tracks[1]
	local second = state.tracks[2]
	local firstFrame = Inference.sample(first.player, first.previous, state.map)
	local secondFrame = Inference.sample(second.player, second.previous, state.map)
	if not firstFrame or not secondFrame then return end
	local distance = (firstFrame.position - secondFrame.position).Magnitude
	local previousDistance = if first.previous and second.previous
		then ((first.previous :: RFrame).position - (second.previous :: RFrame).position).Magnitude
		else distance
	for index, track in state.tracks do
		local frame = if index == 1 then firstFrame else secondFrame
		local currentGameRole = if track.player.Character then track.player.Character:GetAttribute("Role") else nil
		if typeof(currentGameRole) == "string" and track.gameRole and currentGameRole ~= track.gameRole then
			local nextObservedRole: ObservedRole? = nil
			if currentGameRole == "Tagger" or currentGameRole == "Peasant" then nextObservedRole = "Chaser"
			elseif currentGameRole == "Runner" or currentGameRole == "Crown" then nextObservedRole = "Runner"
			end
			local outcome = if nextObservedRole and nextObservedRole ~= track.role
				then (if track.role == "Chaser" then 1 else -1)
				else 0
			finishEpisode(state, track, frame, distance, outcome)
			if currentGameRole == "Tagger" or currentGameRole == "Peasant" then track.role = "Chaser"
			elseif currentGameRole == "Runner" or currentGameRole == "Crown" then track.role = "Runner"
			end
		end
		track.gameRole = if typeof(currentGameRole) == "string" then currentGameRole else track.gameRole
		local advantageDelta = if track.role == "Runner"
			then distance - previousDistance
			else previousDistance - distance
		local cellKey = cell(frame.position)
		local zone = state.batch.zones[cellKey]
		if not zone then
			zone = { 0, 0, 0, 0, 0, 0 }
			state.batch.zones[cellKey] = zone
		end
		zone[1] += 1
		zone[2] += Config.sampleInterval
		zone[3] += Vector3.new(frame.velocity.X, 0, frame.velocity.Z).Magnitude
		zone[if track.role == "Chaser" then 4 else 5] += 1
		if frame.action ~= "Run" and frame.action ~= "Drop" then zone[6] += 1 end

		if track.lastCell and track.lastCell ~= cellKey then
			local transitionKey = `{track.role}:{track.lastCell}>{cellKey}`
			local transition = state.batch.transitions[transitionKey]
			if not transition then
				transition = { 0, 0, 0, 0 }
				state.batch.transitions[transitionKey] = transition
			end
			transition[1] += 1
			transition[2] += frame.time - track.cellEnteredAt
			transition[3] += advantageDelta
			if frame.action ~= "Run" and frame.action ~= "Drop" then transition[4] += 1 end
			track.lastCell = cellKey
			track.cellEnteredAt = frame.time
		elseif not track.lastCell then
			track.lastCell = cellKey
			track.cellEnteredAt = frame.time
		end

		if track.previous then track.episodeDistance += (frame.position - (track.previous :: RFrame).position).Magnitude end
		local opponentFrame = if index == 1 then secondFrame else firstFrame
		addPoint(track, frame, opponentFrame)
		recordTechnique(state, track, frame, advantageDelta)
		if frame.time - track.episodeStartedAt >= Config.routeEpisodeSeconds
			or #track.episodePoints >= Config.routeMaximumPoints
		then
			finishEpisode(state, track, frame, distance, nil)
		end
		track.previous = frame
	end
	state.samples += 2
end

function MatchAnalysisRecorder.drain(state: RState): RBatch?
	if next(state.batch.zones) == nil
		and #state.batch.techniques == 0
		and #state.batch.lines == 0
		and #state.batch.routeReviews == 0
	then return nil end
	local batch = state.batch
	state.batch = emptyBatch(state.mapKey)
	return batch
end

-- Per-request limits protect remotes and DataStore writes, not total retained
-- evidence. Runtime drains immediately at these thresholds into a new batch.
function MatchAnalysisRecorder.shouldDrain(state: RState): boolean
	return #state.batch.techniques >= Config.maximumTechniquesPerBatch - 2
		or #state.batch.lines >= Config.maximumLinesPerBatch - 2
		or #state.batch.routeReviews >= Config.maximumRouteReviewsPerBatch - 2
end

function MatchAnalysisRecorder.stop(state: RState): RBatch?
	for _, track in state.tracks do Inference.clear(track.player) end
	return MatchAnalysisRecorder.drain(state)
end

return table.freeze(MatchAnalysisRecorder)
