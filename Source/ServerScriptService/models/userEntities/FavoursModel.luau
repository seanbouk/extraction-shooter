--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)
local PersistenceService = require(script.Parent.Parent.Parent.services.PersistenceService)

local FavoursModel = {}
FavoursModel.__index = FavoursModel
setmetatable(FavoursModel, AbstractModel)

export type FavoursModel = typeof(setmetatable({} :: {
	favourType: string,
}, FavoursModel)) & AbstractModel.AbstractModel

function FavoursModel.new(ownerId: string, modelId: string): FavoursModel
	local self = AbstractModel.new("FavoursModel", ownerId, "UserEntity", modelId) :: any
	setmetatable(self, FavoursModel)

	self.favourType = ""

	return self :: FavoursModel
end

function FavoursModel.get(ownerId: string, modelId: string): FavoursModel
	return AbstractModel.getOrCreate("FavoursModel", ownerId, function()
		return FavoursModel.new(ownerId, modelId)
	end, modelId) :: FavoursModel
end

function FavoursModel.remove(ownerId: string, modelId: string): ()
	AbstractModel.removeInstance("FavoursModel", ownerId, modelId)
end

-- REQUIRED: Load all favour entities for a player
function FavoursModel.loadAllForOwner(ownerId: string): boolean
	-- Get the InventoryModel to access favourIds list
	local InventoryModel = require(script.Parent.Parent.user.InventoryModel)
	local inventory = InventoryModel.get(ownerId)

	-- If favourIds doesn't exist, assume no favours yet
	local favourIds = (inventory :: any).favourIds or {}

	-- Load each favour from DataStore
	for _, favourId in favourIds do
		local success, loadedData = PersistenceService:loadModel("FavoursModel", ownerId, favourId)

		if not success then
			return false
		end

		local favour = FavoursModel.get(ownerId, favourId)

		if loadedData then
			favour:_applyLoadedData(loadedData)
		end

		favour:syncState(true)
	end

	return true
end

-- REQUIRED: Remove all favour entities for a player
function FavoursModel.removeAllEntitiesForOwner(ownerId: string): ()
	AbstractModel.removeAllEntitiesForOwner("FavoursModel", ownerId)
end

-- Method to set the favour type
function FavoursModel:setFavourType(favourType: string): ()
	self.favourType = favourType
	self:syncState()
end

return FavoursModel
