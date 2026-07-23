--!strict
--[[
    BotTypes (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Shared bot type definitions and stable lookup tables.
]]

export type ActionKind =
	"Walk"
	| "Jump"
	| "Vault"
	| "HighVault"
	| "Swing"
	| "Roll"
	| "RollBoost"
	| "SlideBoost"
	| "Trampoline"
	| "Drop"

export type RoleName = "Tagger" | "Peasant" | "Runner" | "Crown"

export type RGraphEdge = {
	to: number,
	cost: number,
	action: ActionKind,
	heightDelta: number,
	clearance: number,
	contactPosition: Vector3?,
}

export type RGraphNode = {
	id: number,
	position: Vector3,
	sectorKey: string,
	wallPenalty: number,
	verticalScore: number,
	wallMask: number,
	openDirections: number,
	openness: number,
	nearestWallDistance: number,
	headClearance: number,
	dropHeight: number,
	escapeScore: number,
	climbScore: number,
	rollSetupScore: number,
	isTrampoline: boolean,
	edges: { RGraphEdge },
}

export type RGraph = {
	nodes: { RGraphNode },
	nodeByCell: { [string]: number },
	sectors: { [string]: { number } },
	spatialBuckets: { [string]: { number } },
	boundsCenter: Vector3,
	boundsSize: Vector3,
	version: number,
}

export type RPlannerJob = {
	startNodeId: number,
	goalNodeId: number,
	open: { number },
	openSet: { [number]: boolean },
	cameFrom: { [number]: number },
	costSoFar: { [number]: number },
	closed: { [number]: boolean },
	expansions: number,
	done: boolean,
	failed: boolean,
	path: { number },
}

export type RLearningMemory = {
	edgeScores: { [string]: number },
	edgeAttempts: { [string]: number },
	techScores: { [string]: number },
	techAttempts: { [string]: number },
	deadEndScores: { [string]: number },
	areaScores: { [string]: number },
	areaAttempts: { [string]: number },
	playerRouteScores: { [string]: number },
}

local ActionCost = table.freeze({
	Walk = 1,
	Jump = 0.92,
	Vault = 0.8,
	HighVault = 0.9,
	Swing = 0.72,
	Roll = 0.5,
	RollBoost = 0.7,
	SlideBoost = 1.05,
	Trampoline = 0.6,
	Drop = 0.62,
})

local RunnerRoles = table.freeze({
	Runner = true,
	Crown = true,
})

local TaggerRoles = table.freeze({
	Tagger = true,
	Peasant = true,
})

return table.freeze({
	ActionCost = ActionCost,
	RunnerRoles = RunnerRoles,
	TaggerRoles = TaggerRoles,
})
