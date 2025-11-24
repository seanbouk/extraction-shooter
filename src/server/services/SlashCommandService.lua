--!strict

--[[
	SlashCommandService

	Automatically discovers and registers slash commands from models.
	Uses pure convention-based approach:
	- /modelname methodname args... → Executes model method

	Requirements:
	- User must have rank 200+ to use commands
	- Commands are auto-discovered at server startup
	- Zero configuration needed in existing models

	Note: Controller support is commented out pending controller refactoring
	to expose ACTIONS tables and standardize handler signatures.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local SlashCommandService = {}

-- Minimum rank required to use slash commands
local MIN_RANK = 200

-- Registered models
local userModels: { [string]: any } = {}
local serverModels: { [string]: any } = {}

-- RemoteEvent for command execution
local commandRemote: RemoteEvent = nil

-- Group ID (determined at runtime)
local groupId: number? = nil

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
	Handles command execution from client
	Format: commandString = "targetname methodname args..."
]]
local function handleCommand(player: Player, commandString: string): ()
	print(`[SlashCommand] Received command from {player.Name}: "{commandString}"`)

	-- Check permissions
	if not hasPermission(player) then
		warn(`[SlashCommand] Player {player.Name} attempted to use slash command without permission (rank: {player:GetRankInGroup(groupId or 0)})`)
		return
	end

	print(`[SlashCommand] Permission check passed for {player.Name}`)

	-- Parse command string
	local parts = string.split(commandString, " ")
	print(`[SlashCommand] Parsed {#parts} parts from command`)

	if #parts < 2 then
		warn(`[SlashCommand] Invalid command format from {player.Name}: {commandString}`)
		return
	end

	local targetName = parts[1]
	local methodName = parts[2]
	local argString = string.sub(commandString, #targetName + #methodName + 3) -- +3 for two spaces and 1-index
	local args = parseArguments(argString)

	print(`[SlashCommand] Target: {targetName}, Method: {methodName}, Args: {#args}`)

	-- Execute model command
	local success, message = executeModelCommand(player, targetName, methodName, args)

	-- Send feedback to player
	if success then
		print(`[SlashCommand] SUCCESS - {player.Name}: {message}`)
	else
		warn(`[SlashCommand] FAILED - {player.Name}: {message}`)
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
			print(`[SlashCommandService] Registered user model: {name}`)
		elseif scope == "Server" then
			serverModels[name:lower()] = modelClass
			print(`[SlashCommandService] Registered server model: {name}`)
		end
	end

	local totalModels = #modelList
	print(`[SlashCommandService] Total models registered: {totalModels}`)
end

--[[
	Creates TextChatCommands for autocomplete and help
	Called after models are registered
]]
function SlashCommandService:createTextChatCommands(): ()
	local textCommands = TextChatService:WaitForChild("TextChatCommands")

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

	print("[SlashCommandService] TextChatCommands created")
end

--[[
	Initializes the service
	Creates RemoteEvent for client-server communication
]]
function SlashCommandService:init(): ()
	-- Determine if game is owned by a group
	if game.CreatorType == Enum.CreatorType.Group then
		groupId = game.CreatorId
		print(`[SlashCommandService] Game owned by group {groupId}. Rank {MIN_RANK}+ required.`)
	else
		print(`[SlashCommandService] Game owned by user {game.CreatorId}. All players allowed.`)
	end

	-- Create RemoteEvent for commands
	local eventsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
	commandRemote = Instance.new("RemoteEvent")
	commandRemote.Name = "SlashCommand"
	commandRemote.Parent = eventsFolder

	-- Listen for command events
	commandRemote.OnServerEvent:Connect(function(player: Player, commandString: string)
		handleCommand(player, commandString)
	end)

	print("[SlashCommandService] Initialized")
end

return SlashCommandService
