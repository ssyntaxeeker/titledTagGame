--!strict
--[[
    CheckpointEscape (Shared)
    =========================
    Author: Sol (3693744006)
    Updated: 26/07/19

    Competitive course length, team ratio, and timer tuning shared by the
    authoritative mode and its local checkpoint presentation.
]]

return table.freeze({
	laps = 2,
	minimumCheckpoints = 2,
	baseRoundSeconds = 200,
	secondsPerPlayer = -0.8,
})
