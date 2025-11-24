--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Initialize PersistenceServer before any models are used
local PersistenceServer = require(script.Parent.Parent.services.PersistenceServer)
PersistenceServer.init()

-- Auto-discover and require all models (skip Abstract)
local modelsFolder = script.Parent
local models = {}

type ModelClass = {
	get: (ownerId: string) -> any,
	remove: (ownerId: string) -> (),
}

type ModelScope = "User" | "Server"

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

-- Handle player initialization
Players.PlayerAdded:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Initializing models for player " .. player.Name)

	for _, modelInfo in modelInfos do
		-- Only initialize User-scoped models per player
		if modelInfo.scope == "User" then
			-- Load data from DataStore for this model
			local success, loadedData = PersistenceServer:loadModel(modelInfo.name, ownerId)

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

			-- Don't fire initial state here - client will request when ready
			-- This prevents race condition where RemoteEvent hasn't replicated yet
		end
	end
end)

-- Handle player cleanup
local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Cleaning up models for player " .. player.Name)

	-- Flush all pending writes for this player before cleanup
	PersistenceServer:flushPlayerWrites(ownerId)

	-- Only remove User-scoped models (Server-scoped persist for server lifetime)
	for _, modelInfo in modelInfos do
		if modelInfo.scope == "User" then
			modelInfo.class.remove(ownerId)
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
		PersistenceServer:flushPlayerWrites(ownerId)
	end
end)

print("ModelRunner: Initialized with " .. #models .. " model(s)")
