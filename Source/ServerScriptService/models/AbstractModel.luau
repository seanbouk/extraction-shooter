--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PersistenceService = require(script.Parent.Parent.services.framework.PersistenceService)
local Network = require(ReplicatedStorage.Network)

local AbstractModel = {}
AbstractModel.__index = AbstractModel

local registries: { [string]: { [string]: AbstractModel } } = {}

type ModelScope = "User" | "Server" | "UserEntity" | "ServerEntity"

export type AbstractModel = typeof(setmetatable({} :: {
	ownerId: string,
	modelId: string?,
	_modelName: string,
	_scope: ModelScope,
	_syncScope: ("owner" | "all")?,
	_stateProperty: any,
}, AbstractModel))

function AbstractModel.new(modelName: string, ownerId: string, scope: ModelScope, modelId: string?, syncScope: ("owner" | "all")?): AbstractModel
	local self = setmetatable({}, AbstractModel) :: any
	self.ownerId = ownerId
	self.modelId = modelId
	self._modelName = modelName
	self._scope = scope
	self._syncScope = syncScope

	-- Validate UserEntity and ServerEntity scopes have modelId
	if (scope == "UserEntity" or scope == "ServerEntity") and not modelId then
		error(scope .. "-scoped models require a modelId parameter")
	end

	-- Validate User/Server scopes don't have modelId
	if (scope == "User" or scope == "Server") and modelId then
		error("User and Server-scoped models cannot have a modelId parameter")
	end

	-- Validate ServerEntity scope uses "SERVER" as ownerId
	if scope == "ServerEntity" and ownerId ~= "SERVER" then
		error("ServerEntity-scoped models must use 'SERVER' as ownerId")
	end

	-- Register Bolt RemoteProperty for state synchronization
	local propertyName = modelName:gsub("Model$", "")
	self._stateProperty = Network.registerState(propertyName)

	return self
end

function AbstractModel.get(ownerId: string): AbstractModel
	error("AbstractModel.get() should not be called directly. Use a concrete model class instead.")
end

function AbstractModel.getOrCreate(modelName: string, ownerId: string, constructorFn: () -> AbstractModel, modelId: string?): AbstractModel
	if not registries[modelName] then
		registries[modelName] = {}
	end

	-- Create composite key for UserEntity scope
	local registryKey = if modelId then ownerId .. "_" .. modelId else ownerId

	if registries[modelName][registryKey] then
		return registries[modelName][registryKey]
	end

	local instance = constructorFn()

	registries[modelName][registryKey] = instance

	return instance
end

function AbstractModel.removeInstance(modelName: string, ownerId: string, modelId: string?): ()
	if registries[modelName] then
		local registryKey = if modelId then ownerId .. "_" .. modelId else ownerId
		registries[modelName][registryKey] = nil
	end
end

