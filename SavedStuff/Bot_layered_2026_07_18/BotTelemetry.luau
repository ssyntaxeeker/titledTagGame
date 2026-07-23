--!strict
--[[
    BotTelemetry (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Session telemetry for objective bot evaluation. It aggregates transition
    outcomes and navigation churn into bounded time buckets without owning UI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Modules.Bot.BotNavigationTypes)

type ActionKind = Types.ActionKind

export type RActionStat = {
	attempts: number,
	successes: number,
	reward: number,
	duration: number,
}

export type RBucket = {
	startedAt: number,
	attempts: number,
	successes: number,
	techAttempts: number,
	techSuccesses: number,
	reward: number,
	duration: number,
	replans: number,
	recoveries: number,
}

export type RDashboard = {
	summary: string,
	actions: string,
	trendWindowSeconds: number,
	successRate: { number },
	rewardPerAttempt: { number },
	techShare: { number },
	techSuccessRate: { number },
	navigationChurn: { number },
}

export type RState = {
	actions: { [string]: RActionStat },
	roles: { [string]: RActionStat },
	buckets: { RBucket },
	buttonSuccesses: number,
	buttonFailures: number,
	lastPlanIds: { [Model]: number },
	lastDecisions: { [Model]: string },
	eventActions: { [string]: RActionStat },
	lastEventFlushAt: number,
	bucketSeconds: number,
	maximumBuckets: number,
	trendWindowBuckets: number,
}

local BotTelemetry = {}

local function newBucket(startedAt: number): RBucket
	return {
		startedAt = startedAt,
		attempts = 0,
		successes = 0,
		techAttempts = 0,
		techSuccesses = 0,
		reward = 0,
		duration = 0,
		replans = 0,
		recoveries = 0,
	}
end

local function accumulateBucket(result: RBucket, bucket: RBucket, multiplier: number)
	result.attempts += bucket.attempts * multiplier
	result.successes += bucket.successes * multiplier
	result.techAttempts += bucket.techAttempts * multiplier
	result.techSuccesses += bucket.techSuccesses * multiplier
	result.reward += bucket.reward * multiplier
	result.duration += bucket.duration * multiplier
	result.replans += bucket.replans * multiplier
	result.recoveries += bucket.recoveries * multiplier
end

local function currentBucket(state: RState): RBucket
	local now = os.clock()
	local bucket = state.buckets[#state.buckets]
	if not bucket or now - bucket.startedAt >= state.bucketSeconds then
		bucket = newBucket(now)
		state.buckets[#state.buckets + 1] = bucket
		if #state.buckets > state.maximumBuckets then table.remove(state.buckets, 1) end
	end
	return bucket
end

local function aggregate(buckets: { RBucket }, firstIndex: number, lastIndex: number): RBucket
	local result = newBucket(0)
	for index = math.max(1, firstIndex), math.min(#buckets, lastIndex) do
		accumulateBucket(result, buckets[index], 1)
	end
	return result
end

local function percentage(value: number): number
	return math.floor(value * 1000 + 0.5) / 10
end

function BotTelemetry.create(): RState
	return {
		actions = {},
		roles = {},
		buckets = { newBucket(os.clock()) },
		buttonSuccesses = 0,
		buttonFailures = 0,
		lastPlanIds = {},
		lastDecisions = {},
		eventActions = {},
		lastEventFlushAt = os.clock(),
		bucketSeconds = 2,
		maximumBuckets = 90,
		trendWindowBuckets = 15,
	}
end

function BotTelemetry.recordTransition(
	state: RState,
	action: ActionKind,
	role: string,
	succeeded: boolean,
	reward: number,
	duration: number
)
	local stat = state.actions[action]
	if not stat then
		stat = { attempts = 0, successes = 0, reward = 0, duration = 0 }
		state.actions[action] = stat
	end
	stat.attempts += 1
	if succeeded then stat.successes += 1 end
	stat.reward += reward
	stat.duration += duration
	local roleStat = state.roles[role]
	if not roleStat then
		roleStat = { attempts = 0, successes = 0, reward = 0, duration = 0 }
		state.roles[role] = roleStat
	end
	roleStat.attempts += 1
	if succeeded then roleStat.successes += 1 end
	roleStat.reward += reward
	roleStat.duration += duration
	local eventStat = state.eventActions[action]
	if not eventStat then
		eventStat = { attempts = 0, successes = 0, reward = 0, duration = 0 }
		state.eventActions[action] = eventStat
	end
	eventStat.attempts += 1
	if succeeded then eventStat.successes += 1 end
	eventStat.reward += reward
	eventStat.duration += duration

	local bucket = currentBucket(state)
	bucket.attempts += 1
	if succeeded then bucket.successes += 1 end
	if action ~= "Walk" then
		bucket.techAttempts += 1
		if succeeded then bucket.techSuccesses += 1 end
	end
	bucket.reward += reward
	bucket.duration += duration
end

function BotTelemetry.consumeEventSummary(state: RState): string?
	if os.clock() - state.lastEventFlushAt < 1 or next(state.eventActions) == nil then return nil end
	local actionNames: { string } = {}
	for action in state.eventActions do actionNames[#actionNames + 1] = action end
	table.sort(actionNames)
	local parts: { string } = {}
	for _, action in actionNames do
		local stat = state.eventActions[action]
		parts[#parts + 1] = `{action} {stat.successes}/{stat.attempts} R{math.floor(stat.reward / stat.attempts * 100) / 100} {math.floor(stat.duration / stat.attempts * 100) / 100}s`
	end
	table.clear(state.eventActions)
	state.lastEventFlushAt = os.clock()
	return `EDGE RESULTS: {table.concat(parts, " | ")}`
end

function BotTelemetry.recordButton(state: RState, succeeded: boolean)
	if succeeded then
		state.buttonSuccesses += 1
	else
		state.buttonFailures += 1
	end
end

function BotTelemetry.observeAgent(state: RState, agent: any)
	if not agent or not agent.character or not agent.character.Parent then return end
	local model = agent.character :: Model
	local planId = if agent.plan then agent.plan.id else 0
	local previousPlanId = state.lastPlanIds[model]
	if previousPlanId ~= nil and planId > 0 and planId ~= previousPlanId then
		currentBucket(state).replans += 1
	end
	state.lastPlanIds[model] = planId

	local decision = tostring(agent.decision or "")
	local previousDecision = state.lastDecisions[model]
	if decision ~= previousDecision
		and (string.find(string.lower(decision), "recover", 1, true)
			or string.find(string.lower(decision), "stuck", 1, true))
	then
		currentBucket(state).recoveries += 1
	end
	state.lastDecisions[model] = decision
end

function BotTelemetry.getDashboard(state: RState): RDashboard
	currentBucket(state)
	local successRate: { number } = {}
	local rewardPerAttempt: { number } = {}
	local techShare: { number } = {}
	local techSuccessRate: { number } = {}
	local navigationChurn: { number } = {}
	local trend = newBucket(0)
	for index, bucket in state.buckets do
		accumulateBucket(trend, bucket, 1)
		local expiredIndex = index - state.trendWindowBuckets
		if expiredIndex >= 1 then accumulateBucket(trend, state.buckets[expiredIndex], -1) end
		if trend.attempts > 0 then
			successRate[index] = trend.successes / trend.attempts
			rewardPerAttempt[index] = trend.reward / trend.attempts
			techShare[index] = trend.techAttempts / trend.attempts
		elseif index > 1 then
			successRate[index] = successRate[index - 1]
			rewardPerAttempt[index] = rewardPerAttempt[index - 1]
			techShare[index] = techShare[index - 1]
		else
			successRate[index] = 0
			rewardPerAttempt[index] = 0
			techShare[index] = 0
		end
		if trend.techAttempts > 0 then
			techSuccessRate[index] = trend.techSuccesses / trend.techAttempts
		elseif index > 1 then
			techSuccessRate[index] = techSuccessRate[index - 1]
		else
			techSuccessRate[index] = 0
		end
		navigationChurn[index] = (trend.replans + trend.recoveries)
			/ math.min(index, state.trendWindowBuckets)
	end

	local window = math.max(1, math.min(10, math.floor(#state.buckets / 2)))
	local recent = aggregate(state.buckets, #state.buckets - window + 1, #state.buckets)
	local previous = aggregate(state.buckets, #state.buckets - window * 2 + 1, #state.buckets - window)
	local recentSuccess = if recent.attempts > 0 then recent.successes / recent.attempts else 0
	local previousSuccess = if previous.attempts > 0 then previous.successes / previous.attempts else 0
	local recentReward = if recent.attempts > 0 then recent.reward / recent.attempts else 0
	local previousReward = if previous.attempts > 0 then previous.reward / previous.attempts else 0
	local recentDuration = if recent.attempts > 0 then recent.duration / recent.attempts else 0
	local previousDuration = if previous.attempts > 0 then previous.duration / previous.attempts else 0
	local recentTechSuccess = if recent.techAttempts > 0 then recent.techSuccesses / recent.techAttempts else 0
	local recentTechShare = if recent.attempts > 0 then recent.techAttempts / recent.attempts else 0

	local actionNames: { string } = {}
	for action in state.actions do actionNames[#actionNames + 1] = action end
	table.sort(actionNames, function(left, right)
		return state.actions[left].attempts > state.actions[right].attempts
	end)
	local actionLines: { string } = {}
	for _, action in actionNames do
		local stat = state.actions[action]
		local rate = if stat.attempts > 0 then stat.successes / stat.attempts else 0
		local meanReward = if stat.attempts > 0 then stat.reward / stat.attempts else 0
		local meanDuration = if stat.attempts > 0 then stat.duration / stat.attempts else 0
		actionLines[#actionLines + 1] = `{action}: {stat.successes}/{stat.attempts} {percentage(rate)}% | R {math.floor(meanReward * 100) / 100} | {math.floor(meanDuration * 100) / 100}s`
	end
	local roleParts: { string } = {}
	for _, role in { "Tagger", "Runner" } do
		local stat = state.roles[role]
		if stat then
			roleParts[#roleParts + 1] = `{role} {stat.successes}/{stat.attempts} {percentage(stat.successes / math.max(1, stat.attempts))}% R{math.floor(stat.reward / math.max(1, stat.attempts) * 100) / 100}`
		end
	end

	return {
		summary = table.concat({
			`Charts use a count-weighted rolling {state.bucketSeconds * state.trendWindowBuckets}s trend`,
			`Recent success {percentage(recentSuccess)}% ({if recentSuccess >= previousSuccess then "+" else ""}{percentage(recentSuccess - previousSuccess)}pp)`,
			`Tech success {percentage(recentTechSuccess)}% | tech share {percentage(recentTechShare)}%`,
			if #roleParts > 0 then table.concat(roleParts, " | ") else "Role results unavailable",
			`Reward/edge {math.floor(recentReward * 100) / 100} ({if recentReward >= previousReward then "+" else ""}{math.floor((recentReward - previousReward) * 100) / 100})`,
			`Duration/edge {math.floor(recentDuration * 100) / 100}s ({if recentDuration >= previousDuration then "+" else ""}{math.floor((recentDuration - previousDuration) * 100) / 100}s)`,
			`Recent replans {recent.replans} | recoveries {recent.recoveries} | UI errors {state.buttonFailures}`,
		}, "\n"),
		actions = if #actionLines > 0 then table.concat(actionLines, "\n") else "No completed transitions yet.",
		trendWindowSeconds = state.bucketSeconds * state.trendWindowBuckets,
		successRate = successRate,
		rewardPerAttempt = rewardPerAttempt,
		techShare = techShare,
		techSuccessRate = techSuccessRate,
		navigationChurn = navigationChurn,
	}
end

return table.freeze(BotTelemetry)
