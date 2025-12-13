local PlayerReplicationModules = {}

local list = {}

function PlayerReplicationModules.RegisterModule(moduleName, callback)
	list[moduleName] = callback

	return 0
end

function PlayerReplicationModules.GetModule(moduleName)
	return list[moduleName]
end

return PlayerReplicationModules