-- Remove all user entity instances for a given owner (for UserEntity scope cleanup)
function AbstractModel.removeAllEntitiesForOwner(modelName: string, ownerId: string): ()
	if not registries[modelName] then
		return
	end

	local ownerPrefix = ownerId .. "_"
	local keysToRemove = {}

	for registryKey in registries[modelName] do
		if registryKey:sub(1, #ownerPrefix) == ownerPrefix then
			table.insert(keysToRemove, registryKey)
		end
	end

	for _, key in keysToRemove do
		registries[modelName][key] = nil
	end
end

-- Get all active instances for a model (useful for debugging/admin)
function AbstractModel.getAllInstances(modelName: string): { [string]: AbstractModel }
	return registries[modelName] or {}
end

-- Remove a specific ServerEntity instance (for cleanup)
function AbstractModel.removeServerEntity(modelName: string, entityId: string): ()
	AbstractModel.removeInstance(modelName, "SERVER", entityId)
end

-- Get all ServerEntity instances for a model
function AbstractModel.getAllServerEntities(modelName: string): { [string]: AbstractModel }
	local registry = registries[modelName]
	if not registry then
		return {}
	end

	local serverPrefix = "SERVER_"
	local entities: { [string]: AbstractModel } = {}

	for registryKey, instance in registry do
		if registryKey:sub(1, #serverPrefix) == serverPrefix then
			local entityId = registryKey:sub(#serverPrefix + 1)
			entities[entityId] = instance
		end
	end

	return entities
end

function AbstractModel:_extractState()
	local state = {}
	for key, value in pairs(self) do
		-- Include only public fields (no leading underscore, no functions)
		if not key:match("^_") and type(value) ~= "function" then
			state[key] = value
		end
	end
	return state
end

function AbstractModel:_applyLoadedData(loadedData: { [string]: any }?): ()
	if not loadedData then
		return
	end

	for key, value in pairs(loadedData) do
		if not key:match("^_") and type(value) ~= "function" then
			self[key] = value
		end
	end
end

-- Aggregate and sync all UserEntity states for an owner
local function syncAllEntitiesForOwner(modelName: string, ownerId: string, stateProperty: any): ()
	local registry = registries[modelName]
	if not registry then
		return
	end

	local ownerPrefix = ownerId .. "_"
	local aggregatedStates: { [string]: any } = {}

	-- Collect all entity states for this owner
	for registryKey, instance in registry do
		if registryKey:sub(1, #ownerPrefix) == ownerPrefix then
			local modelId = registryKey:sub(#ownerPrefix + 1)
			aggregatedStates[modelId] = (instance :: any):_extractState()
		end
	end

	-- Sync the aggregated dictionary to the owner
	local userId = tonumber(ownerId)
	if userId then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			stateProperty:SetFor(player, aggregatedStates)
		end
	end
end

-- Aggregate and sync all ServerEntity states to all players
local function syncAllServerEntities(modelName: string, stateProperty: any): ()
	local registry = registries[modelName]
	if not registry then
		return
	end

	local serverPrefix = "SERVER_"
	local aggregatedStates: { [string]: any } = {}

	-- Collect all server entity states
	for registryKey, instance in registry do
		if registryKey:sub(1, #serverPrefix) == serverPrefix then
			local entityId = registryKey:sub(#serverPrefix + 1)
			aggregatedStates[entityId] = (instance :: any):_extractState()
		end
	end

	-- Broadcast the aggregated dictionary to all players
	stateProperty:Set(aggregatedStates)
end

function AbstractModel:syncState(skipPersistence: boolean?): ()
	-- Queue persistence for User and UserEntity scoped models (not Server or ServerEntity)
	if not skipPersistence and (self._scope == "User" or self._scope == "UserEntity") then
		PersistenceService:queueWrite(self._modelName, self.ownerId, self, self.modelId)
	end

	-- Determine sync scope (can be overridden with _syncScope)
	local syncScope = self._syncScope or (self._scope == "Server" and "all" or "owner")

	if self._scope == "UserEntity" then
		-- UserEntity: Aggregate all entities for owner and sync as dictionary
		syncAllEntitiesForOwner(self._modelName, self.ownerId, self._stateProperty)
	elseif self._scope == "ServerEntity" then
		-- ServerEntity: Aggregate all server entities and broadcast to all players (no persistence)
		syncAllServerEntities(self._modelName, self._stateProperty)
	elseif syncScope == "owner" then
		-- User scoped models: Send only to owner
		local state = self:_extractState()
		local userId = tonumber(self.ownerId)
		if userId then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				self._stateProperty:SetFor(player, state)  -- Bolt per-player sync
			else
				warn("Could not find player with UserId: " .. tostring(self.ownerId))
			end
		end
	elseif syncScope == "all" then
		-- Server-scoped models (or override): Broadcast to all
		local state = self:_extractState()
		self._stateProperty:Set(state)  -- Bolt global sync
	end
end

return AbstractModel
