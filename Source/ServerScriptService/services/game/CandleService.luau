--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CandlesModel = require(ServerScriptService.models.serverEntities.CandlesModel)
local CandlesConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CandlesConfig"))

local CandleService = {}

local CHECK_INTERVAL_SECONDS = 1

local isRunning = false

local function removeExpiredCandles(): ()
	local currentTime = os.time()
	local allCandles = CandlesModel.getAll()
	local candlesToRemove: { string } = {}

	for entityId, candle in allCandles do
		if currentTime - candle.createdTime >= CandlesConfig.lifetimeSeconds then
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
