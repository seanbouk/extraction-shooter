--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PersistenceService = require(script.Parent.Parent.services.PersistenceService)

local AbstractModel = {}
AbstractModel.__index = AbstractModel

local registries: { [string]: { [string]: AbstractModel } } = {}

local remoteEvents: { [string]: RemoteEvent } = {}

type ModelScope = "User" | "Server"

export type AbstractModel = typeof(setmetatable({} :: {
	ownerId: string,
	remoteEvent: RemoteEvent,
	_modelName: string,
	_scope: ModelScope,
}, AbstractModel))

function AbstractModel.new(modelName: string, ownerId: string, scope: ModelScope): AbstractModel
	local self = setmetatable({}, AbstractModel) :: any
	self.ownerId = ownerId
	self._modelName = modelName
	self._scope = scope

	if remoteEvents[modelName] == nil then
		local eventName = modelName:gsub("Model$", "") .. "StateChanged"

		local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
		if not eventsFolder then
			eventsFolder = Instance.new("Folder")
			eventsFolder.Name = "Events"
			eventsFolder.Parent = ReplicatedStorage
		end

		local event = eventsFolder:FindFirstChild(eventName)
		if not event then
			event = Instance.new("RemoteEvent")
			event.Name = eventName
			event.Parent = eventsFolder
		end

		remoteEvents[modelName] = event :: RemoteEvent

		remoteEvents[modelName].OnServerEvent:Connect(function(player: Player)
			local ownerId = tostring(player.UserId)

			local modelModule = script.Parent:FindFirstChild("user"):FindFirstChild(modelName)
				or script.Parent:FindFirstChild("server"):FindFirstChild(modelName)
			if modelModule then
				local success, model = pcall(require, modelModule)
				if success and model.get then
					local instance = model.get(ownerId)
					if instance then
						instance:fire("owner", true)
					end
				end
			end
		end)
	end

	self.remoteEvent = remoteEvents[modelName] :: RemoteEvent

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

function AbstractModel:fire(scope: "owner" | "all", skipPersistence: boolean?): ()
	if scope ~= "owner" and scope ~= "all" then
		error("fire() scope must be 'owner' or 'all', got: " .. tostring(scope))
	end

	if not skipPersistence and self._scope ~= "Server" then
		PersistenceService:queueWrite(self._modelName, self.ownerId, self)
	end

	if scope == "owner" then
		local userId = tonumber(self.ownerId)
		if userId then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				self.remoteEvent:FireClient(player, self)
			else
				warn("Could not find player with UserId: " .. tostring(self.ownerId))
			end
		end
	elseif scope == "all" then
		self.remoteEvent:FireAllClients(self)
	end
end

return AbstractModel
