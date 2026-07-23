--!strict
--[[
    BotAccess (Shared)
    ==============
    Author: Sol (3693744006)
    Updated: 26/07/17

    Shared access policy for loading the private match analyzer and accepting
    its analysis persistence requests. User ids are authoritative.
]]

local BotAccess = {
	userIds = table.freeze({
		[3693744006] = true,
	}),
	trustedTeacherWeight = 2,
}

return table.freeze(BotAccess)
