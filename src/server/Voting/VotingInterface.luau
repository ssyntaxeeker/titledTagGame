--!strict

return {
	votes = {} :: { [Player]: string? },
	currentItems = {} :: { string },
	roundId = 0,
	voteType = "mode",
}
