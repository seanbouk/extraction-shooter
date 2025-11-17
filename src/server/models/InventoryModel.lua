--!strict

local AbstractModel = require(script.Parent.AbstractModel)

local InventoryModel = {}
InventoryModel.__index = InventoryModel
setmetatable(InventoryModel, AbstractModel)

export type InventoryModel = typeof(setmetatable({} :: {
	gold: number,
	treasure: number,
}, InventoryModel)) & AbstractModel.AbstractModel

local instance: InventoryModel? = nil

function InventoryModel.get(): InventoryModel
	if instance == nil then
		local self = AbstractModel.new() :: any
		setmetatable(self, InventoryModel)

		self.gold = 0
		self.treasure = 0

		instance = self
	end

	return instance :: InventoryModel
end

function InventoryModel:addGold(amount: number): ()
	self.gold += amount
end

return InventoryModel
