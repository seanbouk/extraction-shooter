--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local ProgressModel = {}
ProgressModel.__index = ProgressModel
setmetatable(ProgressModel, AbstractModel)

export type ProgressModel = typeof(setmetatable({} :: {
	progress: number,
}, ProgressModel)) & AbstractModel.AbstractModel

function ProgressModel.new(ownerId: string): ProgressModel
	local self = AbstractModel.new("ProgressModel", ownerId, "User") :: any
	setmetatable(self, ProgressModel)

	self.progress = 0

	return self :: ProgressModel
end

function ProgressModel.get(ownerId: string): ProgressModel
	return AbstractModel.getOrCreate("ProgressModel", ownerId, function()
		return ProgressModel.new(ownerId)
	end) :: ProgressModel
end

function ProgressModel.remove(ownerId: string): ()
	AbstractModel.removeInstance("ProgressModel", ownerId)
end

function ProgressModel:increment(): ()
	self.progress += 1
	self:syncState()
end

function ProgressModel:reset(): ()
	self.progress = 0
	self:syncState()
end

return ProgressModel
