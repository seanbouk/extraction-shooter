--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local CandlesModel = {}
CandlesModel.__index = CandlesModel
setmetatable(CandlesModel, AbstractModel)

export type CandlesModel = typeof(setmetatable({} :: {
	creator: string,
	positionX: number,
	positionY: number,
	positionZ: number,
	createdTime: number,
}, CandlesModel)) & AbstractModel.AbstractModel

function CandlesModel.new(entityId: string): CandlesModel
	local self = AbstractModel.new("CandlesModel", "SERVER", "ServerEntity", entityId) :: any
	setmetatable(self, CandlesModel)

	self.creator = ""
	self.positionX = 0
	self.positionY = 0
	self.positionZ = 0
	self.createdTime = 0

	return self :: CandlesModel
end

function CandlesModel.get(entityId: string): CandlesModel
	return AbstractModel.getOrCreate("CandlesModel", "SERVER", function()
		return CandlesModel.new(entityId)
	end, entityId) :: CandlesModel
end

function CandlesModel.remove(entityId: string): ()
	AbstractModel.removeServerEntity("CandlesModel", entityId)
end

-- Create a new candle with all properties set
function CandlesModel.create(entityId: string, creator: string, positionX: number, positionY: number, positionZ: number): CandlesModel
	local candle = CandlesModel.get(entityId)
	candle.creator = creator
	candle.positionX = positionX
	candle.positionY = positionY
	candle.positionZ = positionZ
	candle.createdTime = os.time()
	candle:syncState()
	return candle
end

-- Get all active candles
function CandlesModel.getAll(): { [string]: CandlesModel }
	return AbstractModel.getAllServerEntities("CandlesModel") :: any
end

-- Required: Initialize server entities on startup
-- For dynamically-created candles, this starts empty
function CandlesModel.initAllServerEntities(): ()
	-- Candles are created dynamically via CandlesModel.create()
	-- No predefined entities to initialize
end

return CandlesModel
