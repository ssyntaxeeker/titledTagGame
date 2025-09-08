local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schedules = require(ReplicatedStorage.Shared.Schedules)

local function createGroups()
	PhysicsService:RegisterCollisionGroup("DeadPlayers")
	PhysicsService:RegisterCollisionGroup("Players")

	PhysicsService:CollisionGroupSetCollidable("DeadPlayers", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("DeadPlayers", "Default", true)
end

return Schedules.Boot.job(createGroups)
