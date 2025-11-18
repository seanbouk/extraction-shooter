--!strict

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local PersistenceManager = {}

-- Configuration
local MAX_BUDGET_TOKENS = 50 -- Max tokens available (safety margin from 60)
local TOKEN_REGENERATION_RATE = 1 -- Tokens per second
local MINIMUM_WAIT_BETWEEN_WRITES = 0.1 -- Wait even when tokens available
local QUEUE_WARNING_THRESHOLD = 100 -- Warn if queue gets too large
local LOAD_RETRY_ATTEMPTS = 3 -- Number of retry attempts for loading
local LOAD_RETRY_DELAYS = { 0.5, 1, 2 } -- Exponential backoff delays (seconds)

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
local currentTokens = MAX_BUDGET_TOKENS
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

-- Regenerate tokens based on elapsed time
local function regenerateTokens()
	local currentTime = os.clock()
	local elapsedTime = currentTime - lastTokenRegenTime

	if elapsedTime >= 1 then
		local tokensToAdd = math.floor(elapsedTime / TOKEN_REGENERATION_RATE)
		currentTokens = math.min(MAX_BUDGET_TOKENS, currentTokens + tokensToAdd)
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
				"[PersistenceManager] ✓ Successfully wrote %s for owner %s",
				request.modelName,
				request.ownerId
			)
		)
		return true
	else
		warn(string.format("[PersistenceManager] ✗ Failed to write %s for owner %s: %s", request.modelName, request.ownerId, tostring(err)))
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
							"[PersistenceManager] Queue is large (%d items). Consider optimizing write frequency.",
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

-- Initialize the PersistenceManager
function PersistenceManager.init()
	-- Only initialize in non-Studio environments or in Studio if testing
	if RunService:IsStudio() then
		warn("[PersistenceManager] Running in Studio - DataStore operations may be limited")
	end

	-- Get or create the DataStore
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("PlayerData")
	end)

	if success then
		dataStore = result
		print("[PersistenceManager] Initialized successfully")
	else
		warn("[PersistenceManager] Failed to initialize DataStore: " .. tostring(result))
		warn("[PersistenceManager] Make sure Studio Access to API Services is enabled")
		-- Create a dummy dataStore to prevent errors
		dataStore = {
			SetAsync = function()
				warn("[PersistenceManager] Dummy SetAsync called - DataStore not available")
			end,
			GetAsync = function()
				warn("[PersistenceManager] Dummy GetAsync called - DataStore not available")
				return nil -- Simulate new player with no saved data
			end,
		} :: any
	end

	-- Initialize token regeneration timer
	lastTokenRegenTime = os.clock()

	-- Start the background processor
	startQueueProcessor()
end

-- Load a model's data from DataStore with retry logic
function PersistenceManager:loadModel(modelName: string, ownerId: string): { [string]: any }?
	local key = modelName .. "_" .. ownerId

	-- Try loading with retry logic
	for attempt = 1, LOAD_RETRY_ATTEMPTS do
		local success, result = pcall(function()
			return dataStore:GetAsync(key)
		end)

		if success then
			if result then
				print(
					string.format(
						"[PersistenceManager] ✓ Loaded %s for owner %s",
						modelName,
						ownerId
					)
				)
				return result
			else
				-- No data found (new player)
				print(
					string.format(
						"[PersistenceManager] No saved data for %s (owner: %s) - using defaults",
						modelName,
						ownerId
					)
				)
				return nil
			end
		else
			-- Load failed
			if attempt < LOAD_RETRY_ATTEMPTS then
				local delay = LOAD_RETRY_DELAYS[attempt]
				warn(
					string.format(
						"[PersistenceManager] Failed to load %s for owner %s (attempt %d/%d): %s - retrying in %.1fs",
						modelName,
						ownerId,
						attempt,
						LOAD_RETRY_ATTEMPTS,
						tostring(result),
						delay
					)
				)
				task.wait(delay)
			else
				-- Final attempt failed
				warn(
					string.format(
						"[PersistenceManager] ✗ Failed to load %s for owner %s after %d attempts: %s - using defaults",
						modelName,
						ownerId,
						LOAD_RETRY_ATTEMPTS,
						tostring(result)
					)
				)
				return nil
			end
		end
	end

	return nil
end

-- Queue a write request
function PersistenceManager:queueWrite(modelName: string, ownerId: string, modelInstance: any)
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
			"[PersistenceManager] Queued write for %s (owner: %s) - Queue size: %d, Tokens: %d",
			modelName,
			ownerId,
			#writeQueue,
			currentTokens
		)
	)
end

-- Get queue stats (useful for debugging)
function PersistenceManager:getStats(): { queueSize: number, availableTokens: number }
	regenerateTokens()
	return {
		queueSize = #writeQueue,
		availableTokens = currentTokens,
	}
end

return PersistenceManager
