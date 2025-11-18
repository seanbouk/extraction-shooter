--!strict

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PersistenceServer = {}

-- Configuration
local BASE_TOKENS = 50 -- Base tokens available (safety margin from 60)
local TOKENS_PER_PLAYER = 8 -- Additional tokens per player in the game
local TOKEN_REGENERATION_RATE = 1 -- Tokens per second
local MINIMUM_WAIT_BETWEEN_WRITES = 0.1 -- Wait even when tokens available
local QUEUE_WARNING_THRESHOLD = 100 -- Warn if queue gets too large

-- Types
type WriteRequest = {
	modelName: string,
	ownerId: string,
	data: { [string]: any },
	timestamp: number,
}

-- State
local dataStore: DataStore = nil
local writeQueue: { WriteRequest } = {}
local currentMaxTokens = BASE_TOKENS
local currentTokens = BASE_TOKENS
local lastTokenRegenTime = 0
local isProcessing = false

-- Helper function to serialize model data
local function serializeModelData(modelInstance: any): { [string]: any }
	local serialized = {}

	for key, value in pairs(modelInstance) do
		-- Skip functions, RemoteEvent references, and internal metadata (fields starting with _)
		local valueType = type(value)
		if valueType ~= "function" and valueType ~= "userdata" and key ~= "remoteEvent" and not key:match("^_") then
			serialized[key] = value
		end
	end

	return serialized
end

-- Update max tokens based on current player count
local function updateMaxTokens()
	local playerCount = #Players:GetPlayers()
	local newMax = BASE_TOKENS + (TOKENS_PER_PLAYER * playerCount)

	currentMaxTokens = newMax

	-- If current tokens exceed new max, cap them
	if currentTokens > currentMaxTokens then
		currentTokens = currentMaxTokens
	end

	print(
		string.format(
			"[PersistenceServer] Max tokens updated: %d (base: %d + %d players × %d)",
			currentMaxTokens,
			BASE_TOKENS,
			playerCount,
			TOKENS_PER_PLAYER
		)
	)
end

-- Regenerate tokens based on elapsed time
local function regenerateTokens()
	local currentTime = os.clock()
	local elapsedTime = currentTime - lastTokenRegenTime

	if elapsedTime >= 1 then
		local tokensToAdd = math.floor(elapsedTime / TOKEN_REGENERATION_RATE)
		currentTokens = math.min(currentMaxTokens, currentTokens + tokensToAdd)
		lastTokenRegenTime = currentTime
	end
end

-- Process a single write from the queue
local function processWrite(request: WriteRequest): boolean
	local key = request.modelName .. "_" .. request.ownerId

	-- Attempt to write to DataStore
	local success, err = pcall(function()
		dataStore:SetAsync(key, request.data)
	end)

	if success then
		print(
			string.format(
				"[PersistenceServer] ✓ Successfully wrote %s for owner %s",
				request.modelName,
				request.ownerId
			)
		)
		return true
	else
		warn(string.format("[PersistenceServer] ✗ Failed to write %s for owner %s: %s", request.modelName, request.ownerId, tostring(err)))
		return false
	end
end

-- Background loop to process the write queue
local function startQueueProcessor()
	if isProcessing then
		return
	end

	isProcessing = true

	task.spawn(function()
		while true do
			regenerateTokens()

			-- Check if we have work to do
			if #writeQueue > 0 then
				-- Warn if queue is getting large
				if #writeQueue > QUEUE_WARNING_THRESHOLD then
					warn(
						string.format(
							"[PersistenceServer] Queue is large (%d items). Consider optimizing write frequency.",
							#writeQueue
						)
					)
				end

				-- Check if we have tokens available
				if currentTokens > 0 then
					-- Remove the first item from the queue
					local request = table.remove(writeQueue, 1)

					-- Consume a token
					currentTokens = currentTokens - 1

					-- Process the write
					processWrite(request)

					-- Wait a bit even when we have tokens
					task.wait(MINIMUM_WAIT_BETWEEN_WRITES)
				else
					-- No tokens available, wait 1 second
					task.wait(1)
				end
			else
				-- No work to do, wait a bit before checking again
				task.wait(0.5)
			end
		end
	end)
end

