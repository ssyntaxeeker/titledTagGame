--!strict
--[[
    RouteTrainerTypes (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Inert route-authoring, attempt, and published-route contracts.
]]

export type RAttempt = {
	success: boolean,
	duration: number,
	distance: number,
	displacement: number,
	averageSpeed: number,
	techCount: number,
	points: { { number } },
	actions: { string },
}

export type RRouteInfo = {
	id: string,
	title: string,
	creatorId: number,
	creatorName: string,
	attemptCount: number,
	successCount: number,
	rating: number,
	ratingCount: number,
	start: { number },
	finish: { number },
	middle: { number },
	updatedAt: number,
}

return table.freeze({})
