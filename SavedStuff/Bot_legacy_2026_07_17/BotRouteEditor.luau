--!strict
--[[
    BotRouteEditor (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Route recording and editor commands for BotTrainer. This module exists to
    keep the trainer loader below Luau's local register limit.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

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

type Context = {
	state: any,
	localPlayer: Player,
	raycastParams: RaycastParams,
	getIgnoreList: () -> { Instance },
	refreshRouteMarkers: () -> (),
	refreshControlButtons: () -> (),
	pushLog: (string) -> (),
}

local BotRouteEditor = {}

function BotRouteEditor.create(ctx: Context): { [string]: any }
	local state = ctx.state

	local editor = {}

	function editor.getCurrentRoute(): RouteInfo?
		return state.routes[state.editorSelectedRouteIndex] or state.routes[math.max(1, #state.routes)]
	end

	function editor.beginRouteRecording()
		local route = {
			id = HttpService:GenerateGUID(false),
			name = `Route {#state.routes + 1}`,
			points = {},
			maxTime = 20,
			maxVaults = 99,
			maxSwings = 99,
			maxRolls = 99,
			bestTime = nil,
			successes = 0,
			failures = 0,
		}
		table.insert(state.routes, route)
		state.editorSelectedRouteIndex = #state.routes
		state.editorSelectedPointIndex = 1
		state.recordingRoute = true
		if not state.guidedTraining then
			ctx.pushLog(`Recording {route.name}.`)
			ctx.refreshRouteMarkers()
		end
	end

	function editor.beginPlayerRouteRecording()
		editor.beginRouteRecording()
		state.playerRouteRecording = true
		state.lastPlayerRouteSampleTime = 0
		state.lastPlayerRouteSamplePosition = nil
		state.lastPlayerRouteActionName = "Start"
		state.playerRouteStartedMoving = false
		state.playerRouteStartPosition = nil
		local character = ctx.localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			state.playerRouteStartPosition = rootPart.Position
			editor.addRoutePointAt(rootPart.Position, "Start", nil, nil)
			state.lastPlayerRouteSamplePosition = rootPart.Position
		end
		if not state.guidedTraining then ctx.pushLog("Recording player movement route.") end
	end

	function editor.stopRouteRecording()
		if state.playerRouteRecording then
			local character = ctx.localPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart:IsA("BasePart") then
				editor.addRoutePointAt(rootPart.Position, "End", nil, nil)
			end
		end
		state.recordingRoute = false
		state.playerRouteRecording = false
		state.playerRouteStartedMoving = false
		state.playerRouteStartPosition = nil
		if not state.guidedTraining then ctx.pushLog("Route recording stopped.") end
	end

	function editor.addRoutePointAt(position: Vector3, actionName: string, partName: string?, studs: number?)
		local route = editor.getCurrentRoute()
		if not route or not state.recordingRoute then
			editor.beginRouteRecording()
			route = editor.getCurrentRoute()
			if not route then return end
		end

		table.insert(route.points, {
			position = position,
			action = actionName,
			partName = partName,
			studs = studs,
		})
		state.editorSelectedRouteIndex = table.find(state.routes, route) or state.editorSelectedRouteIndex
		state.editorSelectedPointIndex = #route.points
		state.editorSelectedAction = actionName
		if not state.guidedTraining then state.editorOpen = true end
		if not state.guidedTraining or actionName ~= "Move" then ctx.pushLog(`Route node #{#route.points}: {actionName}.`) end
		if not state.guidedTraining then ctx.refreshRouteMarkers() end
	end

	function editor.addRoutePoint(actionName: string)
		local character = ctx.localPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart or not rootPart:IsA("BasePart") then return end

		editor.addRoutePointAt(rootPart.Position, actionName, nil, nil)
	end

	function editor.addRoutePointFromView(actionName: string)
		local camera = workspace.CurrentCamera
		if not camera then return end

		ctx.raycastParams.FilterDescendantsInstances = ctx.getIgnoreList()
		local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 80, ctx.raycastParams)
		local position = if result then result.Position + Vector3.new(0, 2.8, 0) else camera.CFrame.Position + camera.CFrame.LookVector * 18
		editor.addRoutePointAt(position, actionName, if result then result.Instance:GetFullName() else nil, nil)
	end

		function editor.selectRoutePointIndex(index: number)
			local route = editor.getCurrentRoute()
			if not route or #route.points == 0 then return end

			state.editorSelectedPointIndex = math.clamp(index, 1, #route.points)
			state.editorSelectedAction = route.points[state.editorSelectedPointIndex].action
			ctx.refreshRouteMarkers()
		end

		function editor.moveSelectedRoutePointOrder(offset: number)
			local route = editor.getCurrentRoute()
			if not route or #route.points < 2 then return end

			local oldIndex = math.clamp(state.editorSelectedPointIndex, 1, #route.points)
			local newIndex = math.clamp(oldIndex + offset, 1, #route.points)
			if oldIndex == newIndex then return end

			local point = table.remove(route.points, oldIndex)
			table.insert(route.points, newIndex, point)
			state.editorSelectedPointIndex = newIndex
			state.editorSelectedAction = point.action
			if state.activeRoute == route then
				state.activeRoute = nil
				state.activeRoutePractice = false
				state.activeRouteCursor = 1
				state.activeTechAttempt = nil
			end
			ctx.refreshRouteMarkers()
			ctx.refreshControlButtons()
			ctx.pushLog(`Moved route node #{oldIndex} to #{newIndex}.`)
		end

	function editor.selectRouteIndex(index: number)
		if #state.routes == 0 then return end

		state.editorSelectedRouteIndex = math.clamp(index, 1, #state.routes)
		state.editorSelectedPointIndex = 1
		local route = state.routes[state.editorSelectedRouteIndex]
		if route and route.points[1] then
			state.editorSelectedAction = route.points[1].action
		end
		state.editorOpen = true
		ctx.refreshRouteMarkers()
		ctx.refreshControlButtons()
		ctx.pushLog(`Selected {route and route.name or "route"}.`)
	end

	function editor.deleteSelectedRoute()
		local route = editor.getCurrentRoute()
		if not route then return end

		local routeIndex = table.find(state.routes, route)
		if not routeIndex then return end

			if state.activeRoute == route then
				state.activeRoute = nil
				state.activeRoutePractice = false
				state.activeRouteCursor = 1
				state.activeTechAttempt = nil
			end

		table.remove(state.routes, routeIndex)
		state.editorSelectedRouteIndex = math.clamp(routeIndex, 1, math.max(1, #state.routes))
		state.editorSelectedPointIndex = 1
		ctx.refreshRouteMarkers()
		ctx.refreshControlButtons()
		ctx.pushLog(`Deleted route {route.name}.`)
	end

	function editor.setSelectedRoutePointAction(actionName: string)
		local route = editor.getCurrentRoute()
		if not route then return end

		local point = route.points[state.editorSelectedPointIndex]
		if not point then return end

			point.action = actionName
			state.editorSelectedAction = actionName
			ctx.pushLog(`Route node #{state.editorSelectedPointIndex} set to {actionName}.`)
			ctx.refreshRouteMarkers()
		end

	function editor.nudgeSelectedRoutePoint(delta: Vector3)
		local route = editor.getCurrentRoute()
		if not route then return end

		local point = route.points[state.editorSelectedPointIndex]
		if not point then return end

		point.position += delta
		ctx.refreshRouteMarkers()
	end

		function editor.setSelectedRoutePointStuds(value: number, absolute: boolean?)
			local route = editor.getCurrentRoute()
			if not route then return end

			local point = route.points[state.editorSelectedPointIndex]
			if not point then return end

			point.studs = if absolute then math.clamp(value, 0, 20) else math.clamp((point.studs or 0) + value, 0, 20)
			ctx.pushLog(`Node #{state.editorSelectedPointIndex} studs set to {math.floor((point.studs or 0) * 10) / 10}.`)
		end

		function editor.setCurrentRouteName(name: string)
			local route = editor.getCurrentRoute()
			if not route then return end

			local trimmedName = name:gsub("^%s+", ""):gsub("%s+$", "")
			if trimmedName == "" then return end

			route.name = string.sub(trimmedName, 1, 48)
			ctx.refreshControlButtons()
			ctx.pushLog(`Route renamed to {route.name}.`)
		end

		function editor.setCurrentRouteMaxTime(value: number)
			local route = editor.getCurrentRoute()
			if not route then return end

			route.maxTime = math.clamp(value, 1, 180)
			ctx.pushLog(`Route max time set to {math.floor(route.maxTime * 10) / 10}s.`)
	end

	function editor.setCurrentRouteCaps(maxVaults: number, maxSwings: number, maxRolls: number)
		local route = editor.getCurrentRoute()
		if not route then return end

		route.maxVaults = math.clamp(math.floor(maxVaults), 0, 999)
		route.maxSwings = math.clamp(math.floor(maxSwings), 0, 999)
		route.maxRolls = math.clamp(math.floor(maxRolls), 0, 999)
		ctx.pushLog(`Route caps set to V/S/R {route.maxVaults}/{route.maxSwings}/{route.maxRolls}.`)
	end

	function editor.deleteSelectedRoutePoint()
		local route = editor.getCurrentRoute()
		if not route then return end
		if not route.points[state.editorSelectedPointIndex] then return end

			table.remove(route.points, state.editorSelectedPointIndex)
			state.editorSelectedPointIndex = math.clamp(state.editorSelectedPointIndex, 1, math.max(1, #route.points))
			ctx.refreshRouteMarkers()
			ctx.pushLog("Deleted selected route node.")
		end

	function editor.resetActiveRouteToStart(reason: string)
		local route = state.activeRoute
		local rootPart = state.rootPart
		local humanoid = state.humanoid
		if not route or not rootPart or not humanoid then return end

		local startPoint = route.points[1]
		if not startPoint then return end

		local nextPoint = route.points[2] or startPoint
		local flatDirection = Vector3.new(nextPoint.position.X - startPoint.position.X, 0, nextPoint.position.Z - startPoint.position.Z)
		local lookDirection = if flatDirection.Magnitude > 0.1 then flatDirection.Unit else Vector3.zAxis
		local spawnPosition = startPoint.position + Vector3.new(0, 2.75, 0)

		rootPart.CFrame = CFrame.lookAt(spawnPosition, spawnPosition + lookDirection)
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
		humanoid:Move(Vector3.zero, false)

		state.activeRouteCursor = if #route.points >= 2 then 2 else 1
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
		state.lastRouteVaultMissTime = 0
		state.routePreVaultJumpCursor = 0
		state.lastRoutePreVaultJumpTime = 0
		state.routeLastProgressTime = os.clock()
		state.routeBestDistance = math.huge
		state.routeResetCount = if reason == "started" then 0 else state.routeResetCount + 1
		state.activeTechAttempt = nil
		state.stuckSeconds = 0
		state.lastDistance = nil
		state.lastPosition = rootPart.Position
		state.lastRewardTime = os.clock()

		ctx.pushLog(`Route reset: {reason}.`)
	end

	function editor.dragSelectedRoutePointToMouse()
		local pointIndex = state.editorDraggingPointIndex
		if not pointIndex then return end

		local route = editor.getCurrentRoute()
		if not route then return end

		local point = route.points[pointIndex]
		if not point then return end

		local camera = workspace.CurrentCamera
		if not camera then return end

		local mouseLocation = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)
		point.position = ray.Origin + ray.Direction * state.editorDragDepth + state.editorDragOffset

		ctx.refreshRouteMarkers()
	end

	function editor.startSelectedRoute()
		local route = editor.getCurrentRoute()
		if not route or #route.points == 0 then
			ctx.pushLog("No route points recorded yet.")
			return
		end

			state.activeRoute = route
			state.activeRoutePractice = true
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
		state.lastRouteVaultMissTime = 0
		state.routePreVaultJumpCursor = 0
		state.lastRoutePreVaultJumpTime = 0
		state.routeResetCount = 0
		state.training = true
		editor.resetActiveRouteToStart("started")
		ctx.refreshControlButtons()
		ctx.pushLog(`Running route: {route.name}.`)
	end

	return editor
end

return BotRouteEditor