-- Initialize the PersistenceServer
function PersistenceServer.init()
	-- Only initialize in non-Studio environments or in Studio if testing
	if RunService:IsStudio() then
		warn("[PersistenceServer] Running in Studio - DataStore operations may be limited")
	end

	-- Get or create the DataStore
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerData")
	end)

	if success then
		dataStore = result
		print("[PersistenceServer] Initialized successfully")
	else
		warn("[PersistenceServer] Failed to initialize DataStore: " .. tostring(result))
		warn("[PersistenceServer] Make sure Studio Access to API Services is enabled")
		-- Create a dummy dataStore to prevent errors
		dataStore = {
			SetAsync = function()
				warn("[PersistenceServer] Dummy SetAsync called - DataStore not available")
			end,
			GetAsync = function()
				warn("[PersistenceServer] Dummy GetAsync called - DataStore not available")
				return nil -- Simulate new player with no saved data
			end,
		} :: any
	end

	-- Initialize token regeneration timer
	lastTokenRegenTime = os.clock()

	-- Set up player tracking for dynamic max tokens
	updateMaxTokens() -- Initial calculation

	Players.PlayerAdded:Connect(function(player)
		updateMaxTokens()
	end)

	Players.PlayerRemoving:Connect(function(player)
		updateMaxTokens()
	end)

	-- Handle server shutdown to flush all pending writes
	game:BindToClose(function()
		-- Skip in Studio to avoid blocking offline testing
		if RunService:IsStudio() then
			print("[PersistenceServer] BindToClose skipped in Studio")
			return
		end

		print("[PersistenceServer] Server shutting down - flushing all pending writes")
		PersistenceServer:flushAllWrites()
	end)

	-- Start the background processor
	startQueueProcessor()
end

-- Load a model's data from DataStore
-- Returns (success: boolean, data: any?)
-- - New player: (true, nil) - Success, no data found
-- - Existing player: (true, data) - Success with loaded data
-- - Load failed: (false, nil) - Failure, should kick player
function PersistenceServer:loadModel(modelName: string, ownerId: string): (boolean, { [string]: any }?)
	local key = modelName .. "_" .. ownerId

	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)

	if success then
		if result then
			print(
				string.format(
					"[PersistenceServer] ✓ Loaded %s for owner %s",
					modelName,
					ownerId
				)
			)
			return true, result
		else
			-- No data found (new player)
			print(
				string.format(
					"[PersistenceServer] No saved data for %s (owner: %s) - using defaults",
					modelName,
					ownerId
				)
			)
			return true, nil
		end
	else
		-- Load failed
		warn(
			string.format(
				"[PersistenceServer] ✗ Failed to load %s for owner %s: %s",
				modelName,
				ownerId,
				tostring(result)
			)
		)
		return false, nil
	end
end

-- Queue a write request
function PersistenceServer:queueWrite(modelName: string, ownerId: string, modelInstance: any)
	-- Serialize the model data
	local serializedData = serializeModelData(modelInstance)

	-- Create the write request
	local request: WriteRequest = {
		modelName = modelName,
		ownerId = ownerId,
		data = serializedData,
		timestamp = os.clock(),
	}

	-- Add to queue
	table.insert(writeQueue, request)

	-- Debug output
	print(
		string.format(
			"[PersistenceServer] Queued write for %s (owner: %s) - Queue size: %d, Tokens: %d",
			modelName,
			ownerId,
			#writeQueue,
			currentTokens
		)
	)
end

-- Flush all pending writes for a specific player
-- Used when a player is leaving to ensure their data is saved
function PersistenceServer:flushPlayerWrites(ownerId: string)
	print(string.format("[PersistenceServer] Flushing writes for owner %s", ownerId))

	local flushedCount = 0
	local i = 1

	-- Process all queued writes for this player
	while i <= #writeQueue do
		local request = writeQueue[i]

		if request.ownerId == ownerId then
			-- Remove from queue
			table.remove(writeQueue, i)

			-- Process immediately (skip token limiting for critical saves)
			processWrite(request)
			flushedCount = flushedCount + 1

			-- Don't increment i since we removed an element
		else
			i = i + 1
		end
	end

	print(string.format("[PersistenceServer] Flushed %d write(s) for owner %s", flushedCount, ownerId))
end

-- Flush all pending writes
-- Used during server shutdown to ensure no data is lost
function PersistenceServer:flushAllWrites()
	local queueSize = #writeQueue
	print(string.format("[PersistenceServer] Flushing all writes (%d items in queue)", queueSize))

	local startTime = os.clock()
	local successCount = 0
	local failCount = 0

	-- Process all queued writes
	while #writeQueue > 0 do
		local request = table.remove(writeQueue, 1)

		-- Process immediately (skip token limiting for critical saves)
		local success = processWrite(request)

		if success then
			successCount = successCount + 1
		else
			failCount = failCount + 1
		end

		-- Check if we're running out of time (BindToClose has 30 second limit)
		local elapsedTime = os.clock() - startTime
		if elapsedTime > 28 then
			warn(string.format("[PersistenceServer] Approaching BindToClose timeout! %d items remaining", #writeQueue))
			break
		end
	end

	local totalTime = os.clock() - startTime
	print(
		string.format(
			"[PersistenceServer] Flush complete: %d succeeded, %d failed, %.2fs elapsed",
			successCount,
			failCount,
			totalTime
		)
	)
end

-- Get queue stats (useful for debugging)
function PersistenceServer:getStats(): { queueSize: number, availableTokens: number, maxTokens: number }
	regenerateTokens()
	return {
		queueSize = #writeQueue,
		availableTokens = currentTokens,
		maxTokens = currentMaxTokens,
	}
end

return PersistenceServer
