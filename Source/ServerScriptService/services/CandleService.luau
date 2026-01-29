--!strict

local CandlesModel = require(script.Parent.Parent.models.serverEntities.CandlesModel)

local CandleService = {}

local CANDLE_LIFETIME_SECONDS = 5
local CHECK_INTERVAL_SECONDS = 1

local isRunning = false

local function removeExpiredCandles(): ()
	local currentTime = os.time()
	local allCandles = CandlesModel.getAll()
	local candlesToRemove: { string } = {}

	for entityId, candle in allCandles do
		if currentTime - candle.createdTime >= CANDLE_LIFETIME_SECONDS then
			table.insert(candlesToRemove, entityId)
		end
	end

	for _, entityId in candlesToRemove do
		CandlesModel.remove(entityId)
	end

	if #candlesToRemove > 0 then
		CandlesModel.syncAll() -- Broadcast updated state to clients
	end
end

local function startCandleChecker()
	if isRunning then
		return
	end
	isRunning = true

	task.spawn(function()
		while true do
			removeExpiredCandles()
			task.wait(CHECK_INTERVAL_SECONDS)
		end
	end)
end

function CandleService.init()
	print("[CandleService] Initializing...")
	startCandleChecker()
end

return CandleService
