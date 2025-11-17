--!strict

local AbstractModel = {}
AbstractModel.__index = AbstractModel

export type AbstractModel = typeof(setmetatable({} :: {}, AbstractModel))

function AbstractModel.new(): AbstractModel
	local self = setmetatable({}, AbstractModel)
	return self
end

function AbstractModel:fire(): ()
	print("=== Firing " .. tostring(self) .. " ===")
	for key, value in pairs(self) do
		print(tostring(key) .. ": " .. tostring(value))
	end
end

return AbstractModel
