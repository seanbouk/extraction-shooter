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
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Network = require(ReplicatedStorage.Network)
local AbstractModel = require(ServerScriptService.models.AbstractModel)

local SlashCommandService = {}

local MIN_RANK = 200
-- Maximum message length for slash command responses
-- Bolt supports up to 32KB strings, but we set a reasonable limit
local MAX_MESSAGE_LENGTH = 30000 -- ~30KB, well under Bolt's 32,767 byte maximum

local userModels: { [string]: any } = {}
local serverModels: { [string]: any } = {}
local userEntityModels: { [string]: { class: any, modelName: string } } = {}
local controllers: { [string]: { instance: any, remoteEvent: RemoteEvent, originalName: string } } = {}

local commandRemote: RemoteEvent = nil
local messageRemote: RemoteEvent = nil
local groupId: number? = nil

local function sendChatMessage(player: Player, message: string): ()
	if not messageRemote then
		warn("[SlashCommandService] Cannot send chat message - messageRemote not initialized")
		return
	end

	-- Truncate if message exceeds maximum length
	if #message > MAX_MESSAGE_LENGTH then
		message = string.sub(message, 1, MAX_MESSAGE_LENGTH) .. "\n...(truncated)"
		warn(`[SlashCommandService] Message truncated for {player.Name} (exceeded {MAX_MESSAGE_LENGTH} bytes)`)
	end

	Network.State.SlashCommand:SetFor(player, { message = message })
end

local function hasPermission(player: Player): boolean
	if groupId then
		return player:GetRankInGroup(groupId) >= MIN_RANK
	end

	warn(`[SlashCommandService] Game is not owned by a group. Allowing all players to use commands.`)
	return true
end

local function parseArguments(argString: string): { any }
	local args = {}

	for arg in string.gmatch(argString, "%S+") do
		local num = tonumber(arg)
		if num then
			table.insert(args, num)
			continue
		end

		if arg == "true" then
			table.insert(args, true)
			continue
		elseif arg == "false" then
			table.insert(args, false)
			continue
		end

		table.insert(args, arg)
	end

	return args
end

local function executeModelCommand(player: Player, modelName: string, methodName: string, args: { any }): (boolean, string)
	local modelClass = userModels[modelName:lower()]
	local isServerModel = false

	if not modelClass then
		modelClass = serverModels[modelName:lower()]
		isServerModel = true
	end

	if not modelClass then
		return false, `Model '{modelName}' not found`
	end

	local modelInstance
	if isServerModel then
		modelInstance = modelClass.get("SERVER")
	else
		modelInstance = modelClass.get(tostring(player.UserId))
	end

	if not modelInstance then
		return false, `Could not get instance of {modelName}`
	end

	if type(modelInstance[methodName]) ~= "function" then
		return false, `Method '{methodName}' not found in {modelName}`
	end

	local success, err = pcall(function()
		modelInstance[methodName](modelInstance, table.unpack(args))
	end)

	if not success then
		return false, `Error executing method: {err}`
	end

	return true, `Executed {modelName}:{methodName}`
end

local function executeControllerCommand(player: Player, controllerName: string, actionName: string, args: { any }): (boolean, string)
	local controllerInfo = controllers[controllerName:lower()]

	if not controllerInfo then
		return false, `Controller '{controllerName}' not found`
	end

	local success, err = pcall(function()
		controllerInfo.instance:executeAction(player, actionName, table.unpack(args))
	end)

	if not success then
		return false, `Error executing controller command: {err}`
	end

	return true, `Executed {controllerName}:{actionName}`
end

