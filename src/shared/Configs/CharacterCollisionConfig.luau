--!strict
--[[
    CharacterCollisionConfig (Shared)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/18

    Defines the authoritative R6 body parts that participate in collisions.
]]

return table.freeze({
	collidablePartNames = table.freeze({
		Head = true,
		Torso = true,
		["Left Leg"] = true,
		["Right Leg"] = true,
	}),
})
