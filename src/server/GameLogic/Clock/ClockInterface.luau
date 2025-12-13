local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	updateRunnerTimesSignal = Signal.new(),
	updateTagRangeSignal = Signal.new(),

	roundEndedSignal = Signal.new(),
}
