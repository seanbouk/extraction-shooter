--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

-- Get remote events
local eventsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
local shrineIntent = eventsFolder:WaitForChild("ShrineIntent") :: RemoteEvent
local shrineStateChanged = eventsFolder:WaitForChild("ShrineStateChanged") :: RemoteEvent
local inventoryStateChanged = eventsFolder:WaitForChild("InventoryStateChanged") :: RemoteEvent

-- Constants
local SHRINE_TAG = "Shrine"
local DONATION_AMOUNT = 1

-- Types
type ShrineData = {
	ownerId: string,
	treasure: number,
	userID: string,
}

type InventoryData = {
	ownerId: string,
	gold: number,
	treasure: number,
}

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
		shrineIntent:FireServer("Donate")
	end)

	-- Listen for shrine state changes (ALL players see this - no ownerId filter!)
	shrineStateChanged.OnClientEvent:Connect(function(shrineData: ShrineData)
		-- Update text to show who donated
		if shrineData.userID and shrineData.userID ~= "" then
			local username = getPlayerNameFromUserId(shrineData.userID)
			textBox.Text = "Thank you, " .. username .. "!"
		end
	end)

	-- Listen for inventory changes (only local player)
	inventoryStateChanged.OnClientEvent:Connect(function(inventoryData: InventoryData)
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
