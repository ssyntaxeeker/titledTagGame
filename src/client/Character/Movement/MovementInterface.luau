--!strict
--[[
    MovementInterface (Client)
    ==========================
    Author: Sol (3693744006)
    Updated: 26/07/20

    Shared mutable input state consumed by keyboard, mobile, and movement
    physics controllers.
]]

return {
	LockMoveVector = false,
	LockedMoveDirection = Vector3.zero,

	IsJumping = false,
	WalkRequested = false,
	MoveVector = Vector3.zero,
}
