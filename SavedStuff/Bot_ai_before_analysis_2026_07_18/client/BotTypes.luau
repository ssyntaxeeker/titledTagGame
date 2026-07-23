--!strict
--[[
    BotTypes (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Inert contracts shared by the new world, graph, planner, motor, and brain
    modules.
]]

export type BotRole = "Tagger" | "Runner"
export type Action = "Walk" | "Jump" | "Vault" | "HighVault" | "TrussClimb" | "Swing" | "Drop" | "RollBoost" | "SlideBoost" | "Trampoline"

export type RNode = {
	id: number,
	position: Vector3,
	floorPosition: Vector3,
	surface: BasePart,
	clearance: number,
	openDirections: number,
	nearestWall: number,
	barrierAdjacent: boolean,
	edges: { number },
	exitCount: number,
	hasVerticalExit: boolean,
}

export type REdge = {
	id: number,
	from: number,
	to: number,
	action: Action,
	time: number,
	risk: number,
	approach: Vector3,
	direction: Vector3,
	target: Vector3,
	targetPart: BasePart?,
	height: number,
	taught: boolean?,
	taughtEvidence: number?,
}

export type RWorld = {
	map: Instance,
	floorY: number,
	nodes: { RNode },
	edges: { REdge },
	taughtEdges: { number },
	buckets: { [string]: { number } },
	ready: boolean,
	graphReady: boolean,
	version: number,
}

export type RPlan = {
	id: number,
	goal: Vector3,
	nodes: { number },
	edges: { number },
	cost: number,
	time: number,
	success: number,
	createdAt: number,
}

return table.freeze({})
