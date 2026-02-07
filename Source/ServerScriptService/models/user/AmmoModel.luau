--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local AmmoModel = {}
AmmoModel.__index = AmmoModel
setmetatable(AmmoModel, AbstractModel)

export type AmmoType = "pistol" | "shot" | "laser" | "auto" | "canon"

export type AmmoModel = typeof(setmetatable({} :: {
	pistol: number,
	shot: number,
	laser: number,
	auto: number,
	canon: number,
}, AmmoModel)) & AbstractModel.AbstractModel

function AmmoModel.new(ownerId: string): AmmoModel
	local self = AbstractModel.new("AmmoModel", ownerId, "User") :: any
	setmetatable(self, AmmoModel)

	self.pistol = 100
	self.shot = 1
	self.laser = 1
	self.auto = 20
	self.canon = 1

	return self :: AmmoModel
end

function AmmoModel.get(ownerId: string): AmmoModel
	return AbstractModel.getOrCreate("AmmoModel", ownerId, function()
		return AmmoModel.new(ownerId)
	end) :: AmmoModel
end

function AmmoModel.remove(ownerId: string): ()
	AbstractModel.removeInstance("AmmoModel", ownerId)
end

function AmmoModel:getAmmo(ammoType: AmmoType): number
	if ammoType == "pistol" then return self.pistol
	elseif ammoType == "shot" then return self.shot
	elseif ammoType == "laser" then return self.laser
	elseif ammoType == "auto" then return self.auto
	elseif ammoType == "canon" then return self.canon
	end
	return 0
end

function AmmoModel:addAmmo(ammoType: AmmoType, amount: number): ()
	if ammoType == "pistol" then self.pistol += amount
	elseif ammoType == "shot" then self.shot += amount
	elseif ammoType == "laser" then self.laser += amount
	elseif ammoType == "auto" then self.auto += amount
	elseif ammoType == "canon" then self.canon += amount
	end
	self:syncState()
end

function AmmoModel:spendAmmo(ammoType: AmmoType, amount: number): boolean
	local current = self:getAmmo(ammoType)
	if current < amount then
		return false
	end

	if ammoType == "pistol" then self.pistol -= amount
	elseif ammoType == "shot" then self.shot -= amount
	elseif ammoType == "laser" then self.laser -= amount
	elseif ammoType == "auto" then self.auto -= amount
	elseif ammoType == "canon" then self.canon -= amount
	end
	self:syncState()
	return true
end

return AmmoModel
