--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local SYNC_DEBOUNCE = 5
local SYNC_MAX_STALE = 15

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

function AmmoModel:_flushSync(): ()
	if self._syncThread then
		task.cancel(self._syncThread)
		self._syncThread = nil
	end
	if self._syncStaleThread then
		task.cancel(self._syncStaleThread)
		self._syncStaleThread = nil
	end
	self:syncState()
end

function AmmoModel:_debouncedSync(): ()
	self:syncState(true) -- replicate to client immediately, skip datastore
	if self._syncThread then
		task.cancel(self._syncThread)
	end
	self._syncThread = task.delay(SYNC_DEBOUNCE, function()
		self._syncThread = nil
		self:_flushSync()
	end)
	if not self._syncStaleThread then
		self._syncStaleThread = task.delay(SYNC_MAX_STALE, function()
			self._syncStaleThread = nil
			self:_flushSync()
		end)
	end
end

function AmmoModel:addAmmo(ammoType: AmmoType, amount: number): ()
	if ammoType == "pistol" then self.pistol += amount
	elseif ammoType == "shot" then self.shot += amount
	elseif ammoType == "laser" then self.laser += amount
	elseif ammoType == "auto" then self.auto += amount
	elseif ammoType == "canon" then self.canon += amount
	end
	self:_flushSync()
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
	if amount == 1 then
		self:_debouncedSync()
	else
		self:_flushSync()
	end
	return true
end

return AmmoModel
