--!strict
--[[
    RouteTrainerRuntime (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Orchestrates local attempts, best-three selection, similarity confirmation,
    global publication, route loading, ratings, and ghost previews.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AttemptRecorder = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteAttemptRecorder)
local BotAccess = require(ReplicatedStorage.Shared.Configs.BotAccess)
local Config = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerConfig)
local GhostPreview = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteGhostPreview)
local Net = require(ReplicatedStorage.Packages.Net)
local Similarity = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteSimilarity)
local Types = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerTypes)

type RAttempt = Types.RAttempt
type RRecorder = AttemptRecorder.RRecorder
type RRouteInfo = Types.RRouteInfo

local LoadIndex = Net:RemoteFunction("LoadAuthoredRouteIndex")
local LoadRoute = Net:RemoteFunction("LoadAuthoredRoute")
local PublishRoute = Net:RemoteFunction("PublishAuthoredRoute")
local RateRoute = Net:RemoteFunction("RateAuthoredRoute")
local DeleteRoute = Net:RemoteFunction("DeleteAuthoredRoute")

local RouteTrainerRuntime = {}
local state = {
	initialized = false,
	recorder = nil :: RRecorder?,
	accumulator = 0,
	attempts = {} :: { RAttempt },
	best = {} :: { [number]: boolean },
	routes = {} :: { RRouteInfo },
	selectedRoute = nil :: RRouteInfo?,
	selectedRouteData = nil :: { [string]: any }?,
	similarRoute = nil :: RRouteInfo?,
	title = "",
	status = "Ready",
	logs = {} :: { string },
}

