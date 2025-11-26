--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local IntentActions = require(ReplicatedStorage:WaitForChild("IntentActions"))
local StateEvents = require(ReplicatedStorage:WaitForChild("StateEvents"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local shrineIntent = eventsFolder:WaitForChild("ShrineIntent") :: RemoteEvent
local shrineStateChanged = eventsFolder:WaitForChild(StateEvents.Shrine.EventName) :: RemoteEvent
local inventoryStateChanged = eventsFolder:WaitForChild(StateEvents.Inventory.EventName) :: RemoteEvent

local SHRINE_TAG = "Shrine"
local DONATION_AMOUNT = 1

local currentTreasure = 0

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

	local originalXScale = textBox.Position.X.Scale
	local originalYScale = textBox.Position.Y.Scale
	local originalYOffset = textBox.Position.Y.Offset

	local activeTween1: Tween? = nil
	local activeTween2: Tween? = nil
	local tween1Connection: RBXScriptConnection? = nil
	local tween2Connection: RBXScriptConnection? = nil

	textBox.Position = UDim2.new(
		originalXScale,
		400,
		originalYScale,
		originalYOffset
	)

	local function updateState(canAfford: boolean)
		if canAfford then
			proximityPrompt.Enabled = true
			proximityPrompt.ActionText = "Donate (1 treasure)"
		else
			proximityPrompt.Enabled = false
			proximityPrompt.ActionText = "Need 1 treasure"
		end
	end

	updateState(currentTreasure >= DONATION_AMOUNT)
	textBox.Text = "Shrine awaits..."

	proximityPrompt.Triggered:Connect(function(player: Player)
		if player ~= localPlayer then
			return
		end

		sound:Play()
		shrineIntent:FireServer(IntentActions.Shrine.Donate)
	end)

	-- Listen for shrine state changes (ALL players see this - no ownerId filter!)
	shrineStateChanged.OnClientEvent:Connect(function(shrineData: StateEvents.ShrineData)
		particleEmitter:Emit(shrineData.treasure)

		if shrineData.userId and shrineData.userId ~= "" then
			local username = getPlayerNameFromUserId(shrineData.userId)
			textBox.Text = "Thank you, " .. username .. "!"

			if activeTween1 then
				activeTween1:Cancel()
			end
			if activeTween2 then
				activeTween2:Cancel()
			end
			if tween1Connection then
				tween1Connection:Disconnect()
				tween1Connection = nil
			end
			if tween2Connection then
				tween2Connection:Disconnect()
				tween2Connection = nil
			end

			textBox.Position = UDim2.new(originalXScale, 400, originalYScale, originalYOffset)

			local tweenInfo1 = TweenInfo.new(
				2,
				Enum.EasingStyle.Bounce,
				Enum.EasingDirection.Out,
				0,
				false,
				0
			)

			local tweenInfo2 = TweenInfo.new(
				1.5,
				Enum.EasingStyle.Circular,
				Enum.EasingDirection.Out,
				0,
				false,
				0
			)

			activeTween1 = TweenService:Create(textBox, tweenInfo1, {
				Position = UDim2.new(originalXScale, 0, originalYScale, originalYOffset)
			})

			activeTween2 = TweenService:Create(textBox, tweenInfo2, {
				Position = UDim2.new(originalXScale, -300, originalYScale, originalYOffset)
			})

			tween1Connection = activeTween1.Completed:Connect(function()
				task.wait(1)
				if activeTween2 then
					activeTween2:Play()
				end
			end)

			tween2Connection = activeTween2.Completed:Connect(function()
				textBox.Position = UDim2.new(originalXScale, 400, originalYScale, originalYOffset)
			end)

			activeTween1:Play()
		end
	end)

	inventoryStateChanged.OnClientEvent:Connect(function(inventoryData: StateEvents.InventoryData)
		local localPlayerId = tostring(localPlayer.UserId)
		if inventoryData.ownerId == localPlayerId then
			currentTreasure = inventoryData.treasure
			updateState(currentTreasure >= DONATION_AMOUNT)
		end
	end)

	inventoryStateChanged:FireServer()
end

for _, shrine in ipairs(CollectionService:GetTagged(SHRINE_TAG)) do
	task.spawn(function()
		setupShrine(shrine)
	end)
end

CollectionService:GetInstanceAddedSignal(SHRINE_TAG):Connect(function(shrine: Instance)
	task.spawn(function()
		setupShrine(shrine)
	end)
end)
