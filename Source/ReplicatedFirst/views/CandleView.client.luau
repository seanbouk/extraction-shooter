--!strict

--[[
	CandleView

	Pattern: C (State Observation)
	Purpose: Spawns and positions candle models based on server state

	Observes State:
	  - Network.State.Candles - Creates visual candles when state updates
	  - ServerEntity scope sends aggregated dictionary of all candles

	Behavior:
	  - Clones Candle template from ReplicatedStorage.Assets
	  - Positions at state coordinates with random offset:
	    - ±1 stud in X
	    - ±1 stud in Z
	    - +2 studs in Y
	  - Tracks spawned candles by entityId to avoid duplicates

	Studio Setup:
	1. Ensure Candle model exists in ReplicatedStorage.Assets
	2. Candle model should have a PrimaryPart set for positioning
	3. Candles spawn automatically when server creates them via CandlesModel
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage:WaitForChild("Network"))

local candlesState = Network.State.Candles

-- Template for spawning candles
local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
local candleTemplate = assetsFolder:WaitForChild("Candle")

-- Track spawned candles by entityId to avoid duplicates
local spawnedCandles: { [string]: Model } = {}

local function spawnCandle(entityId: string, data: Network.CandlesState)
	-- Skip if already spawned
	if spawnedCandles[entityId] then
		return
	end

	-- Clone the candle template
	local candle = candleTemplate:Clone() :: Model

	-- Calculate position with random offset
	local offsetX = (math.random() * 2) - 1 -- ±1 stud
	local offsetZ = (math.random() * 2) - 1 -- ±1 stud
	local offsetY = 2 -- +2 studs

	local position = Vector3.new(
		data.positionX + offsetX,
		data.positionY + offsetY,
		data.positionZ + offsetZ
	)

	-- Position the candle using PivotTo
	candle:PivotTo(CFrame.new(position))

	-- Parent to workspace and track
	candle.Parent = Workspace
	spawnedCandles[entityId] = candle

	print("CandleView: Spawned candle", entityId, "at", position)
end

-- ServerEntity state is an aggregated dictionary: { [entityId]: CandlesState }
type CandlesStateDictionary = { [string]: Network.CandlesState }

-- Observe candle state changes
candlesState:Observe(function(allCandles: CandlesStateDictionary)
	for entityId, candleData in allCandles do
		spawnCandle(entityId, candleData)
	end
end)

print("CandleView: Initialized")
