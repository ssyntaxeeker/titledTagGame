--!strict
--[[
    BotPolicyWeights (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Export target for the offline bot policy trainer. The default weights are
    intentionally neutral so the handcrafted graph planner remains in control
    until real samples are trained.
]]

return table.freeze({
	version = 1,
	inputSize = 12,
	actions = table.freeze({
		"Walk",
		"Jump",
		"Vault",
		"HighVault",
		"Swing",
		"Roll",
		"RollBoost",
		"SlideBoost",
		"Trampoline",
		"Drop",
	}),
	inputMean = table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
	inputStd = table.freeze({ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }),
	layers = table.freeze({
		table.freeze({
			activation = "linear",
			weights = table.freeze({
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
				table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
			}),
			bias = table.freeze({ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }),
		}),
	}),
})
