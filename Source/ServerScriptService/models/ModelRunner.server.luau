--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Initialize PersistenceService before any models are used
local PersistenceService = require(script.Parent.Parent.services.PersistenceService)
PersistenceService.init()

-- Auto-discover and require all models (skip Abstract)
local modelsFolder = script.Parent
local models = {}

type ModelClass = {
	get: (ownerId: string) -> any,
	remove: (ownerId: string) -> (),
	initAllServerEntities: (() -> ())?,
}

type ModelScope = "User" | "Server" | "UserEntity" | "ServerEntity"

type ModelInfo = {
	class: ModelClass,
	name: string,
	scope: ModelScope,
}

local modelInfos: { ModelInfo } = {}

-- Helper function to discover models in a folder with a specific scope
local function discoverModelsInFolder(folder: Instance, scope: ModelScope)
	for _, moduleScript in folder:GetChildren() do
		if moduleScript:IsA("ModuleScript") and not moduleScript.Name:find("^Abstract") then
			local model = require(moduleScript) :: ModelClass
			table.insert(models, model)
			table.insert(modelInfos, {
				class = model,
				name = moduleScript.Name,
				scope = scope,
			})
			print("ModelRunner: Discovered " .. scope .. "-scoped model - " .. moduleScript.Name)
		end
	end
end

-- Discover User-scoped models
local userFolder = modelsFolder:FindFirstChild("user")
if userFolder then
	discoverModelsInFolder(userFolder, "User")
end

-- Discover Server-scoped models
local serverFolder = modelsFolder:FindFirstChild("server")
if serverFolder then
	discoverModelsInFolder(serverFolder, "Server")
end

-- Discover UserEntity-scoped models
local userEntitiesFolder = modelsFolder:FindFirstChild("userEntities")
if userEntitiesFolder then
	discoverModelsInFolder(userEntitiesFolder, "UserEntity")
end

-- Discover ServerEntity-scoped models
local serverEntitiesFolder = modelsFolder:FindFirstChild("serverEntities")
if serverEntitiesFolder then
	discoverModelsInFolder(serverEntitiesFolder, "ServerEntity")
end

-- Register models with SlashCommandService and initialize it
local SlashCommandService = require(script.Parent.Parent.services.SlashCommandService)
SlashCommandService:init()
SlashCommandService:registerModels(modelInfos)
SlashCommandService:createTextChatCommands()

-- Initialize Server-scoped models once (ephemeral, shared by all players)
print("ModelRunner: Initializing Server-scoped models")
for _, modelInfo in modelInfos do
	if modelInfo.scope == "Server" then
		-- Initialize with ownerId "SERVER" (no persistence)
		local instance = modelInfo.class.get("SERVER")
		print("ModelRunner: Initialized Server-scoped model - " .. modelInfo.name)
	end
end

-- Initialize ServerEntity-scoped models (ephemeral, multiple instances, shared by all players)
print("ModelRunner: Initializing ServerEntity-scoped models")
for _, modelInfo in modelInfos do
	if modelInfo.scope == "ServerEntity" then
		-- ServerEntity models need to implement initAllServerEntities() to define their entity IDs
		if modelInfo.class.initAllServerEntities then
			modelInfo.class.initAllServerEntities()
			print("ModelRunner: Initialized ServerEntity-scoped model - " .. modelInfo.name)
		else
			warn("ServerEntity model " .. modelInfo.name .. " missing initAllServerEntities method")
		end
	end
end

-- Initialize game services that depend on models
local CandleService = require(script.Parent.Parent.services.CandleService)
CandleService.init()

-- Handle player initialization
Players.PlayerAdded:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Initializing models for player " .. player.Name)

	for _, modelInfo in modelInfos do
		-- Only initialize User-scoped models per player
		if modelInfo.scope == "User" then
			-- Load data from DataStore for this model
			local success, loadedData = PersistenceService:loadModel(modelInfo.name, ownerId)

			-- If load failed, kick the player to prevent data loss
			if not success then
				player:Kick("Roblox servers are busy right now. Please rejoin to try again. Your progress is safe!")
				return -- Stop processing this player
			end

			-- Get or create model instance for this player (with defaults)
			local instance = modelInfo.class.get(ownerId)

			-- Apply loaded data if it exists (overwrites defaults)
			if loadedData then
				instance:_applyLoadedData(loadedData)
			end

			-- Sync initial state to client (skipPersistence=true since we just loaded)
			-- This ensures Bolt RemoteProperty has correct value when client calls Observe()
			instance:syncState(true)

		-- Initialize UserEntity-scoped models per player
		elseif modelInfo.scope == "UserEntity" then
			-- UserEntity models need custom initialization per model type
			-- They should implement a static loadAllForOwner method
			if modelInfo.class.loadAllForOwner then
				local success = modelInfo.class.loadAllForOwner(ownerId)

				if not success then
					player:Kick("Roblox servers are busy right now. Please rejoin to try again. Your progress is safe!")
					return
				end
			else
				warn("UserEntity model " .. modelInfo.name .. " missing loadAllForOwner method")
			end
		end
	end
end)

-- Handle player cleanup
local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Cleaning up models for player " .. player.Name)

	-- Flush all pending writes for this player before cleanup
	PersistenceService:flushPlayerWrites(ownerId)

	-- Remove User and UserEntity scoped models (Server-scoped persist for server lifetime)
	for _, modelInfo in modelInfos do
		if modelInfo.scope == "User" then
			modelInfo.class.remove(ownerId)
		elseif modelInfo.scope == "UserEntity" then
			-- Clean up all user entities for this owner
			if modelInfo.class.removeAllEntitiesForOwner then
				modelInfo.class.removeAllEntitiesForOwner(ownerId)
			end
		end
	end
end)

-- Handle server shutdown as backup to ensure all data is saved
game:BindToClose(function()
	-- Skip in Studio to avoid blocking offline testing
	if RunService:IsStudio() then
		print("[ModelRunner] BindToClose skipped in Studio")
		return
	end

	print("[ModelRunner] Server shutting down - disconnecting PlayerRemoving and flushing all players")

	-- Disconnect PlayerRemoving to prevent duplicate saves during shutdown
	playerRemovingConnection:Disconnect()

	-- Flush all remaining player data
	for _, player in Players:GetPlayers() do
		local ownerId = tostring(player.UserId)
		PersistenceService:flushPlayerWrites(ownerId)
	end
end)

print("ModelRunner: Initialized with " .. #models .. " model(s)")
