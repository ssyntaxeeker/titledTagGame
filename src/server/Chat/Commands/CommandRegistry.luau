local commands = {}

local CommandRegistry = {}

function CommandRegistry.RegisterCommand(commandName, commandFn)
	commands[commandName] = commandFn

	return 0
end

function CommandRegistry.GetCommand(commandName)
	return commands[commandName]
end

return CommandRegistry
