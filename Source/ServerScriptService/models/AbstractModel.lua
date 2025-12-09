--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PersistenceService = require(script.Parent.Parent.services.PersistenceService)
local Network = require(ReplicatedStorage.Network)

local AbstractModel = {}
AbstractModel.__index = AbstractModel

local registries: { [string]: { [string]: AbstractModel } } = {}

type ModelScope = "User" | "Server" | "Entity"

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

	-- Validate Entity scope has modelId
	if scope == "Entity" and not modelId then
		error("Entity-scoped models require a modelId parameter")
	end

	-- Validate User/Server scopes don't have modelId
	if (scope == "User" or scope == "Server") and modelId then
		error("User and Server-scoped models cannot have a modelId parameter")
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

	-- Create composite key for Entity scope
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

-- Remove all entity instances for a given owner (for Entity scope cleanup)
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

function AbstractModel:syncState(skipPersistence: boolean?): ()
	-- Queue persistence for User and Entity scoped models
	if not skipPersistence and (self._scope == "User" or self._scope == "Entity") then
		PersistenceService:queueWrite(self._modelName, self.ownerId, self, self.modelId)
	end

	-- Extract current state
	local state = self:_extractState()

	-- Determine sync scope (can be overridden with _syncScope)
	local syncScope = self._syncScope or (self._scope == "Server" and "all" or "owner")

	if syncScope == "owner" then
		-- User and Entity scoped models (or override): Send only to owner
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
		self._stateProperty:Set(state)  -- Bolt global sync
	end
end

return AbstractModel
