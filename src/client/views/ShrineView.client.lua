--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

-- Import shared constants and state events
local IntentActions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IntentActions"))
local StateEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StateEvents"))

-- Get remote events
local eventsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
local shrineIntent = eventsFolder:WaitForChild("ShrineIntent") :: RemoteEvent
local shrineStateChanged = eventsFolder:WaitForChild(StateEvents.Shrine.EventName) :: RemoteEvent
local inventoryStateChanged = eventsFolder:WaitForChild(StateEvents.Inventory.EventName) :: RemoteEvent

-- Constants
local SHRINE_TAG = "Shrine"
local DONATION_AMOUNT = 1

local currentTreasure = 0

-- Helper to get player name from UserId
local function getPlayerNameFromUserId(userId: string): string
	local userIdNum = tonumber(userId)
	if not userIdNum then
		return "Unknown"
	end

	local success, username = pcall(function()
		return Players:GetNameFromUserIdAsync(userIdNum)
	end)

	if success then
		return username
	else
		return "Player " .. userId
	end
end

local function setupShrine(shrine: Instance)
	local base = shrine:WaitForChild("Base")
	local proximityPrompt = base:WaitForChild("ProximityPrompt") :: ProximityPrompt
	local sound = base:WaitForChild("Sound") :: Sound
	local surfaceGui = base:WaitForChild("SurfaceGui") :: SurfaceGui
	local textBox = surfaceGui:WaitForChild("TextBox") :: TextLabel
	local particleEmitter = base:WaitForChild("ParticleEmitter") :: ParticleEmitter

	-- Store original scale values to preserve designer settings
	local originalXScale = textBox.Position.X.Scale
	local originalYScale = textBox.Position.Y.Scale
	local originalYOffset = textBox.Position.Y.Offset

	-- Initialize position with X offset at 400
	textBox.Position = UDim2.new(
		originalXScale,
		400,
		originalYScale,
		originalYOffset
	)

	-- Function to update visual state
	local function updateState(canAfford: boolean)
		if canAfford then
			-- Available state: Can afford
			proximityPrompt.Enabled = true
			proximityPrompt.ActionText = "Donate (1 treasure)"
		else
			-- Locked state: Cannot afford
			proximityPrompt.Enabled = false
			proximityPrompt.ActionText = "Need 1 treasure"
		end
	end

	-- Initialize with default state
	updateState(currentTreasure >= DONATION_AMOUNT)
	textBox.Text = "Shrine awaits..."

	-- Connect to proximity prompt
	proximityPrompt.Triggered:Connect(function(player: Player)
		if player ~= localPlayer then
			return
		end

		-- Immediate feedback
		sound:Play()

		-- Send intent to server
		shrineIntent:FireServer(IntentActions.Shrine.Donate)
	end)

	-- Listen for shrine state changes (ALL players see this - no ownerId filter!)
	shrineStateChanged.OnClientEvent:Connect(function(shrineData: StateEvents.ShrineData)
		-- Emit particles based on total treasure count
		particleEmitter:Emit(shrineData.treasure)

		-- Update text to show who donated
		if shrineData.userId and shrineData.userId ~= "" then
			local username = getPlayerNameFromUserId(shrineData.userId)
			textBox.Text = "Thank you, " .. username .. "!"

			-- Reset position to starting point (400 offset)
			textBox.Position = UDim2.new(originalXScale, 400, originalYScale, originalYOffset)

			-- First tween info: 2 seconds, BounceOut
			local tweenInfo1 = TweenInfo.new(
				2,
				Enum.EasingStyle.Bounce,
				Enum.EasingDirection.Out,
				0,
				false,
				0
			)

			-- Second tween info: 1.5 seconds, Circular EaseOut (delayed by 1 second)
			local tweenInfo2 = TweenInfo.new(
				1.5,
				Enum.EasingStyle.Circular,
				Enum.EasingDirection.Out,
				0,
				false,
				0
			)

			-- First tween: 400 -> 0 (2 seconds)
			local tween1 = TweenService:Create(textBox, tweenInfo1, {
				Position = UDim2.new(originalXScale, 0, originalYScale, originalYOffset)
			})

			-- Second tween: 0 -> -300 (3 seconds)
			local tween2 = TweenService:Create(textBox, tweenInfo2, {
				Position = UDim2.new(originalXScale, -300, originalYScale, originalYOffset)
			})

			-- Chain them with 1 second delay (start at 3 seconds total)
			tween1.Completed:Connect(function()
				task.wait(1)
				tween2:Play()
			end)

			-- Reset position to 400 when animation completes
			tween2.Completed:Connect(function()
				textBox.Position = UDim2.new(originalXScale, 400, originalYScale, originalYOffset)
			end)

			-- Start the animation
			tween1:Play()
		end
	end)

	-- Listen for inventory changes (only local player)
	inventoryStateChanged.OnClientEvent:Connect(function(inventoryData: StateEvents.InventoryData)
		local localPlayerId = tostring(localPlayer.UserId)
		if inventoryData.ownerId == localPlayerId then
			currentTreasure = inventoryData.treasure
			updateState(currentTreasure >= DONATION_AMOUNT)
		end
	end)

	-- Request initial state
	inventoryStateChanged:FireServer()

	print("ShrineView: Setup complete for " .. shrine.Name)
end

-- Initialize existing shrines
for _, shrine in ipairs(CollectionService:GetTagged(SHRINE_TAG)) do
	task.spawn(function()
		setupShrine(shrine)
	end)
end

-- Handle newly added shrines
CollectionService:GetInstanceAddedSignal(SHRINE_TAG):Connect(function(shrine: Instance)
	task.spawn(function()
		setupShrine(shrine)
	end)
end)

print("ShrineView: Initialized")