local function log(message: string)
	state.logs[#state.logs + 1] = `[${os.date("!%H:%M:%S")}] {message}`
	while #state.logs > Config.maximumLogs do table.remove(state.logs, 1) end
	state.status = message
end

local function mapKey(): string?
	local map = Workspace:FindFirstChild("Map")
	if not map then return nil end
	local mapAttribute = Workspace:GetAttribute("Map")
	local name = if typeof(mapAttribute) == "string" then mapAttribute else map.Name
	return `{game.PlaceId}:{string.sub(name, 1, 48)}`
end

local function selectedBest(): { number }
	local indexes = {}
	for index, selected in state.best do if selected then indexes[#indexes + 1] = index end end
	table.sort(indexes)
	return indexes
end

local function refreshOpenAnalyzer()
	if not Players.LocalPlayer.PlayerGui:FindFirstChild("MatchAnalysisUI") then return end
	task.spawn(function()
		local analysisRuntime = require(ReplicatedStorage.Modules.Bot.Analysis.MatchAnalysisRuntime)
		analysisRuntime.loadMemory()
	end)
end

local function publish(mergeRouteId: string?): (boolean, string)
	local key = mapKey()
	if not key then return false, "workspace.Map is unavailable." end
	if #state.title < 2 then return false, "Enter a route title first." end
	local bestIndexes = selectedBest()
	if #bestIndexes ~= Config.requiredBestAttempts then return false, "Select exactly 3 successful attempts." end
	for _, index in bestIndexes do
		local attempt = state.attempts[index]
		if not attempt or not attempt.success then return false, "Best attempts must all be successful." end
	end
	local success, result = pcall(function()
		return PublishRoute:InvokeServer({
			mapKey = key,
			title = state.title,
			attempts = state.attempts,
			bestIndexes = bestIndexes,
			mergeRouteId = mergeRouteId,
		})
	end)
	if not success or typeof(result) ~= "table" or result.success ~= true then
		local reason = if success and typeof(result) == "table" then tostring(result.reason) else tostring(result)
		log(`Publish failed: {reason}`)
		return false, reason
	end
	state.similarRoute = nil
	state.attempts = {}
	state.best = {}
	state.title = ""
	RouteTrainerRuntime.loadRoutes()
	log(`Published route: {result.route.title}`)
	refreshOpenAnalyzer()
	return true, "Route published."
end

local function heartbeat(dt: number)
	local recorder = state.recorder
	if not recorder then return end
	if not recorder.map.Parent or Workspace:FindFirstChild("Map") ~= recorder.map then
		state.recorder = nil
		state.accumulator = 0
		log("Discarded in-progress attempt because the map changed.")
		return
	end
	state.accumulator += dt
	if state.accumulator < Config.sampleInterval then return end
	state.accumulator %= Config.sampleInterval
	AttemptRecorder.step(recorder)
	if os.clock() - recorder.startedAt >= Config.maximumAttemptSeconds then
		RouteTrainerRuntime.finishAttempt(false)
	end
end

function RouteTrainerRuntime.init()
	if state.initialized then return end
	assert(BotAccess.userIds[Players.LocalPlayer.UserId] == true, "[RouteTrainerRuntime.init] player is not authorized")
	state.initialized = true
	RunService.Heartbeat:Connect(heartbeat)
	Workspace.ChildAdded:Connect(function(child)
		if child.Name ~= "Map" then return end
		state.attempts = {}
		state.best = {}
		state.routes = {}
		state.selectedRoute = nil
		state.selectedRouteData = nil
		state.similarRoute = nil
		task.delay(1, function()
			if child.Parent then RouteTrainerRuntime.loadRoutes() end
		end)
	end)
	RouteTrainerRuntime.loadRoutes()
	log("Route trainer initialized.")
end

function RouteTrainerRuntime.setTitle(title: string)
	state.title = string.sub(title, 1, 48)
end

function RouteTrainerRuntime.startAttempt(): (boolean, string)
	if state.recorder then return false, "An attempt is already recording." end
	if #state.attempts >= Config.maximumAttempts then return false, "Delete or publish the current draft first." end
	local map = Workspace:FindFirstChild("Map")
	if not map then return false, "workspace.Map is unavailable." end
	state.recorder = AttemptRecorder.create(map)
	state.accumulator = 0
	log(`Recording attempt {#state.attempts + 1}.`)
	return true, "Attempt recording."
end

function RouteTrainerRuntime.finishAttempt(successful: boolean): (boolean, string)
	local recorder = state.recorder
	if not recorder then return false, "No attempt is recording." end
	state.recorder = nil
	state.accumulator = 0
	local attempt = AttemptRecorder.finish(recorder, successful)
	if not attempt or attempt.distance < Config.minimumAttemptDistance then
		log("Discarded attempt with insufficient movement.")
		return false, "Attempt was too short."
	end
	state.attempts[#state.attempts + 1] = attempt
	log(`Attempt {#state.attempts}: {if successful then "SUCCESS" else "FAILURE"}, {string.format("%.2f", attempt.duration)}s, {attempt.techCount} techs.`)
	return true, "Attempt saved locally."
end

function RouteTrainerRuntime.toggleBest(index: number): (boolean, string)
	local attempt = state.attempts[index]
	if not attempt then return false, "Attempt does not exist." end
	if not attempt.success then return false, "Failed attempts cannot be planner selections." end
	if state.best[index] then
		state.best[index] = nil
		log(`Removed attempt {index} from the planner selection.`)
		return true, "Attempt removed from best three."
	end
	if #selectedBest() >= Config.requiredBestAttempts then return false, "Exactly three attempts are already selected." end
	state.best[index] = true
	log(`Selected attempt {index} for the planner.`)
	return true, "Attempt selected for the planner."
end

function RouteTrainerRuntime.previewAttempt(index: number): (boolean, string)
	local attempt = state.attempts[index]
	if not attempt then return false, "Attempt does not exist." end
	local success, message = GhostPreview.play(attempt)
	if success then log(`Previewing draft attempt {index}.`) end
	return success, message
end

function RouteTrainerRuntime.deleteAttempt(index: number): (boolean, string)
	if not state.attempts[index] then return false, "Attempt does not exist." end
	table.remove(state.attempts, index)
	local nextBest = {}
	for oldIndex in state.best do
		if oldIndex < index then nextBest[oldIndex] = true elseif oldIndex > index then nextBest[oldIndex - 1] = true end
	end
	state.best = nextBest
	log(`Deleted draft attempt {index}.`)
	return true, "Attempt deleted."
end

function RouteTrainerRuntime.requestPublish(): (boolean, string)
	local bestIndexes = selectedBest()
	if #bestIndexes ~= Config.requiredBestAttempts then return false, "Select exactly 3 successful attempts." end
	local anchor = state.attempts[bestIndexes[1]]
	local similar = Similarity.find(anchor, state.routes)
	if similar then
		state.similarRoute = similar
		RouteTrainerRuntime.selectRoute(similar.id)
		log(`Similar route found: {similar.title}. Preview it, then merge or publish separately.`)
		return true, "Similar route needs confirmation."
	end
	return publish(nil)
end

function RouteTrainerRuntime.publishSeparate(): (boolean, string)
	state.similarRoute = nil
	return publish(nil)
end

function RouteTrainerRuntime.mergeSimilar(): (boolean, string)
	local similar = state.similarRoute
	if not similar then return false, "No similar route is pending." end
	return publish(similar.id)
end

function RouteTrainerRuntime.loadRoutes(): (boolean, string)
	local key = mapKey()
	if not key then return false, "workspace.Map is unavailable." end
	local success, result = pcall(function() return LoadIndex:InvokeServer(key) end)
	if not success or typeof(result) ~= "table" then
		log(`Route list load failed: {tostring(result)}`)
		return false, "Route list failed to load."
	end
	state.routes = result :: { RRouteInfo }
	log(`Loaded {#state.routes} published routes.`)
	return true, "Routes loaded."
end

function RouteTrainerRuntime.selectRoute(id: string): (boolean, string)
	local selected: RRouteInfo? = nil
	for _, route in state.routes do if route.id == id then selected = route break end end
	if not selected then return false, "Route is unavailable." end
	local success, result = pcall(function() return LoadRoute:InvokeServer(id) end)
	if not success or typeof(result) ~= "table" then return false, "Route details failed to load." end
	state.selectedRoute = selected
	state.selectedRouteData = result
	log(`Selected published route: {selected.title}.`)
	return true, `Selected {selected.title}.`
end

function RouteTrainerRuntime.previewSelectedAttempt(index: number): (boolean, string)
	local data = state.selectedRouteData
	if not data or typeof(data.attempts) ~= "table" then return false, "Select a published route first." end
	local attempt = data.attempts[index]
	if not attempt then return false, "Published attempt does not exist." end
	local success, message = GhostPreview.play(attempt)
	if success then log(`Previewing published attempt {index} from {data.title}.`) end
	return success, message
end

function RouteTrainerRuntime.previewSelectedBest(): (boolean, string)
	local data = state.selectedRouteData
	if not data or typeof(data.bestIndexes) ~= "table" or not data.bestIndexes[1] then
		return false, "Selected route has no planner preview."
	end
	return RouteTrainerRuntime.previewSelectedAttempt(data.bestIndexes[1])
end

function RouteTrainerRuntime.rateSelected(rating: number): (boolean, string)
	local route = state.selectedRoute
	if not route then return false, "Select a route first." end
	local success, result = pcall(function() return RateRoute:InvokeServer(route.id, rating) end)
	if not success or typeof(result) ~= "table" or result.success ~= true then return false, "Rating failed." end
	state.selectedRoute = result.route
	RouteTrainerRuntime.loadRoutes()
	log(`Rated {route.title} {rating}/5.`)
	refreshOpenAnalyzer()
	return true, `Rated route {rating}/5.`
end

function RouteTrainerRuntime.deleteSelectedRoute(): (boolean, string)
	local route = state.selectedRoute
	if not route then return false, "Select a route first." end
	if route.creatorId ~= Players.LocalPlayer.UserId then return false, "Only the route owner can delete it." end
	local success, result = pcall(function() return DeleteRoute:InvokeServer(route.id) end)
	if not success or typeof(result) ~= "table" or result.success ~= true then
		local reason = if success and typeof(result) == "table" then tostring(result.reason) else tostring(result)
		log(`Delete failed: {reason}`)
		return false, reason
	end
	local title = route.title
	state.selectedRoute = nil
	state.selectedRouteData = nil
	state.similarRoute = nil
	RouteTrainerRuntime.loadRoutes()
	log(`Deleted owned route: {title}.`)
	refreshOpenAnalyzer()
	return true, "Route deleted."
end

function RouteTrainerRuntime.getState(): { [string]: any }
	return {
		recording = state.recorder ~= nil,
		title = state.title,
		status = state.status,
		attempts = state.attempts,
		best = state.best,
		routes = state.routes,
		selectedRoute = state.selectedRoute,
		selectedRouteData = state.selectedRouteData,
		similarRoute = state.similarRoute,
		logs = table.concat(state.logs, "\n"),
	}
end

return table.freeze(RouteTrainerRuntime)
