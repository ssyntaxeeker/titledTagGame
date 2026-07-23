--!strict
--[[
    RouteAttemptRecorder (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/20

    Records one local-player route attempt with pose, facing, velocity, and
    inferred parkour action at a fixed rate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerConfig)
local Inference = require(ReplicatedStorage.Modules.Bot.Analysis.MatchTechniqueInference)
local RoutePathProcessor = require(ReplicatedStorage.Shared.Bot.RoutePathProcessor)
local Types = require(ReplicatedStorage.Modules.Bot.RouteTrainer.RouteTrainerTypes)

type RAttempt = Types.RAttempt

export type RRecorder = {
	map: Instance,
	startedAt: number,
	previous: any?,
	points: { { number } },
	actions: { string },
	distance: number,
	techCount: number,
	lastAction: string,
}

local RouteAttemptRecorder = {}

local function rounded(value: number, precision: number): number
	return math.floor(value / precision + 0.5) * precision
end

function RouteAttemptRecorder.create(map: Instance): RRecorder
	return {
		map = map,
		startedAt = os.clock(),
		previous = nil,
		points = {},
		actions = {},
		distance = 0,
		techCount = 0,
		lastAction = "Run",
	}
end

function RouteAttemptRecorder.step(recorder: RRecorder)
	if os.clock() - recorder.startedAt > Config.maximumAttemptSeconds then return end
	local frame = Inference.sample(Players.LocalPlayer, recorder.previous, recorder.map)
	if not frame then return end
	if recorder.previous then recorder.distance += (frame.position - recorder.previous.position).Magnitude end
	if frame.action ~= recorder.lastAction and frame.action ~= "Run" and frame.action ~= "Drop" then
		recorder.techCount += 1
	end
	recorder.points[#recorder.points + 1] = {
		rounded(frame.position.X, 0.25),
		rounded(frame.position.Y, 0.25),
		rounded(frame.position.Z, 0.25),
		rounded(frame.time - recorder.startedAt, 0.05),
		rounded(frame.look.X, 0.02),
		rounded(frame.look.Y, 0.02),
		rounded(frame.look.Z, 0.02),
		rounded(frame.velocity.X, 0.25),
		rounded(frame.velocity.Y, 0.25),
		rounded(frame.velocity.Z, 0.25),
	}
	recorder.actions[#recorder.actions + 1] = frame.action
	recorder.lastAction = frame.action
	recorder.previous = frame
end

function RouteAttemptRecorder.finish(recorder: RRecorder, success: boolean): RAttempt?
	Inference.clear(Players.LocalPlayer)
	if #recorder.points < 3 then return nil end
	local path = RoutePathProcessor.clean(recorder.points, recorder.actions)
	local first = path.points[1]
	local last = path.points[#path.points]
	local displacement = (Vector3.new(last[1], last[2], last[3]) - Vector3.new(first[1], first[2], first[3])).Magnitude
	local duration = math.max(last[4], 0.05)
	local distance = 0
	local techCount = 0
	local previousAction = "Run"
	for index = 2, #path.points do
		local previousPoint = path.points[index - 1]
		local point = path.points[index]
		distance += (Vector3.new(point[1], point[2], point[3]) - Vector3.new(previousPoint[1], previousPoint[2], previousPoint[3])).Magnitude
		local action = path.actions[index]
		if action ~= previousAction and action ~= "Run" and action ~= "Drop" then techCount += 1 end
		previousAction = action
	end
	return {
		success = success,
		duration = duration,
		distance = distance,
		displacement = displacement,
		averageSpeed = distance / duration,
		techCount = techCount,
		points = path.points,
		actions = path.actions,
	}
end

return table.freeze(RouteAttemptRecorder)
