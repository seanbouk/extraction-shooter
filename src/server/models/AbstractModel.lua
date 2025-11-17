--!strict

local AbstractModel = {}
AbstractModel.__index = AbstractModel

-- Registry to store model instances per owner
local instances: { [string]: AbstractModel } = {}

export type AbstractModel = typeof(setmetatable({} :: {
	ownerId: string,
}, AbstractModel))

function AbstractModel.new(ownerId: string): AbstractModel
	local self = setmetatable({}, AbstractModel) :: any
	self.ownerId = ownerId
	return self
end

-- Get or create a model instance for the given owner
function AbstractModel.get(ownerId: string): AbstractModel
	if instances[ownerId] == nil then
		instances[ownerId] = AbstractModel.new(ownerId)
	end
	return instances[ownerId]
end

-- Remove a model instance for the given owner (cleanup)
function AbstractModel.remove(ownerId: string): ()
	instances[ownerId] = nil
end

function AbstractModel:fire(): ()
	print("=== Firing " .. tostring(self) .. " ===")
	for key, value in pairs(self) do
		print(tostring(key) .. ": " .. tostring(value))
	end
end

return AbstractModel
