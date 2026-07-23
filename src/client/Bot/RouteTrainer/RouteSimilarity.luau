--!strict
--[[
    RouteSimilarity (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Detects authored routes occupying the same directed map corridor.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerConfig)
local Types = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerTypes)

type RAttempt = Types.RAttempt
type RRouteInfo = Types.RRouteInfo

local RouteSimilarity = {}

local function position(tuple: { number }): Vector3
	return Vector3.new(tuple[1], tuple[2], tuple[3])
end

function RouteSimilarity.find(attempt: RAttempt, routes: { RRouteInfo }): RRouteInfo?
	local points = attempt.points
	local start = position(points[1])
	local finish = position(points[#points])
	local middle = position(points[math.ceil(#points / 2)])
	local best: RRouteInfo? = nil
	local bestDistance = math.huge
	for _, route in routes do
		local startDistance = (start - position(route.start)).Magnitude
		local finishDistance = (finish - position(route.finish)).Magnitude
		local middleDistance = (middle - position(route.middle)).Magnitude
		if startDistance > Config.similarEndpointRadius
			or finishDistance > Config.similarEndpointRadius
			or middleDistance > Config.similarMidpointRadius
		then
			continue
		end
		local distance = startDistance + finishDistance + middleDistance
		if distance < bestDistance then
			best = route
			bestDistance = distance
		end
	end
	return best
end

return table.freeze(RouteSimilarity)
