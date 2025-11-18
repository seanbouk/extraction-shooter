--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local ShrineModel = {}
ShrineModel.__index = ShrineModel
setmetatable(ShrineModel, AbstractModel)

export type ShrineModel = typeof(setmetatable({} :: {
	treasure: number,
	userID: string,
}, ShrineModel)) & AbstractModel.AbstractModel

-- Registry to store shrine instances (should only ever have one with ownerId "SERVER")
local instances: { [string]: ShrineModel } = {}

function ShrineModel.new(ownerId: string): ShrineModel
	local self = AbstractModel.new("ShrineModel", ownerId, "Server") :: any
	setmetatable(self, ShrineModel)

	self.treasure = 0
	self.userID = ""

	return self :: ShrineModel
end

function ShrineModel.get(ownerId: string): ShrineModel
	if instances[ownerId] == nil then
		instances[ownerId] = ShrineModel.new(ownerId)
	end
	return instances[ownerId]
end

function ShrineModel.remove(ownerId: string): ()
	instances[ownerId] = nil
end

function ShrineModel:donate(playerUserId: string, amount: number): ()
	self.treasure += amount
	self.userID = playerUserId
	self:fire("all") -- Broadcast to all players
end

return ShrineModel
