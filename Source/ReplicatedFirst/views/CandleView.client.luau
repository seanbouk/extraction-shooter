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
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Network = require(ReplicatedStorage:WaitForChild("Network"))
local CandlesConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CandlesConfig"))

local candlesState = Network.State.Candles

-- Template for spawning candles
local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
local candleTemplate = assetsFolder:WaitForChild("Candle")

-- Track spawned candles by entityId to avoid duplicates
local spawnedCandles: { [string]: Model } = {}

-- Animation state for shrinking candles
type CandleAnimationState = {
	model: Model,
	shaft: BasePart,
	wick: Instance,
	initialShaftHeight: number,
	initialShaftY: number,
	initialWickCFrame: CFrame,
	tickAtSpawn: number, -- tick() when spawned locally (for smooth animation)
	wickDestroyed: boolean,
}

local candleAnimations: { [string]: CandleAnimationState } = {}

local function spawnCandle(entityId: string, data: Network.CandlesState)
	-- Skip if already spawned
	if spawnedCandles[entityId] then
		return
	end

	-- Skip if data is not a valid candle state table
	if type(data) ~= "table" then
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

	-- Initialize animation state
	local shaft = candle:FindFirstChild("Shaft") :: BasePart?
	local wick = candle:FindFirstChild("Wick")

	if shaft and wick then
		candleAnimations[entityId] = {
			model = candle,
			shaft = shaft,
			wick = wick,
			initialShaftHeight = shaft.Size.X, -- Cylinders use X for height
			initialShaftY = shaft.Position.Y,
			initialWickCFrame = wick:GetPivot(),
			tickAtSpawn = tick(),
			wickDestroyed = false,
		}
	end

	print("CandleView: Spawned candle", entityId, "at", position)
end

-- ServerEntity state is an aggregated dictionary: { [entityId]: CandlesState }
type CandlesStateDictionary = { [string]: Network.CandlesState }

local function removeCandle(entityId: string)
	-- Clean up animation state
	candleAnimations[entityId] = nil

	local candle = spawnedCandles[entityId]
	if candle then
		candle:Destroy()
		spawnedCandles[entityId] = nil
		print("CandleView: Removed candle", entityId)
	end
end

-- Animation loop: shrink candles over their lifetime
RunService.Heartbeat:Connect(function()
	local currentTick = tick()

	for entityId, anim in candleAnimations do
		local elapsed = currentTick - anim.tickAtSpawn
		local progress = math.clamp(elapsed / CandlesConfig.lifetimeSeconds, 0, 1)

		-- Calculate new shaft height
		local newHeight = anim.initialShaftHeight * (1 - progress)
		local shrinkAmount = anim.initialShaftHeight - newHeight
		local moveDown = shrinkAmount / 2

		-- Update shaft size (X for cylinder height) and position (Y for world vertical)
		anim.shaft.Size = Vector3.new(newHeight, anim.shaft.Size.Y, anim.shaft.Size.Z)
		anim.shaft.Position = Vector3.new(anim.shaft.Position.X, anim.initialShaftY - moveDown, anim.shaft.Position.Z)

		-- Update wick position (preserve rotation, only offset Y at full speed)
		if not anim.wickDestroyed then
			anim.wick:PivotTo(anim.initialWickCFrame - Vector3.new(0, shrinkAmount, 0))
		end

		-- Destroy wick when fully shrunk
		if progress >= 1 and not anim.wickDestroyed then
			anim.wick:Destroy()
			anim.wickDestroyed = true
		end
	end
end)

-- Observe candle state changes
candlesState:Observe(function(allCandles: CandlesStateDictionary)
	-- Spawn new candles
	for entityId, candleData in allCandles do
		spawnCandle(entityId, candleData)
	end

	-- Remove candles that no longer exist in state
	for entityId, _ in spawnedCandles do
		if not allCandles[entityId] then
			removeCandle(entityId)
		end
	end
end)

print("CandleView: Initialized")
