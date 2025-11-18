--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PersistenceManager = require(script.Parent.Parent.services.PersistenceManager)

local AbstractModel = {}
AbstractModel.__index = AbstractModel

-- Registry to store model instances per owner
local instances: { [string]: AbstractModel } = {}

-- Store the RemoteEvent for this model type (one per model class)
local remoteEvent: RemoteEvent? = nil

export type AbstractModel = typeof(setmetatable({} :: {
	ownerId: string,
	remoteEvent: RemoteEvent,
	_modelName: string,
}, AbstractModel))

function AbstractModel.new(modelName: string, ownerId: string): AbstractModel
	local self = setmetatable({}, AbstractModel) :: any
	self.ownerId = ownerId
	self._modelName = modelName

	-- Create RemoteEvent if it doesn't exist (only on first instance)
	if remoteEvent == nil then
		-- Derive event name by removing "Model" suffix and adding "StateChanged"
		local eventName = modelName:gsub("Model$", "") .. "StateChanged"

		-- Ensure Shared/Events folder exists in ReplicatedStorage
		local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
		local eventsFolder = sharedFolder:FindFirstChild("Events")
		if not eventsFolder then
			eventsFolder = Instance.new("Folder")
			eventsFolder.Name = "Events"
			eventsFolder.Parent = sharedFolder
		end

		-- Create or get RemoteEvent
		local event = eventsFolder:FindFirstChild(eventName)
		if not event then
			event = Instance.new("RemoteEvent")
			event.Name = eventName
			event.Parent = eventsFolder
		end

		remoteEvent = event :: RemoteEvent

		-- Set up handler for client-ready signals (only once per model class)
		remoteEvent.OnServerEvent:Connect(function(player: Player)
			-- Client is signaling it's ready to receive initial state
			local ownerId = tostring(player.UserId)

			-- Get the model class from the modelName
			-- We need to look it up in the concrete model's registry
			-- This is called from AbstractModel, so we delegate to the concrete implementation
			local modelModule = script.Parent:FindFirstChild(modelName)
			if modelModule then
				local success, model = pcall(require, modelModule)
				if success and model.get then
					local instance = model.get(ownerId)
					if instance then
						-- Send current state to this player (skip persistence)
						instance:fire("owner", true)
						print(
							string.format(
								"[AbstractModel] Client ready - sent initial state for %s to player %s",
								modelName,
								player.Name
							)
						)
					end
				end
			end
		end)
	end

	self.remoteEvent = remoteEvent :: RemoteEvent

	return self
end

-- Get or create a model instance for the given owner
function AbstractModel.get(ownerId: string): AbstractModel
	error("AbstractModel.get() should not be called directly. Use a concrete model class instead.")
end

-- Remove a model instance for the given owner (cleanup)
function AbstractModel.remove(ownerId: string): ()
	instances[ownerId] = nil
end

-- Apply loaded data to the model instance (private method called by ModelRunner)
function AbstractModel:_applyLoadedData(loadedData: { [string]: any }?): ()
	if not loadedData then
		return
	end

	-- Apply each field from loaded data to the model instance
	for key, value in pairs(loadedData) do
		-- Skip internal metadata fields and methods
		if not key:match("^_") and type(value) ~= "function" then
			self[key] = value
		end
	end

	print(
		string.format(
			"[AbstractModel] Applied loaded data to %s (owner: %s)",
			self._modelName,
			self.ownerId
		)
	)
end

function AbstractModel:fire(scope: "owner" | "all", skipPersistence: boolean?): ()
	-- Validate scope parameter
	if scope ~= "owner" and scope ~= "all" then
		error("fire() scope must be 'owner' or 'all', got: " .. tostring(scope))
	end

	-- Queue persistence write (unless explicitly skipped)
	if not skipPersistence then
		PersistenceManager:queueWrite(self._modelName, self.ownerId, self)
	end

	print("=== Firing " .. tostring(self) .. " (scope: " .. scope .. ") ===")
	for key, value in pairs(self) do
		print(tostring(key) .. ": " .. tostring(value))
	end

	-- Broadcast based on scope
	if scope == "owner" then
		-- Send to owning player only (if it's a valid UserId)
		local userId = tonumber(self.ownerId)
		if userId then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				self.remoteEvent:FireClient(player, self)
			else
				warn("Could not find player with UserId: " .. tostring(self.ownerId))
			end
		else
			-- Not a valid UserId (probably a test), skip broadcasting
			print("Skipping broadcast - ownerId is not a valid UserId: " .. tostring(self.ownerId))
		end
	elseif scope == "all" then
		-- Send to all players
		self.remoteEvent:FireAllClients(self)
	end
end

return AbstractModel
