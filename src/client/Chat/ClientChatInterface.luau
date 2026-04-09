local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	processingReceivedMessageSignal = Signal.new(),

	addedMessageToHistorySignal = Signal.new(),
}
