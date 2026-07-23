--!strict
--[[
    BotNavigationTypes (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Inert contracts shared by the rebuilt map, affordance, planning, skill,
    tactics, and debug layers.
]]

export type ActionKind =
	"Walk"
	| "Jump"
	| "Vault"
	| "HighVault"
	| "TrussClimb"
	| "Swing"
	| "Drop"
	| "Roll"
	| "RollBoost"
	| "SlideBoost"
	| "Trampoline"

export type BotRole = "Tagger" | "Runner"

export type RSwingAnchor = {
	id: number,
	position: Vector3,
	bar: BasePart,
}

export type RSurfaceNode = {
	id: number,
	rootPosition: Vector3,
	floorPosition: Vector3,
	floorNormal: Vector3,
	surface: BasePart,
	layer: number,
	clearance: number,
	wallMask: number,
	openDirections: number,
	nearestWallDistance: number,
	isBarrierAdjacent: boolean,
	isTrampoline: boolean,
	edges: { number },
}

export type RMapModel = {
	mapRoot: Instance,
	floorY: number,
	nodes: { RSurfaceNode },
	nodeByCell: { [string]: number },
	partIds: { [BasePart]: number },
	buckets: { [string]: { number } },
	spacingBuckets: { [string]: { number } },
	swingBars: { BasePart },
	swingAnchors: { RSwingAnchor },
	trampolines: { BasePart },
	vaultableParts: { BasePart },
	trusses: { TrussPart },
	boundsCenter: Vector3,
	boundsSize: Vector3,
	buildVersion: number,
	ready: boolean,
}

export type RTransitionSetup = {
	approachPosition: Vector3,
	approachDirection: Vector3,
	lookTarget: Vector3?,
	contactPosition: Vector3?,
	targetPart: BasePart?,
	requiredHeight: number,
	requiredSpeed: number,
	timingMin: number,
	timingMax: number,
	requiresSlide: boolean?,
}

export type RAffordanceEdge = {
	id: number,
	from: number,
	to: number,
	action: ActionKind,
	expectedTime: number,
	baseCost: number,
	successProbability: number,
	failureRisk: number,
	setup: RTransitionSetup,
	memoryKeys: {
		edge: string,
		areaAction: string,
		general: string,
	}?,
	playerTransitionBaseKey: string?,
	taughtTransitionBaseKey: string?,
}

export type RAffordanceGraph = {
	mapModel: RMapModel,
	edges: { RAffordanceEdge },
	ready: boolean,
	buildVersion: number,
}

export type RPlan = {
	id: number,
	goalPosition: Vector3,
	goalNodeId: number,
	nodeIds: { number },
	edgeIds: { number },
	totalCost: number,
	expectedTime: number,
	successProbability: number,
	opponentAdvantage: number,
	minimumOpponentClearance: number,
	interceptionMargin: number,
	edgeAdvantages: { number },
	edgeClearances: { number },
	edgeInterceptionMargins: { number },
	isPartial: boolean,
	createdAt: number,
}

export type RPlannerJob = {
	id: number,
	role: BotRole,
	startNodeId: number,
	goalNodeId: number,
	goalPosition: Vector3,
	openHeap: { { nodeId: number, score: number } },
	openBest: { [number]: number },
	cameFromNode: { [number]: number },
	cameFromEdge: { [number]: number },
	gScore: { [number]: number },
	closed: { [number]: boolean },
	activeNodeId: number?,
	activeEdgeCursor: number,
	expansions: number,
	done: boolean,
	failed: boolean,
	cancelled: boolean,
	plan: RPlan?,
}

export type RSkillResult = {
	status: "Idle" | "Running" | "Succeeded" | "Failed",
	action: ActionKind?,
	reason: string,
	edgeId: number?,
}

return table.freeze({})
