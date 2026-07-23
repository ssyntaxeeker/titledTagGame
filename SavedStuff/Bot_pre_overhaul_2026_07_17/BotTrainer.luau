--!strict
--[[
    BotTrainer (Client)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Entry point for the rebuilt lightweight bot trainer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotRuntime = require(ReplicatedStorage.Modules.Bot.BotRuntime)
local BotTrainerUI = require(ReplicatedStorage.Modules.Bot.BotTrainerUI)

local initialized = false

local function init()
	if initialized then return end
	initialized = true

	BotRuntime.init()
	BotTrainerUI.create(BotRuntime)
end

init()

return table.freeze({
	init = init,
})
