--!strict
--[[
    BotLearningPersistence (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Save/load serialization for BotTrainer learning data.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotPolicyNetwork = require(ReplicatedStorage.Modules.Bot.BotPolicyNetwork)

type SaveRoleName = "tagger" | "runner"

type Context = {
	state: any,
	retrieveRemote: RemoteFunction,
	saveRemote: RemoteFunction,
	refreshRouteMarkers: () -> (),
	pushLog: (string) -> (),
}

local BotLearningPersistence = {}

local function vectorToInfo(position: Vector3): { [string]: number }
	return {
		x = math.floor(position.X * 100 + 0.5) / 100,
		y = math.floor(position.Y * 100 + 0.5) / 100,
		z = math.floor(position.Z * 100 + 0.5) / 100,
	}
end

local function infoToVector(info: any): Vector3?
	if typeof(info) ~= "table" then return nil end

	local x = tonumber(info.x)
	local y = tonumber(info.y)
	local z = tonumber(info.z)
	if not x or not y or not z then return nil end

	return Vector3.new(x, y, z)
end

local function countDictionary(dictionary: { [any]: any }): number
	local count = 0
	for _ in dictionary do
		count += 1
	end
	return count
end

function BotLearningPersistence.create(ctx: Context): { [string]: any }
	local state = ctx.state
	local persistence = {}
	local saveQueue: { [SaveRoleName]: boolean } = {}
	local saveCreateNew: { [SaveRoleName]: boolean } = {}
	local saveWorkerRunning = false

	function persistence.getRoleData(role: SaveRoleName): { [string]: any }?
		local trainingData = state.trainingData
		if not trainingData then return nil end

		local roleData = trainingData[role]
		if typeof(roleData) ~= "table" then return nil end

		return roleData
	end

	function persistence.getRoleVersions(role: SaveRoleName): { any }
		local roleData = persistence.getRoleData(role)
		if not roleData or typeof(roleData.versions) ~= "table" then return {} end

		return roleData.versions
	end

	function persistence.getSelectedVersion(role: SaveRoleName): any?
		local versions = persistence.getRoleVersions(role)
		if #versions == 0 then return nil end

		state.selectedVersionIndexes[role] = math.clamp(state.selectedVersionIndexes[role], 1, #versions)
		return versions[state.selectedVersionIndexes[role]]
	end

	function persistence.serializeLearning(role: SaveRoleName): { [string]: any }
		local graph = {}
		for index, node in state.graph do
			if node.visits <= 0 and math.abs(node.score) < 0.001 then
				if index % 450 == 0 then task.wait() end
				continue
			end

			table.insert(graph, {
				id = node.id,
				position = vectorToInfo(node.position),
				score = node.score,
				visits = node.visits,
				wallPenalty = node.wallPenalty,
				openDirections = node.openDirections,
			})
			if index % 450 == 0 then task.wait() end
		end

		local directionScores = {}
		local roleDirectionScores = if role == "tagger" then state.directionScores else state.runnerDirectionScores
		for bucket, scoreInfo in roleDirectionScores do
			directionScores[bucket] = {
				score = scoreInfo.score,
				visits = scoreInfo.visits,
			}
		end

		local slideBoostScores = {}
		for key, scoreInfo in state.slideBoostScores do
			slideBoostScores[key] = {
				score = scoreInfo.score,
				visits = scoreInfo.visits,
			}
		end

		local techScores = {}
		for key, scoreInfo in state.techScores do
			techScores[key] = {
				score = scoreInfo.score,
				visits = scoreInfo.visits,
			}
		end

		local routeTechNotes = {}
		for key, scoreInfo in state.routeTechNotes do
			routeTechNotes[key] = {
				score = scoreInfo.score,
				visits = scoreInfo.visits,
			}
		end

		local geometryScores = {}
		for key, scoreInfo in state.geometryScores do
			geometryScores[key] = {
				score = scoreInfo.score,
				visits = scoreInfo.visits,
			}
		end

		local cutoffScores = {}
		for key, scoreInfo in state.cutoffScores do
			cutoffScores[key] = {
				score = scoreInfo.score,
				visits = scoreInfo.visits,
			}
		end

		local policyWeights = {}
		for key, value in state.policyWeights do
			if typeof(key) == "string" and typeof(value) == "number" then policyWeights[key] = value end
		end

		local playerModelScores = {}
		for key, scoreInfo in state.playerModelScores do
			playerModelScores[key] = {
				score = scoreInfo.score,
				visits = scoreInfo.visits,
			}
		end

		local routes = {}
		for routeIndex, route in state.routes do
			local points = {}
			for pointIndex, point in route.points do
				table.insert(points, {
					position = vectorToInfo(point.position),
					action = point.action,
					partName = point.partName,
					studs = point.studs,
				})
				if pointIndex % 80 == 0 then task.wait() end
			end

			table.insert(routes, {
				id = route.id,
				name = route.name,
				maxTime = route.maxTime,
				maxVaults = route.maxVaults,
				maxSwings = route.maxSwings,
				maxRolls = route.maxRolls,
				bestTime = route.bestTime,
				successes = route.successes,
				failures = route.failures,
				points = points,
			})
			if routeIndex % 8 == 0 then task.wait() end
		end

		local payload = {
			graph = graph,
			directionScores = directionScores,
			slideBoostScores = slideBoostScores,
			techScores = techScores,
			routeTechNotes = routeTechNotes,
			geometryScores = geometryScores,
			cutoffScores = cutoffScores,
			policyWeights = policyWeights,
			playerModelScores = playerModelScores,
			learnParams = table.clone(state.learnParams),
			routes = routes,
			stats = {
				successes = state.successes,
				attempts = state.attempts,
				lastDistance = state.lastDistance,
			},
		}
		return payload
	end

	function persistence.serializeSummary(role: SaveRoleName): { [string]: any }
		local roleDirectionScores = if role == "tagger" then state.directionScores else state.runnerDirectionScores

		return {
			graphNodes = #state.graph,
			directionScores = countDictionary(roleDirectionScores),
			slideTimings = countDictionary(state.slideBoostScores),
			techNotes = countDictionary(state.routeTechNotes),
			geometryNotes = countDictionary(state.geometryScores),
			cutoffs = countDictionary(state.cutoffScores),
			policyWeights = countDictionary(state.policyWeights),
			playerModels = countDictionary(state.playerModelScores),
			selfTaughtCandidates = countDictionary(state.selfTaughtRouteCandidates),
			routes = #state.routes,
			learnParams = "custom",
			successes = state.successes,
			attempts = state.attempts,
			note = `{state.selectedAI} {if state.targetMode == "Player" then "vs player" else "vs AI"}`,
		}
	end

	function persistence.applyLearningVersion(role: SaveRoleName, version: any)
		if typeof(version) ~= "table" or typeof(version.learning) ~= "table" then return end

		local learning = version.learning
		local targetDirectionScores = if role == "tagger" then state.directionScores else state.runnerDirectionScores
		table.clear(targetDirectionScores)
		table.clear(state.slideBoostScores)
		table.clear(state.techScores)
		table.clear(state.routeTechNotes)
		table.clear(state.geometryScores)
		table.clear(state.cutoffScores)
		table.clear(state.policyWeights)
		table.clear(state.playerModelScores)

		if typeof(learning.directionScores) == "table" then
			for key, scoreInfo in learning.directionScores do
				if typeof(scoreInfo) == "table" then
					local bucket = tonumber(scoreInfo.bucket) or tonumber(key)
					if bucket then
						targetDirectionScores[math.floor(bucket)] = {
							score = tonumber(scoreInfo.score) or 0,
							visits = math.floor(tonumber(scoreInfo.visits) or 0),
						}
					end
				end
			end
		end

		if typeof(learning.slideBoostScores) == "table" then
			for key, scoreInfo in learning.slideBoostScores do
				if typeof(scoreInfo) == "table" then
					local scoreKey = if typeof(scoreInfo.key) == "string" then scoreInfo.key else tostring(key)
					state.slideBoostScores[scoreKey] = {
						score = tonumber(scoreInfo.score) or 0,
						visits = math.floor(tonumber(scoreInfo.visits) or 0),
					}
				end
			end
		end

		if typeof(learning.techScores) == "table" then
			for key, scoreInfo in learning.techScores do
				if typeof(scoreInfo) == "table" then
					local scoreKey = if typeof(scoreInfo.key) == "string" then scoreInfo.key else tostring(key)
					state.techScores[scoreKey] = {
						score = tonumber(scoreInfo.score) or 0,
						visits = math.floor(tonumber(scoreInfo.visits) or 0),
					}
				end
			end
		end

		if typeof(learning.routeTechNotes) == "table" then
			for key, scoreInfo in learning.routeTechNotes do
				if typeof(scoreInfo) == "table" then
					local scoreKey = if typeof(scoreInfo.key) == "string" then scoreInfo.key else tostring(key)
					state.routeTechNotes[scoreKey] = {
						score = tonumber(scoreInfo.score) or 0,
						visits = math.floor(tonumber(scoreInfo.visits) or 0),
					}
				end
			end
		end

		if typeof(learning.geometryScores) == "table" then
			for key, scoreInfo in learning.geometryScores do
				if typeof(scoreInfo) == "table" then
					local scoreKey = if typeof(scoreInfo.key) == "string" then scoreInfo.key else tostring(key)
					state.geometryScores[scoreKey] = {
						score = tonumber(scoreInfo.score) or 0,
						visits = math.floor(tonumber(scoreInfo.visits) or 0),
					}
				end
			end
		end

		if typeof(learning.cutoffScores) == "table" then
			for key, scoreInfo in learning.cutoffScores do
				if typeof(scoreInfo) == "table" then
					local scoreKey = if typeof(scoreInfo.key) == "string" then scoreInfo.key else tostring(key)
					state.cutoffScores[scoreKey] = {
						score = tonumber(scoreInfo.score) or 0,
						visits = math.floor(tonumber(scoreInfo.visits) or 0),
					}
				end
			end
		end

		for key, value in BotPolicyNetwork.copySanitized(learning.policyWeights) do
			state.policyWeights[key] = value
		end

		if typeof(learning.playerModelScores) == "table" then
			for key, scoreInfo in learning.playerModelScores do
				if typeof(scoreInfo) == "table" then
					state.playerModelScores[tostring(key)] = {
						score = tonumber(scoreInfo.score) or 0,
						visits = math.floor(tonumber(scoreInfo.visits) or 0),
					}
				end
			end
		end

		if typeof(learning.learnParams) == "table" then
			for key, value in learning.learnParams do
				if typeof(key) == "string" and typeof(value) == "number" and state.learnParams[key] ~= nil then
					state.learnParams[key] = math.clamp(value, 0, 4)
				end
			end
		end

		if typeof(learning.graph) == "table" then
			for _, savedNode in learning.graph do
				if typeof(savedNode) ~= "table" then continue end

				local nodeId = tonumber(savedNode.id)
				local node = if nodeId then state.graph[nodeId] else nil
				if node then
					node.score = tonumber(savedNode.score) or node.score
					node.visits = math.floor(tonumber(savedNode.visits) or node.visits)
				end
			end
		end

		table.clear(state.routes)
		if typeof(learning.routes) == "table" then
			for _, savedRoute in learning.routes do
				if typeof(savedRoute) ~= "table" then continue end

				local points = {}
				if typeof(savedRoute.points) == "table" then
					for _, point in savedRoute.points do
						if typeof(point) ~= "table" then continue end

						local position = infoToVector(point.position)
						if not position then continue end

						table.insert(points, {
							position = position,
							action = if typeof(point.action) == "string" then point.action else "Move",
							partName = if typeof(point.partName) == "string" then point.partName else nil,
							studs = tonumber(point.studs),
						})
					end
				end

				table.insert(state.routes, {
					id = if typeof(savedRoute.id) == "string" then savedRoute.id else HttpService:GenerateGUID(false),
					name = if typeof(savedRoute.name) == "string" then savedRoute.name else "Route",
					points = points,
					maxTime = tonumber(savedRoute.maxTime) or 20,
					maxVaults = math.floor(tonumber(savedRoute.maxVaults) or 99),
					maxSwings = math.floor(tonumber(savedRoute.maxSwings) or 99),
					maxRolls = math.floor(tonumber(savedRoute.maxRolls) or 99),
					bestTime = tonumber(savedRoute.bestTime),
					successes = math.floor(tonumber(savedRoute.successes) or 0),
					failures = math.floor(tonumber(savedRoute.failures) or 0),
				})
			end
		end

		state.currentVersionIds[role] = version.id
		ctx.refreshRouteMarkers()
		ctx.pushLog(`Loaded {role} version {version.name or version.id}.`)
	end

	function persistence.saveLearningVersionNow(role: SaveRoleName, createNew: boolean): boolean
		local versionId = state.currentVersionIds[role]
		local versionName = nil
		for _, version in persistence.getRoleVersions(role) do
			if typeof(version) == "table" and version.id == versionId and typeof(version.name) == "string" then
				versionName = version.name
				break
			end
		end

		if createNew or not versionId then
			versionId = `{role}-{HttpService:GenerateGUID(false)}`
			state.currentVersionIds[role] = versionId
			versionName = nil
		end

		local payload = {
			id = versionId,
			role = role,
			name = versionName or `{if role == "tagger" then "Tagger" else "Runner"} {os.date("%H:%M:%S")}`,
			summary = persistence.serializeSummary(role),
			learning = persistence.serializeLearning(role),
		}

		local success, result = pcall(function()
			return ctx.saveRemote:InvokeServer(role, payload)
		end)
		if not success or typeof(result) ~= "table" then
			ctx.pushLog("Save failed. Check server output.")
			return false
		end

		state.trainingData = result
		state.lastAutoSaveTime = os.clock()
		ctx.pushLog(`Saved {role} learning version.`)
		return true
	end

	function persistence.queueSaveLearningVersion(role: SaveRoleName, createNew: boolean): boolean
		saveQueue[role] = true
		saveCreateNew[role] = saveCreateNew[role] or createNew
		state.lastAutoSaveTime = os.clock()

		if saveWorkerRunning then return true end
		saveWorkerRunning = true

		task.spawn(function()
			while saveQueue.tagger or saveQueue.runner do
				for _, queuedRole in { "tagger" :: SaveRoleName, "runner" :: SaveRoleName } do
					if not saveQueue[queuedRole] then continue end

					local queuedCreateNew = saveCreateNew[queuedRole] == true
					saveQueue[queuedRole] = nil
					saveCreateNew[queuedRole] = nil
					persistence.saveLearningVersionNow(queuedRole, queuedCreateNew)
					task.wait()
				end
			end

			saveWorkerRunning = false
		end)

		return true
	end

	function persistence.saveLearningVersion(role: SaveRoleName, createNew: boolean): boolean
		return persistence.queueSaveLearningVersion(role, createNew)
	end

	function persistence.retrieveTrainingData()
		local success, result = pcall(function()
			return ctx.retrieveRemote:InvokeServer()
		end)
		if not success or typeof(result) ~= "table" then
			ctx.pushLog("Could not load saved bot learning yet.")
			return
		end

		state.trainingData = result
		ctx.pushLog("Loaded saved bot learning overview.")

		local loadQueue = {}
		for _, role in { "tagger" :: SaveRoleName, "runner" :: SaveRoleName } do
			local roleData = persistence.getRoleData(role)
			local versions = persistence.getRoleVersions(role)
			if not roleData or #versions == 0 then continue end

			local selectedIndex = 1
			if typeof(roleData.activeVersionId) == "string" then
				for index, version in versions do
					if typeof(version) == "table" and version.id == roleData.activeVersionId then
						selectedIndex = index
						break
					end
				end
			end

			state.selectedVersionIndexes[role] = selectedIndex
			table.insert(loadQueue, {
				role = role,
				version = versions[selectedIndex],
				updatedAt = if typeof(versions[selectedIndex]) == "table" then tonumber(versions[selectedIndex].updatedAt) or 0 else 0,
			})
		end

		table.sort(loadQueue, function(a, b)
			return a.updatedAt < b.updatedAt
		end)

		for _, loadInfo in loadQueue do
			persistence.applyLearningVersion(loadInfo.role, loadInfo.version)
		end
	end

	return persistence
end

return BotLearningPersistence
