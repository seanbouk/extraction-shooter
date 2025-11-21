--!strict

--[[
	StatusBarView

	Handles client-side display of player inventory (gold and treasure) in the UI.
	Uses CollectionService to find all ScreenGui instances tagged "StatusBar" and
	updates the GoldLabel and TreasureLabel text when inventory changes are received.

	Expected hierarchy:
	StarterGui
	└── StatusBar [ScreenGui, Tagged "StatusBar"]
	    └── Frame
	        ├── UIListLayout
	        ├── GoldLabel (TextLabel)
	        └── TreasureLabel (TextLabel)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

-- Import shared state events
local StateEvents = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("StateEvents"))

-- Wait for the remote event for inventory state changes
local eventsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
local inventoryStateChanged = eventsFolder:WaitForChild(StateEvents.Inventory.EventName) :: RemoteEvent

-- Constants
local STATUS_BAR_TAG = "StatusBar"
local GOLD_EMOJI = "💰"
local TREASURE_EMOJI = "💎"

-- Sets up the status bar UI for a single ScreenGui
local function setupStatusBar(statusBar: Instance)
	-- Ensure it's a ScreenGui
	if not statusBar:IsA("ScreenGui") then
		warn(`StatusBarView: {statusBar.Name} is not a ScreenGui`)
		return
	end

	-- Wait for the Frame
	local frame = statusBar:WaitForChild("Frame")

	-- Wait for the text labels
	local goldLabel = frame:WaitForChild("GoldLabel") :: TextLabel
	local treasureLabel = frame:WaitForChild("TreasureLabel") :: TextLabel

	-- Function to update the labels
	local function updateLabels(gold: number, treasure: number)
		goldLabel.Text = `{GOLD_EMOJI} {gold}`
		treasureLabel.Text = `{TREASURE_EMOJI} {treasure}`
	end

	-- Initialize with zero values
	updateLabels(0, 0)

	-- Listen for inventory state changes
	inventoryStateChanged.OnClientEvent:Connect(function(inventoryData: StateEvents.InventoryData)
		updateLabels(inventoryData.gold, inventoryData.treasure)
	end)

	-- Request initial state from server now that listener is set up
	inventoryStateChanged:FireServer()

	print(`StatusBarView: Setup complete for {statusBar.Name}`)
end

-- Initialize all existing status bars
for _, statusBar in ipairs(CollectionService:GetTagged(STATUS_BAR_TAG)) do
	task.spawn(function()
		setupStatusBar(statusBar)
	end)
end

-- Handle newly added status bars
CollectionService:GetInstanceAddedSignal(STATUS_BAR_TAG):Connect(function(statusBar: Instance)
	task.spawn(function()
		setupStatusBar(statusBar)
	end)
end)

print("StatusBarView: Initialized")
