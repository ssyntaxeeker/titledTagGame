local module = {}
local cooldowns = {}

local function setupEntity(entity: number)
	if cooldowns[entity] then return end

	cooldowns[entity] = {}
end

function module.modifyCooldown(entity: any, cooldownId: string, bool: boolean, timer: number?)
	setupEntity(entity)
	cooldowns[entity][cooldownId] = bool

	if timer then
		task.delay(timer, function()
			if cooldowns[entity][cooldownId] ~= bool then return end

			cooldowns[entity][cooldownId] = not cooldowns[entity][cooldownId]
		end)
	end
end

function module.getCooldown(entity: any, cooldownId: string): boolean
	setupEntity(entity)

	return cooldowns[entity][cooldownId] or false
end

return module
