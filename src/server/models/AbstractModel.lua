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

function AbstractModel:fire(scope: "owner" | "all"): ()
	-- Validate scope parameter
	if scope ~= "owner" and scope ~= "all" then
		error("fire() scope must be 'owner' or 'all', got: " .. tostring(scope))
	end

	-- Queue persistence write
	PersistenceManager:queueWrite(self._modelName, self.ownerId, self)

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
