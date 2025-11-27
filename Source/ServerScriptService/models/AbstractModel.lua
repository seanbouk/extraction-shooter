--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PersistenceService = require(script.Parent.Parent.services.PersistenceService)
local Network = require(ReplicatedStorage.Network)

local AbstractModel = {}
AbstractModel.__index = AbstractModel

local registries: { [string]: { [string]: AbstractModel } } = {}

type ModelScope = "User" | "Server"

export type AbstractModel = typeof(setmetatable({} :: {
	ownerId: string,
	_modelName: string,
	_scope: ModelScope,
	_stateProperty: any,
}, AbstractModel))

function AbstractModel.new(modelName: string, ownerId: string, scope: ModelScope): AbstractModel
	local self = setmetatable({}, AbstractModel) :: any
	self.ownerId = ownerId
	self._modelName = modelName
	self._scope = scope

	-- Register Bolt RemoteProperty for state synchronization
	local propertyName = modelName:gsub("Model$", "")
	self._stateProperty = Network.registerState(propertyName)

	return self
end

function AbstractModel.get(ownerId: string): AbstractModel
	error("AbstractModel.get() should not be called directly. Use a concrete model class instead.")
end

function AbstractModel.getOrCreate(modelName: string, ownerId: string, constructorFn: () -> AbstractModel): AbstractModel
	if not registries[modelName] then
		registries[modelName] = {}
	end

	if registries[modelName][ownerId] then
		return registries[modelName][ownerId]
	end

	local instance = constructorFn()

	registries[modelName][ownerId] = instance

	return instance
end

function AbstractModel.removeInstance(modelName: string, ownerId: string): ()
	if registries[modelName] then
		registries[modelName][ownerId] = nil
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
	-- Queue persistence for User-scoped models
	if not skipPersistence and self._scope == "User" then
		PersistenceService:queueWrite(self._modelName, self.ownerId, self)
	end

	-- Extract current state
	local state = self:_extractState()

	-- Automatic scope detection based on model scope type
	if self._scope == "User" then
		-- User-scoped models: Send only to owner
		local userId = tonumber(self.ownerId)
		if userId then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				self._stateProperty:SetFor(player, state)  -- Bolt per-player sync
			else
				warn("Could not find player with UserId: " .. tostring(self.ownerId))
			end
		end
	elseif self._scope == "Server" then
		-- Server-scoped models: Broadcast to all
		self._stateProperty:Set(state)  -- Bolt global sync
	end
end

return AbstractModel
