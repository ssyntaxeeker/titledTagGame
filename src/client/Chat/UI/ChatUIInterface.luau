local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

return {
	UI = nil,

	typingMode = 0,
	currentChannel = "Global",

	createdChatUISignal = Signal.new(),
}
