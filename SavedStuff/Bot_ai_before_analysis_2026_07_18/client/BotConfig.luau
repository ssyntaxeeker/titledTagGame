--!strict
--[[
    BotConfig (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Frozen physical, navigation, tactical, and frame-budget tuning for the
    second-generation training bot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParkourMovementModel = require(ReplicatedStorage.Modules.Character.Parkour.ParkourMovementModel)

local Config = {
	rootFloorOffset = 2.75,
	walkSpeed = 32,
	jumpPower = 28,
	tagRange = 8,
	tagLockoutSeconds = 2,

	mapStep = 4.5,
	mapPrecisionStep = 1,
	mapPrecisionSurfaceTag = "BotPrecisionSurface",
	mapMinimumNodeSpacing = 1.4,
	mapMaximumNodes = 18000,
	mapBucketSize = 18,
	mapBuildBudget = 0.002,
	graphBuildBudget = 0.0025,
	bodyWidth = 2.2,
	bodyHeight = 5,
	walkableNormalY = 0.58,
	minimumHeadroom = 2.7,
	neighborRadius = 10,
	climbNeighborRadius = 15,
	maximumDrop = 34,
	walkStepHeight = 1,
	jumpHeight = 5.5,
	groundVaultHeight = 5.5,
	highVaultHeight = 11.5,
	slideBoostMinimumHeight = 11.6,
	slideBoostMaximumHeight = 13.5,
	swingReach = 11,

	plannerBudget = 0.0007,
	plannerUrgentBudget = 0.0012,
	plannerMaximumExpansions = 3500,
	plannerMaximumSearchSeconds = 0.2,
	plannerMinimumPartialExpansions = 48,
	plannerHeuristicWeight = 1.08,
	plannerReplanSeconds = 0.35,
	plannerGoalMoveDistance = 18,
	plannerGoalLayerTolerance = 4,
	plannerReachDistance = 4,
	plannerWalkLookahead = 5,
	plannerWalkSimplifyDirectionDot = 0.985,
	plannerWalkSimplifyLateralTolerance = 1.25,
	plannerWalkSimplifyMaximumDistance = 36,
	plannerExtensionLookahead = 3,
	plannerExtensionGoalMoveDistance = 8,
	plannerPreviewExpansions = 32,
	plannerFailureBlockSeconds = 10,

	runnerRolloutTransitionsPerStep = 80,
	runnerRolloutMaximumTransitions = 560,
	runnerRolloutMaximumDepth = 10,
	runnerRolloutMaximumTravelTime = 6,
	runnerGoalCommitSeconds = 2.2,
	runnerPressureCommitSeconds = 0.65,
	runnerThreatRadius = 22,
	runnerSafeClearance = 13,
	runnerGoalMinimumDistance = 24,
	runnerGoalPreferredDistance = 70,
	runnerDeadEndPenalty = 42,
	runnerCorridorPenalty = 5,
	runnerBarrierPenalty = 50,
	runnerInterceptPenalty = 70,
	runnerReversalPenalty = 18,
	runnerVerticalBonus = 0.3,
	runnerOrbitWeight = 9,
	runnerBranchWeight = 5,
	runnerDistanceWeight = 0.65,
	runnerTravelTimeWeight = 2.2,
	runnerMemoryWeight = 0.08,
	runnerRecentGoalPenalty = 18,
	runnerRecentGoalCount = 6,

	taggerDirectDistance = 30,
	taggerEmergencyDirectDistance = 12,
	taggerPredictionSeconds = 0.3,
	taggerCorridorCheckSeconds = 0.1,
	taggerCorridorGoalMoveDistance = 8,
	taggerDirectionStabilityDot = 0.55,
	taggerVerticalCommitDifference = 6,
	taggerVerticalCommitSeconds = 2.5,

	stuckMovementDistance = 0.75,
	stuckMovementSeconds = 0.7,
	stuckProgressDistance = 0.8,
	stuckProgressSeconds = 1.15,
	stuckRecoveryCommitSeconds = 2.5,

	jumpCooldown = 0.1,
	vaultCooldown = ParkourMovementModel.cooldowns.vault,
	swingCooldown = ParkourMovementModel.cooldowns.swing,
	rollCooldown = ParkourMovementModel.cooldowns.roll,
	rollRequiredVelocity = ParkourMovementModel.rollRequiredVelocity,
	rollDuration = 0.5,
	rollBoostDelay = 0.15,
	slideCooldown = 0.5,
	slideHoldMinimum = 0.2,
	slideHoldMaximum = 0.35,
	slideJumpDelayMinimum = 0.06,
	slideJumpDelayMaximum = 0.15,
	skillApproachTolerance = 3,
	skillTimeout = 2.4,
	taughtRouteActivationRadius = 18,
	taughtRouteProgressTolerance = 12,
	playerObservationInterval = 0.15,

	actionCost = table.freeze({
		Walk = 0.08,
		Jump = 0.01,
		Vault = 0.015,
		HighVault = 0.025,
		TrussClimb = 0.02,
		Swing = 0.03,
		Drop = 0.04,
		RollBoost = 0.035,
		SlideBoost = 0.13,
		Trampoline = 0.02,
	}),

	debugInstancesPerFrame = 100,
	debugMaximumRoutePoints = 80,
	debugMaximumRouteLabels = 18,
	updateRate = 30,
}

return table.freeze(Config)
