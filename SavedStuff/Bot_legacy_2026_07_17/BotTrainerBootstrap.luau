--!strict
--[[
    BotTrainerBootstrap (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/16

    Creates BotTrainer's persistence, route editor, and editor UI outside the
    main trainer module so the trainer stays below Luau's local register limit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotLearningPersistence = require(ReplicatedStorage.Modules.Bot.BotLearningPersistence)
local BotRouteEditor = require(ReplicatedStorage.Modules.Bot.BotRouteEditor)
local BotTrainerUI = require(ReplicatedStorage.Modules.Bot.BotTrainerUI)
local Net = require(ReplicatedStorage.Packages.Net)

local RetrieveBotTrainingDataRF = Net:RemoteFunction("RetrieveBotTrainingData")
local SaveBotLearningVersionRF = Net:RemoteFunction("SaveBotLearningVersion")
local FavoriteBotLearningVersionRF = Net:RemoteFunction("FavoriteBotLearningVersion")
local DeleteBotLearningVersionRF = Net:RemoteFunction("DeleteBotLearningVersion")
local SelectBotLearningVersionRF = Net:RemoteFunction("SelectBotLearningVersion")

local BotTrainerBootstrap = {}

function BotTrainerBootstrap.create(info: { [string]: any }): { [string]: any }
	local persistence = info.persistence
	if not persistence then
		persistence = BotLearningPersistence.create {
			state = info.state,
			retrieveRemote = RetrieveBotTrainingDataRF,
			saveRemote = SaveBotLearningVersionRF,
			refreshRouteMarkers = info.refreshRouteMarkers,
			pushLog = info.pushLog,
		}
	end

	local routeEditor = info.routeEditor
	if not routeEditor then
		routeEditor = BotRouteEditor.create {
			state = info.state,
			localPlayer = info.localPlayer,
			raycastParams = info.raycastParams,
			getIgnoreList = info.getIgnoreList,
			refreshRouteMarkers = info.refreshRouteMarkers,
			refreshControlButtons = info.refreshControlButtons,
			pushLog = info.pushLog,
		}
	end

	local trainerUi = BotTrainerUI.create {
		state = info.state,
		localPlayer = info.localPlayer,
		chaseStartDelaySeconds = info.chaseStartDelaySeconds,
		pushLog = info.pushLog,
		refreshControlButtons = info.refreshControlButtons,
		spawnBot = info.spawnBot,
		spawnRunnerBot = info.spawnRunnerBot,
		buildGraph = info.buildGraph,
		printGraph = info.printGraph,
		clearLearning = info.clearLearning,
		saveLearningVersion = persistence.saveLearningVersion,
		getSelectedRoleName = info.getSelectedRoleName,
		getSelectedEnabled = info.getSelectedEnabled,
		setSelectedEnabled = info.setSelectedEnabled,
		getSelectedSpeedMultiplier = info.getSelectedSpeedMultiplier,
		setSelectedSpeedMultiplier = info.setSelectedSpeedMultiplier,
		getRoleVersions = persistence.getRoleVersions,
		getSelectedVersion = persistence.getSelectedVersion,
		applyLearningVersion = persistence.applyLearningVersion,
		getCurrentRoute = routeEditor.getCurrentRoute,
		setEditorOpen = info.setEditorOpen,
		beginRouteRecording = routeEditor.beginRouteRecording,
			beginPlayerRouteRecording = routeEditor.beginPlayerRouteRecording,
			startGuidedTraining = info.startGuidedTraining,
			teachTechHint = info.teachTechHint,
			teachClimbableWall = info.teachClimbableWall,
			stopRouteRecording = routeEditor.stopRouteRecording,
		addRoutePoint = routeEditor.addRoutePoint,
		addRoutePointFromView = routeEditor.addRoutePointFromView,
		selectRoutePointIndex = routeEditor.selectRoutePointIndex,
		moveSelectedRoutePointOrder = routeEditor.moveSelectedRoutePointOrder,
		selectRouteIndex = routeEditor.selectRouteIndex,
		setSelectedRoutePointAction = routeEditor.setSelectedRoutePointAction,
		nudgeSelectedRoutePoint = routeEditor.nudgeSelectedRoutePoint,
		setSelectedRoutePointStuds = routeEditor.setSelectedRoutePointStuds,
		setCurrentRouteName = routeEditor.setCurrentRouteName,
		setCurrentRouteMaxTime = routeEditor.setCurrentRouteMaxTime,
		setCurrentRouteCaps = routeEditor.setCurrentRouteCaps,
		deleteSelectedRoutePoint = routeEditor.deleteSelectedRoutePoint,
		deleteSelectedRoute = routeEditor.deleteSelectedRoute,
		startSelectedRoute = routeEditor.startSelectedRoute,
		selectVersionRemote = SelectBotLearningVersionRF,
		favoriteVersionRemote = FavoriteBotLearningVersionRF,
		deleteVersionRemote = DeleteBotLearningVersionRF,
	}

	return {
		trainerUi = trainerUi,
		persistence = persistence,
		routeEditor = routeEditor,
	}
end

return BotTrainerBootstrap
