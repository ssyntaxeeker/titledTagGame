local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	queuedPlayers = {},
	scores = {},
	runnerTimes = {},

	killedSignal = Signal.new(),
}
