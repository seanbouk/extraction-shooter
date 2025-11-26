--!strict

--[[
	SlashCommandService

	Automatically discovers and registers slash commands from models and controllers.
	Uses pure convention-based approach:
	- /modelname methodname args... → Executes model method
	- /controllername actionname args... → Fires controller RemoteEvent

	Requirements:
	- User must have rank 200+ to use commands
	- Commands are auto-discovered at server startup
	- Zero configuration needed in existing models/controllers
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local IntentActions = require(ReplicatedStorage:WaitForChild("IntentActions"))

local SlashCommandService = {}

-- Minimum rank required to use slash commands
local MIN_RANK = 200

-- Registered models and controllers
local userModels: { [string]: any } = {}
local serverModels: { [string]: any } = {}
local controllers: { [string]: { instance: any, remoteEvent: RemoteEvent, originalName: string } } = {}

-- RemoteEvent for command execution (client → server intent)
local commandRemote: RemoteEvent = nil

-- RemoteEvent for state changes (server → client feedback)
local messageRemote: RemoteEvent = nil

-- Group ID (determined at runtime)
local groupId: number? = nil

--[[
	Sends a message to the player's chat window
]]
local function sendChatMessage(player: Player, message: string): ()
	if messageRemote then
		messageRemote:FireClient(player, message)
	else
		warn("[SlashCommandService] Cannot send chat message - messageRemote not initialized")
	end
end

--[[
	Checks if a player has sufficient rank to use slash commands
]]
local function hasPermission(player: Player): boolean
	-- If game is owned by a group, check rank in that group
	if groupId then
		return player:GetRankInGroup(groupId) >= MIN_RANK
	end

	-- If game is owned by a user (not a group), allow all players with Studio Edit access
	-- or you could check if player is the owner: player.UserId == game.CreatorId
	-- For now, we'll allow everyone if not in a group (you can customize this)
	warn(`[SlashCommandService] Game is not owned by a group. Allowing all players to use commands.`)
	return true
end

--[[
	Parses command arguments from a string
	Attempts to convert to appropriate types (number, boolean, string)
]]
local function parseArguments(argString: string): { any }
	local args = {}

	for arg in string.gmatch(argString, "%S+") do
		-- Try to parse as number
		local num = tonumber(arg)
		if num then
			table.insert(args, num)
			continue
		end

		-- Try to parse as boolean
		if arg == "true" then
			table.insert(args, true)
			continue
		elseif arg == "false" then
			table.insert(args, false)
			continue
		end

		-- Default to string
		table.insert(args, arg)
	end

	return args
end

--[[
	Executes a model command
	Format: /modelname methodname args...
]]
local function executeModelCommand(player: Player, modelName: string, methodName: string, args: { any }): (boolean, string)
	-- Check user-scoped models first
	local modelClass = userModels[modelName:lower()]
	local isServerModel = false

	if not modelClass then
		-- Check server-scoped models
		modelClass = serverModels[modelName:lower()]
		isServerModel = true
	end

	if not modelClass then
		return false, `Model '{modelName}' not found`
	end

	-- Get the model instance
	local modelInstance
	if isServerModel then
		modelInstance = modelClass.get("SERVER")
	else
		modelInstance = modelClass.get(tostring(player.UserId))
	end

	if not modelInstance then
		return false, `Could not get instance of {modelName}`
	end

	-- Check if method exists
	if type(modelInstance[methodName]) ~= "function" then
		return false, `Method '{methodName}' not found in {modelName}`
	end

	-- Call the method
	local success, err = pcall(function()
		modelInstance[methodName](modelInstance, table.unpack(args))
	end)

	if not success then
		return false, `Error executing method: {err}`
	end

	return true, `Executed {modelName}:{methodName}`
end

--[[
	Executes a controller command
	Format: /controllername actionname args...
]]
local function executeControllerCommand(player: Player, controllerName: string, actionName: string, args: { any }): (boolean, string)
	local controllerInfo = controllers[controllerName:lower()]

	if not controllerInfo then
		return false, `Controller '{controllerName}' not found`
	end

	-- Call the controller's executeAction method directly
	-- Controllers expose this method for slash command execution
	local success, err = pcall(function()
		controllerInfo.instance:executeAction(player, actionName, table.unpack(args))
	end)

	if not success then
		return false, `Error executing controller command: {err}`
	end

	return true, `Executed {controllerName}:{actionName}`
end

--[[
	Shows help information for commands
	Format: /help [targetname]
]]
local function showHelp(player: Player, targetName: string?): (boolean, string)
	if not targetName then
		-- Show all available commands
		local helpText = "=== Available Slash Commands ===\n\n"

		-- List user models
		local userModelNames = {}
		for name, _ in userModels do
			table.insert(userModelNames, name)
		end
		table.sort(userModelNames)

		if #userModelNames > 0 then
			helpText ..= "USER MODELS (per-player state):\n"
			for _, name in userModelNames do
				helpText ..= `  /{name}\n`
			end
			helpText ..= "\n"
		end

		-- List server models
		local serverModelNames = {}
		for name, _ in serverModels do
			table.insert(serverModelNames, name)
		end
		table.sort(serverModelNames)

		if #serverModelNames > 0 then
			helpText ..= "SERVER MODELS (global state):\n"
			for _, name in serverModelNames do
				helpText ..= `  /{name}\n`
			end
			helpText ..= "\n"
		end

		-- List controllers
		local controllerNames = {}
		for name, _ in controllers do
			table.insert(controllerNames, name)
		end
		table.sort(controllerNames)

		if #controllerNames > 0 then
			helpText ..= "CONTROLLERS:\n"
			for _, name in controllerNames do
				helpText ..= `  /{name}\n`
			end
			helpText ..= "\n"
		end

		helpText ..= "SPECIAL COMMANDS:\n"
		helpText ..= "  /help [command] - Show this help or details for a command\n"
		helpText ..= "  /state [model] - Show model state (all models or specific)\n"
		helpText ..= "\n"
		helpText ..= "Usage: /<command> <method> [args...] - Execute a command"

		return true, helpText
	else
		-- Show details for specific command
		local target = targetName:lower()

		-- Check if it's a model (user or server)
		local modelClass = userModels[target] or serverModels[target]
		if modelClass then
			local isUserModel = userModels[target] ~= nil
			local scope = isUserModel and "USER" or "SERVER"

			-- Get model instance to introspect methods
			local modelInstance
			if isUserModel then
				modelInstance = modelClass.get(tostring(player.UserId))
			else
				modelInstance = modelClass.get("SERVER")
			end

			if not modelInstance then
				return false, `Could not get instance of {targetName}`
			end

			-- Discover public methods from the metatable
			local methods = {}
			local metatable = getmetatable(modelInstance)
			if metatable then
				for key, value in pairs(metatable) do
					-- Filter out private methods, special metatable keys, static methods, and non-functions
					if type(value) == "function"
						and not key:match("^_")
						and not key:match("^__")
						and key ~= "new"
						and key ~= "get"
						and key ~= "remove" then
						table.insert(methods, key)
					end
				end
			end
			table.sort(methods)

			local helpText = `=== /{target} ({scope} MODEL) ===\n\n`

			if #methods > 0 then
				helpText ..= "Available methods:\n"
				for _, method in methods do
					helpText ..= `  /{target} {method} [args...]\n`
				end
			else
				helpText ..= "No public methods available.\n"
			end

			return true, helpText
		end

		-- Check if it's a controller
		local controllerInfo = controllers[target]
		if controllerInfo then
			local actions = {}

			-- Parse controller name to match IntentActions key
			-- e.g., "BazaarController" → "Bazaar", "CashMachineController" → "CashMachine"
			local controllerKey = controllerInfo.originalName:gsub("Controller$", "")

			-- Get actions from IntentActions module
			local actionsTable = IntentActions[controllerKey]
			if actionsTable then
				for _, actionName in pairs(actionsTable) do
					table.insert(actions, actionName)
				end
			end

			local helpText = `=== /{target} (CONTROLLER) ===\n\n`

			if #actions > 0 then
				table.sort(actions)
				helpText ..= "Available actions:\n"
				for _, action in actions do
					helpText ..= `  /{target} {action} [args...]\n`
				end
			else
				helpText ..= "Actions not documented.\n"
				helpText ..= "See IntentActions module for available actions.\n"
			end

			return true, helpText
		end

		return false, `Command '{targetName}' not found`
	end
end

--[[
	Shows state information for models
	Format: /state [modelname]
]]
local function queryModelState(player: Player, modelName: string?): (boolean, string)
	if not modelName then
		-- Show all model state (user and server)
		local output = "=== Model State Summary ===\n\n"

		-- Collect user models
		local userModelNames = {}
		for name, _ in userModels do
			table.insert(userModelNames, name)
		end
		table.sort(userModelNames)

		-- Show user model states
		if #userModelNames > 0 then
			for _, name in userModelNames do
				local modelClass = userModels[name]
				local modelInstance = modelClass.get(tostring(player.UserId))

				output ..= `--- {name:upper()} (USER) ---\n`

				if modelInstance then
					-- Introspect properties
					local properties = {}
					for key, value in pairs(modelInstance) do
						-- Filter out internal fields and functions
						if not key:match("^_")
							and key ~= "ownerId"
							and key ~= "remoteEvent"
							and type(value) ~= "function" then
							properties[key] = value
						end
					end

					-- Sort and display
					local sortedKeys = {}
					for key, _ in pairs(properties) do
						table.insert(sortedKeys, key)
					end
					table.sort(sortedKeys)

					if #sortedKeys > 0 then
						for _, key in sortedKeys do
							output ..= `  {key}: {tostring(properties[key])}\n`
						end
					else
						output ..= "  (no properties)\n"
					end
				else
					output ..= "  (instance not found)\n"
				end

				output ..= "\n"
			end
		end

		-- Collect server models
		local serverModelNames = {}
		for name, _ in serverModels do
			table.insert(serverModelNames, name)
		end
		table.sort(serverModelNames)

		-- Show server model states
		if #serverModelNames > 0 then
			for _, name in serverModelNames do
				local modelClass = serverModels[name]
				local modelInstance = modelClass.get("SERVER")

				output ..= `--- {name:upper()} (SERVER) ---\n`

				if modelInstance then
					-- Introspect properties
					local properties = {}
					for key, value in pairs(modelInstance) do
						-- Filter out internal fields and functions
						if not key:match("^_")
							and key ~= "ownerId"
							and key ~= "remoteEvent"
							and type(value) ~= "function" then
							properties[key] = value
						end
					end

					-- Sort and display
					local sortedKeys = {}
					for key, _ in pairs(properties) do
						table.insert(sortedKeys, key)
					end
					table.sort(sortedKeys)

					if #sortedKeys > 0 then
						for _, key in sortedKeys do
							output ..= `  {key}: {tostring(properties[key])}\n`
						end
					else
						output ..= "  (no properties)\n"
					end
				else
					output ..= "  (instance not found)\n"
				end

				output ..= "\n"
			end
		end

		if #userModelNames == 0 and #serverModelNames == 0 then
			output ..= "No models registered.\n"
		end

		return true, output
	else
		-- Query specific model
		local target = modelName:lower()
		local modelClass = userModels[target] or serverModels[target]

		if not modelClass then
			return false, `Model '{modelName}' not found`
		end

		local isServerModel = serverModels[target] ~= nil
		local scope = isServerModel and "SERVER" or "USER"

		-- Get model instance
		local modelInstance
		if isServerModel then
			modelInstance = modelClass.get("SERVER")
		else
			modelInstance = modelClass.get(tostring(player.UserId))
		end

		if not modelInstance then
			return false, `Could not get instance of {modelName}`
		end

		-- Introspect properties
		local properties = {}
		for key, value in pairs(modelInstance) do
			-- Filter out internal fields and functions
			if not key:match("^_")
				and key ~= "ownerId"
				and key ~= "remoteEvent"
				and type(value) ~= "function" then
				properties[key] = value
			end
		end

		-- Build output
		local output = `=== {target:upper()} ({scope}) ===\n\n`

		local sortedKeys = {}
		for key, _ in pairs(properties) do
			table.insert(sortedKeys, key)
		end
		table.sort(sortedKeys)

		if #sortedKeys > 0 then
			for _, key in sortedKeys do
				output ..= `{key}: {tostring(properties[key])}\n`
			end
		else
			output ..= "(no properties)\n"
		end

		return true, output
	end
end

--[[
	Handles command execution from client
	Format: commandString = "targetname methodname args..."
]]
local function handleCommand(player: Player, commandString: string): ()
	-- Check permissions
	if not hasPermission(player) then
		warn(`[SlashCommand] Player {player.Name} attempted to use slash command without permission (rank: {player:GetRankInGroup(groupId or 0)})`)
		return
	end

	-- Parse command string
	local parts = string.split(commandString, " ")

	if #parts < 1 then
		warn(`[SlashCommand] Invalid command format from {player.Name}: {commandString}`)
		return
	end

	local targetName = parts[1]

	-- Handle /help command specially
	if targetName:lower() == "help" then
		local helpTarget = parts[2] -- May be nil
		local success, message = showHelp(player, helpTarget)
		sendChatMessage(player, message)
		print(`[SlashCommand] {player.Name} used /help` .. (helpTarget and ` {helpTarget}` or ""))
		return
	end

	-- Handle /state command specially
	if targetName:lower() == "state" then
		local modelTarget = parts[2] -- May be nil (show all models)
		local success, message = queryModelState(player, modelTarget)
		sendChatMessage(player, message)
		print(`[SlashCommand] {player.Name} used /state` .. (modelTarget and ` {modelTarget}` or ""))
		return
	end

	-- All other commands require at least 2 parts (target + method/action)
	if #parts < 2 then
		sendChatMessage(player, "Invalid command format. Usage: /<command> <method> [args...]")
		warn(`[SlashCommand] Invalid command format from {player.Name}: {commandString}`)
		return
	end

	local methodName = parts[2]
	local argString = string.sub(commandString, #targetName + #methodName + 3) -- +3 for two spaces and 1-index
	local args = parseArguments(argString)

	-- Route to controller or model based on name
	local success, message
	if targetName:lower():match("controller$") then
		-- Controller command
		success, message = executeControllerCommand(player, targetName, methodName, args)
	else
		-- Model command
		success, message = executeModelCommand(player, targetName, methodName, args)
	end

	-- Send feedback to player
	sendChatMessage(player, message)
	if not success then
		warn(`[SlashCommand] FAILED - {player.Name}: {message}`)
	else
		print(`[SlashCommand] SUCCESS - {player.Name}: {message}`)
	end
end

--[[
	Registers all models discovered by ModelRunner
]]
function SlashCommandService:registerModels(modelList: { { class: any, name: string, scope: string } }): ()
	for _, modelInfo in modelList do
		local name = modelInfo.name
		local modelClass = modelInfo.class
		local scope = modelInfo.scope

		if scope == "User" then
			userModels[name:lower()] = modelClass
		elseif scope == "Server" then
			serverModels[name:lower()] = modelClass
		end
	end
end

--[[
	Registers all controllers discovered by ControllerRunner
]]
function SlashCommandService:registerControllers(controllerList: { { name: string, instance: any } }): ()
	for _, controllerInfo in controllerList do
		local name = controllerInfo.name
		local instance = controllerInfo.instance

		-- Store controller instance, RemoteEvent, and original name for IntentActions lookup
		controllers[name:lower()] = {
			instance = instance,
			remoteEvent = instance.remoteEvent,
			originalName = name,
		}
	end
end

--[[
	Creates TextChatCommands for autocomplete and help
	Called after models and controllers are registered
]]
function SlashCommandService:createTextChatCommands(): ()
	local textCommands = TextChatService:WaitForChild("TextChatCommands")

	-- Create /help command
	local helpCommand = Instance.new("TextChatCommand")
	helpCommand.Name = "help"
	helpCommand.PrimaryAlias = "/help"
	helpCommand.Parent = textCommands

	-- Create /state command
	local stateCommand = Instance.new("TextChatCommand")
	stateCommand.Name = "state"
	stateCommand.PrimaryAlias = "/state"
	stateCommand.Parent = textCommands

	-- Create a command for each user-scoped model
	for modelName, _ in userModels do
		local command = Instance.new("TextChatCommand")
		command.Name = `model_{modelName}`
		command.PrimaryAlias = `/{modelName:lower()}`
		command.Parent = textCommands
	end

	-- Create a command for each server-scoped model
	for modelName, _ in serverModels do
		local command = Instance.new("TextChatCommand")
		command.Name = `servermodel_{modelName}`
		command.PrimaryAlias = `/{modelName:lower()}`
		command.Parent = textCommands
	end

	-- Create a command for each controller
	for controllerName, _ in controllers do
		local command = Instance.new("TextChatCommand")
		command.Name = `controller_{controllerName}`
		command.PrimaryAlias = `/{controllerName:lower()}`
		command.Parent = textCommands
	end
end

--[[
	Initializes the service
	Creates RemoteEvent for client-server communication
]]
function SlashCommandService:init(): ()
	-- Determine if game is owned by a group
	if game.CreatorType == Enum.CreatorType.Group then
		groupId = game.CreatorId
	end

	-- Create RemoteEvent for commands (follows Intent pattern)
	local eventsFolder = ReplicatedStorage:WaitForChild("Events")
	commandRemote = Instance.new("RemoteEvent")
	commandRemote.Name = "SlashCommandIntent"
	commandRemote.Parent = eventsFolder

	-- Create RemoteEvent for state changes (follows StateChanged pattern)
	messageRemote = Instance.new("RemoteEvent")
	messageRemote.Name = "SlashCommandStateChanged"
	messageRemote.Parent = eventsFolder

	-- Listen for command events
	commandRemote.OnServerEvent:Connect(function(player: Player, commandString: string)
		handleCommand(player, commandString)
	end)
end

return SlashCommandService
