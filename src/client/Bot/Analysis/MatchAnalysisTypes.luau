--!strict
--[[
    MatchAnalysisTypes (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/21

    Inert contracts for whitelisted match observation and learned map memory.
]]

export type ObservedRole = "Chaser" | "Runner"
export type Technique = "Run" | "Jump" | "Vault" | "Swing" | "Walljump" | "Wallrun" | "Zipline" | "Rail" | "Rope" | "Windforce" | "Crouch" | "Slide" | "Roll" | "SlideBoost" | "RollBoost" | "Tramp" | "Trampoline" | "Drop" | "UnknownTech"

export type RGeometry = {
	floorY: number,
	headroom: number,
	wallDistance: number,
	wallHeight: number,
	nearSwingBar: boolean,
	nearTrampoline: boolean,
}

export type RFrame = {
	time: number,
	position: Vector3,
	velocity: Vector3,
	moveDirection: Vector3,
	look: Vector3,
	walkSpeed: number,
	grounded: boolean,
	action: Technique,
	techValue: number?,
	geometry: RGeometry,
}

export type RTrack = {
	player: Player,
	role: ObservedRole,
	gameRole: string?,
	previous: RFrame?,
	lastCell: string?,
	cellEnteredAt: number,
	episodeStartedAt: number,
	episodeStartDistance: number,
	episodeDistance: number,
	episodePoints: { { number } },
	episodeActions: { string },
	lastPoint: Vector3?,
	lastAction: Technique,
	lastActionAt: number,
}

export type RBatch = {
	batchId: string,
	mapKey: string,
	zones: { [string]: { number } },
	transitions: { [string]: { number } },
	techniques: { { [string]: any } },
	lines: { { [string]: any } },
	routeReviews: { { [string]: any } },
}

export type RMemory = {
	version: number,
	mapKey: string,
	zones: { [string]: { [string]: any } },
	transitions: { [string]: { [string]: any } },
	techniques: { [string]: { [string]: any } },
	techObservations: { { [string]: any } },
	lines: { { [string]: any } },
	routeReviews: { { [string]: any } },
	updatedAt: number,
}

return table.freeze({})
