--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local ShrineModel = {}
ShrineModel.__index = ShrineModel
setmetatable(ShrineModel, AbstractModel)

export type ShrineModel = typeof(setmetatable({} :: {
	treasure: number,
	userId: string,
}, ShrineModel)) & AbstractModel.AbstractModel

function ShrineModel.new(ownerId: string): ShrineModel
	local self = AbstractModel.new("ShrineModel", ownerId, "Server") :: any
	setmetatable(self, ShrineModel)

	self.treasure = 0
	self.userId = ""

	return self :: ShrineModel
end

function ShrineModel.get(ownerId: string): ShrineModel
	return AbstractModel.getOrCreate("ShrineModel", ownerId, function()
		return ShrineModel.new(ownerId)
	end) :: ShrineModel
end

function ShrineModel.remove(ownerId: string): ()
	AbstractModel.removeInstance("ShrineModel", ownerId)
end

function ShrineModel:donate(playerUserId: string, amount: number): ()
	self.treasure += amount
	self.userId = playerUserId
	self:fire("all") -- Broadcast to all players
end

return ShrineModel
