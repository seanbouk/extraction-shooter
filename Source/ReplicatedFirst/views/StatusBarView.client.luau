--!strict

--[[
	StatusBarView

	Handles client-side display of player inventory (gold and treasure) in the UI.
	Uses CollectionService to find all ScreenGui instances tagged "StatusBar" and
	updates the GoldLabel and TreasureLabel text when inventory changes are received.

	Expected hierarchy:
	PlayerGui
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

local Network = require(ReplicatedStorage:WaitForChild("Network"))
local inventoryState = Network.State.Inventory

local STATUS_BAR_TAG = "StatusBar"
local GOLD_EMOJI = "💰"
local TREASURE_EMOJI = "💎"

local function setupStatusBar(statusBar: Instance)
	if not statusBar:IsA("ScreenGui") then
		warn(`StatusBarView: {statusBar.Name} is not a ScreenGui`)
		return
	end

	local frame = statusBar:WaitForChild("Frame")

	local goldLabel = frame:WaitForChild("GoldLabel") :: TextLabel
	local treasureLabel = frame:WaitForChild("TreasureLabel") :: TextLabel

	local function updateLabels(gold: number, treasure: number)
		goldLabel.Text = `{GOLD_EMOJI} {gold}`
		treasureLabel.Text = `{TREASURE_EMOJI} {treasure}`
	end

	updateLabels(0, 0)

	inventoryState:Observe(function(data: Network.InventoryState)
		updateLabels(data.gold, data.treasure)
	end)
end

for _, statusBar in ipairs(CollectionService:GetTagged(STATUS_BAR_TAG)) do
	task.spawn(function()
		setupStatusBar(statusBar)
	end)
end

CollectionService:GetInstanceAddedSignal(STATUS_BAR_TAG):Connect(function(statusBar: Instance)
	task.spawn(function()
		setupStatusBar(statusBar)
	end)
end)
