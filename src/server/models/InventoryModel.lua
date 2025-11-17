--!strict

local AbstractModel = require(script.Parent.AbstractModel)

local InventoryModel = {}
InventoryModel.__index = InventoryModel
setmetatable(InventoryModel, AbstractModel)

export type InventoryModel = typeof(setmetatable({} :: {
	gold: number,
	treasure: number,
}, InventoryModel)) & AbstractModel.AbstractModel

-- Registry to store inventory instances per owner
local instances: { [string]: InventoryModel } = {}

function InventoryModel.new(ownerId: string): InventoryModel
	local self = AbstractModel.new("InventoryModel", ownerId) :: any
	setmetatable(self, InventoryModel)

	self.gold = 0
	self.treasure = 0

	return self :: InventoryModel
end

function InventoryModel.get(ownerId: string): InventoryModel
	if instances[ownerId] == nil then
		instances[ownerId] = InventoryModel.new(ownerId)
	end
	return instances[ownerId]
end

function InventoryModel.remove(ownerId: string): ()
	instances[ownerId] = nil
end

function InventoryModel:addGold(amount: number): ()
	self.gold += amount
	self:fire("owner")
end

return InventoryModel
