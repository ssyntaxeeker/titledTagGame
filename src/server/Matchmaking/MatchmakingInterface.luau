local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	queuedPlayers = {},
	scores = {},
	runnerTimes = {},
	rankedAwardsEnabled = false,
	ratingAwarded = false,

	killedSignal = Signal.new(),
}