local function showHelp(player: Player, targetName: string?): (boolean, string)
	if not targetName then
		local helpText = "=== Available Slash Commands ===\n\n"

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

		local userEntityModelNames = {}
		for name, _ in userEntityModels do
			table.insert(userEntityModelNames, name)
		end
		table.sort(userEntityModelNames)

		if #userEntityModelNames > 0 then
			helpText ..= "USER ENTITY MODELS (multiple per player):\n"
			for _, name in userEntityModelNames do
				helpText ..= `  /{name}\n`
			end
			helpText ..= "\n"
		end

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
		helpText ..= "  /commands [command] - Show all commands or details for specific command\n"
		helpText ..= "  /state [model] - Show state for all models or specific model\n"
		helpText ..= "\n"
		helpText ..= "Usage: /<command> <method> [args...] - Execute a command"

		return true, helpText
	else
		local target = targetName:lower()

		local modelClass = userModels[target] or serverModels[target]
		if not modelClass then
			local userEntityInfo = userEntityModels[target]
			if userEntityInfo then
				modelClass = userEntityInfo.class
			end
		end

		if modelClass then
			local isUserModel = userModels[target] ~= nil
			local userEntityInfo = userEntityModels[target]
			local isUserEntityModel = userEntityInfo ~= nil
			local scope = isUserModel and "USER" or (isUserEntityModel and "USER ENTITY" or "SERVER")

			local modelInstance
			if isUserModel then
				modelInstance = modelClass.get(tostring(player.UserId))
			elseif isUserEntityModel then
				-- For UserEntity models, get any instance to show available methods
				local instances = AbstractModel.getAllInstances(userEntityInfo.modelName)
				local prefix = tostring(player.UserId) .. "_"
				for registryKey, instance in pairs(instances) do
					if registryKey:sub(1, #prefix) == prefix then
						modelInstance = instance
						break
					end
				end

				if not modelInstance then
					-- If no instances exist, still show what methods would be available
					-- by using the class's metatable
					return true, `=== /{target} (USER ENTITY MODEL) ===\n\nNo instances exist. Create an instance first to see available methods.`
				end
			else
				modelInstance = modelClass.get("SERVER")
			end

			if not modelInstance then
				return false, `Could not get instance of {targetName}`
			end

			local methods = {}
			local metatable = getmetatable(modelInstance)
			if metatable then
				for key, value in pairs(metatable) do
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

		local controllerInfo = controllers[target]
		if controllerInfo then
			local actions = {}

			local controllerKey = controllerInfo.originalName:gsub("Controller$", "")

			local actionsTable = Network.Actions[controllerKey]
			if actionsTable then
				for actionName, _ in pairs(actionsTable) do
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
				helpText ..= "See Network.Actions module for available actions.\n"
			end

			return true, helpText
		end

		return false, `Command '{targetName}' not found`
	end
end

-- Format a value for display (handles tables, strings, numbers, etc.)
local function formatValue(value: any, maxLength: number?): string
	local maxLen = maxLength or 200 -- Default cap at 200 characters

	local valueType = type(value)

	if valueType == "table" then
		-- Check if it's an array (sequential numeric keys)
		local isArray = true
		local arrayLength = 0
		for k, v in pairs(value) do
			if type(k) ~= "number" or k ~= arrayLength + 1 then
				isArray = false
				break
			end
			arrayLength = arrayLength + 1
		end

		local result
		if isArray then
			-- Format as array: { "item1", "item2", "item3" }
			local items = {}
			for _, v in ipairs(value) do
				table.insert(items, formatValue(v, nil)) -- Recursive
			end
			result = "{ " .. table.concat(items, ", ") .. " }"
		else
			-- Format as dictionary: { key1: "value1", key2: "value2" }
			local items = {}
			for k, v in pairs(value) do
				table.insert(items, tostring(k) .. ": " .. formatValue(v, nil)) -- Recursive
			end
			result = "{ " .. table.concat(items, ", ") .. " }"
		end

		-- Truncate if too long
		if #result > maxLen then
			result = result:sub(1, maxLen - 3) .. "..."
		end
		return result
	elseif valueType == "string" then
		-- Wrap strings in quotes
		return '"' .. value .. '"'
	else
		-- Numbers, booleans, etc. - use tostring
		return tostring(value)
	end
end

local function queryModelState(player: Player, modelName: string?): (boolean, string)
	if not modelName then
		local output = "=== Model State Summary ===\n\n"

		local userModelNames = {}
		for name, _ in userModels do
			table.insert(userModelNames, name)
		end
		table.sort(userModelNames)

		if #userModelNames > 0 then
			for _, name in userModelNames do
				local modelClass = userModels[name]
				local modelInstance = modelClass.get(tostring(player.UserId))

				output ..= `--- {name:upper()} (USER) ---\n`

				if modelInstance then
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
							output ..= `  {key}: {formatValue(properties[key])}\n`
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

		local serverModelNames = {}
		for name, _ in serverModels do
			table.insert(serverModelNames, name)
		end
		table.sort(serverModelNames)

		if #serverModelNames > 0 then
			for _, name in serverModelNames do
				local modelClass = serverModels[name]
				local modelInstance = modelClass.get("SERVER")

				output ..= `--- {name:upper()} (SERVER) ---\n`

				if modelInstance then
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
							output ..= `  {key}: {formatValue(properties[key])}\n`
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

		-- Display UserEntity-scoped models
		local userEntityModelNames = {}
		for name, _ in userEntityModels do
			table.insert(userEntityModelNames, name)
		end
		table.sort(userEntityModelNames)

		if #userEntityModelNames > 0 then
			for _, name in userEntityModelNames do
				local modelInfo = userEntityModels[name]
				local instances = AbstractModel.getAllInstances(modelInfo.modelName)

				output ..= `--- {name:upper()} (USER ENTITY) ---\n`

				if instances and next(instances) then
					-- Display instances for requesting player only
					local prefix = tostring(player.UserId) .. "_"
					local playerInstances = {}
					for registryKey, instance in pairs(instances) do
						if registryKey:sub(1, #prefix) == prefix then
							table.insert(playerInstances, { key = registryKey, instance = instance })
						end
					end

					if #playerInstances > 0 then
						table.sort(playerInstances, function(a, b)
							return a.key < b.key
						end)

						for _, data in playerInstances do
							local modelId = data.key:match("_(.+)$")
							output ..= `\n  [Instance: {modelId}]\n`

							-- Extract and display properties
							local properties = {}
							for key, value in pairs(data.instance) do
								if not key:match("^_")
									and key ~= "ownerId"
									and key ~= "remoteEvent"
									and type(value) ~= "function" then
									properties[key] = value
								end
							end

							local sortedKeys = {}
							for key, _ in pairs(properties) do
								table.insert(sortedKeys, key)
							end
							table.sort(sortedKeys)

							for _, key in sortedKeys do
								output ..= `    {key}: {formatValue(properties[key])}\n`
							end
						end
					else
						output ..= "  (no instances for this player)\n"
					end
				else
					output ..= "  (no active instances)\n"
				end

				output ..= "\n"
			end
		end

		if #userModelNames == 0 and #serverModelNames == 0 and #userEntityModelNames == 0 then
			output ..= "No models registered.\n"
		end

		return true, output
	else
		local target = modelName:lower()

		-- Try to find model in User, Server, or UserEntity scopes
		local modelClass = userModels[target]
		local isServerModel = false
		local isUserEntityModel = false

		if not modelClass then
			modelClass = serverModels[target]
			isServerModel = true
		end

		if not modelClass then
			local userEntityInfo = userEntityModels[target]
			if userEntityInfo then
				modelClass = userEntityInfo.class
				isUserEntityModel = true
			end
		end

		if not modelClass then
			return false, `Model '{modelName}' not found`
		end

		-- Handle UserEntity models differently
		if isUserEntityModel then
			local userEntityInfo = userEntityModels[target]
			local instances = AbstractModel.getAllInstances(userEntityInfo.modelName)
			local output = `=== {target:upper()} (USER ENTITY) ===\n\n`

			if instances and next(instances) then
				-- Display instances for requesting player only
				local prefix = tostring(player.UserId) .. "_"
				local playerInstances = {}
				for registryKey, instance in pairs(instances) do
					if registryKey:sub(1, #prefix) == prefix then
						table.insert(playerInstances, { key = registryKey, instance = instance })
					end
				end

				if #playerInstances > 0 then
					table.sort(playerInstances, function(a, b)
						return a.key < b.key
					end)

					for _, data in playerInstances do
						local modelId = data.key:match("_(.+)$")
						output ..= `[Instance: {modelId}]\n`

						-- Extract and display properties
						local properties = {}
						for key, value in pairs(data.instance) do
							if not key:match("^_")
								and key ~= "ownerId"
								and key ~= "remoteEvent"
								and type(value) ~= "function" then
								properties[key] = value
							end
						end

						local sortedKeys = {}
						for key, _ in pairs(properties) do
							table.insert(sortedKeys, key)
						end
						table.sort(sortedKeys)

						for _, key in sortedKeys do
							output ..= `  {key}: {formatValue(properties[key])}\n`
						end

						output ..= "\n"
					end
				else
					output ..= "(no instances for this player)\n"
				end
			else
				output ..= "(no active instances)\n"
			end

			return true, output
		else
			-- Handle User or Server models
			local scope = isServerModel and "SERVER" or "USER"

			local modelInstance
			if isServerModel then
				modelInstance = modelClass.get("SERVER")
			else
				modelInstance = modelClass.get(tostring(player.UserId))
			end

			if not modelInstance then
				return false, `Could not get instance of {modelName}`
			end

			local properties = {}
			for key, value in pairs(modelInstance) do
				if not key:match("^_")
					and key ~= "ownerId"
					and key ~= "remoteEvent"
					and type(value) ~= "function" then
					properties[key] = value
				end
			end

			local output = `=== {target:upper()} ({scope}) ===\n\n`

			local sortedKeys = {}
			for key, _ in pairs(properties) do
				table.insert(sortedKeys, key)
			end
			table.sort(sortedKeys)

			if #sortedKeys > 0 then
				for _, key in sortedKeys do
					output ..= `{key}: {formatValue(properties[key])}\n`
				end
			else
				output ..= "(no properties)\n"
			end

			return true, output
		end
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

	-- Handle /commands command specially (renamed from /help to avoid conflict with Roblox built-in)
	if targetName:lower() == "commands" then
		local helpTarget = parts[2] -- May be nil
		local success, message = showHelp(player, helpTarget)
		sendChatMessage(player, message)
		print(`[SlashCommand] {player.Name} used /commands` .. (helpTarget and ` {helpTarget}` or ""))
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
		elseif scope == "UserEntity" then
			userEntityModels[name:lower()] = { class = modelClass, modelName = name }
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

	-- Create /commands command (renamed from /help to avoid conflict with Roblox built-in)
	local helpCommand = Instance.new("TextChatCommand")
	helpCommand.Name = "custom_commands"
	helpCommand.PrimaryAlias = "/commands"
	helpCommand.Parent = textCommands

	-- Create /state command
	local stateCommand = Instance.new("TextChatCommand")
	stateCommand.Name = "custom_state"
	stateCommand.PrimaryAlias = "/state"
	stateCommand.Parent = textCommands

	-- Create a command for each user-scoped model
	for modelName, _ in userModels do
		local command = Instance.new("TextChatCommand")
		command.Name = `custom_model_{modelName}`
		command.PrimaryAlias = `/{modelName:lower()}`
		command.Parent = textCommands
	end

	-- Create a command for each server-scoped model
	for modelName, _ in serverModels do
		local command = Instance.new("TextChatCommand")
		command.Name = `custom_servermodel_{modelName}`
		command.PrimaryAlias = `/{modelName:lower()}`
		command.Parent = textCommands
	end

	-- Create a command for each user-entity-scoped model
	for modelName, _ in userEntityModels do
		local command = Instance.new("TextChatCommand")
		command.Name = `custom_userentitymodel_{modelName}`
		command.PrimaryAlias = `/{modelName:lower()}`
		command.Parent = textCommands
	end

	-- Create a command for each controller
	for controllerName, _ in controllers do
		local command = Instance.new("TextChatCommand")
		command.Name = `custom_controller_{controllerName}`
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

	-- Use Bolt events for commands and messages
	commandRemote = Network.Intent.SlashCommand
	messageRemote = Network.State.SlashCommand

	-- Listen for command events
	commandRemote.OnServerEvent:Connect(function(player: Player, commandString: string)
		handleCommand(player, commandString)
	end)
end

return SlashCommandService
