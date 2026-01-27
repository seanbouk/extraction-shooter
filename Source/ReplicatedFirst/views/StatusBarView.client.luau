--!strict

--[[
	StatusBarView

	Handles client-side display of player inventory (gold and treasure) in the UI.
	Uses CollectionService to find all ScreenGui instances tagged "StatusBar" and
	updates the GoldLabel and TreasureLabel text when inventory changes are received.

	ViewState is used to visually indicate when treasure is zero (red color).

	Expected hierarchy:
	PlayerGui
	└── StatusBar [ScreenGui, Tagged "StatusBar"]
	    └── Frame
	        ├── UIListLayout
	        ├── GoldLabel (TextLabel)
	        ├── TreasureLabel (TextLabel)
	        └── _Templates (Folder) - removed at runtime
	            ├── TreasureLabelDefault (TextLabel)
	            └── TreasureLabelEmpty (TextLabel) - red TextColor3
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))
local ViewState = require(ReplicatedStorage:WaitForChild("ViewState"))

local inventoryState = Network.State.Inventory

local GOLD_EMOJI = "💰"
local TREASURE_EMOJI = "💎"

local view = AbstractView.new("StatusBarView", "StatusBar")

local function setupStatusBar(statusBar: Instance)
	if not statusBar:IsA("ScreenGui") then
		warn(`StatusBarView: {statusBar.Name} is not a ScreenGui`)
		return
	end

	local frame = statusBar:WaitForChild("Frame")

	local goldLabel = frame:WaitForChild("GoldLabel") :: TextLabel
	local treasureLabel = frame:WaitForChild("TreasureLabel") :: TextLabel

	-- Setup FavoursButton toggle
	local favoursButton = frame:FindFirstChild("FavoursButton") :: TextButton?
	if favoursButton then
		favoursButton.Activated:Connect(function()
			local toggleEvent = view:getEvent("FavoursToggleEvent")
			if toggleEvent then
				toggleEvent:Fire()
			end
		end)
	end

	-- Setup CandlesButton toggle
	local candlesButton = frame:FindFirstChild("CandlesButton") :: TextButton?
	if candlesButton then
		candlesButton.Activated:Connect(function()
			local toggleEvent = view:getEvent("CandlesToggleEvent")
			if toggleEvent then
				toggleEvent:Fire()
			end
		end)
	end

	-- Setup ViewState for treasure label visual states
	local treasureLabelStates: ViewState.ViewStateInstance? = nil
	local templatesFolder = frame:FindFirstChild("_Templates")

	if templatesFolder then
		local defaultTemplate = templatesFolder:FindFirstChild("TreasureLabelDefault")
		local emptyTemplate = templatesFolder:FindFirstChild("TreasureLabelEmpty")

		if defaultTemplate and emptyTemplate then
			treasureLabelStates = ViewState.new(defaultTemplate, emptyTemplate)
			templatesFolder.Parent = nil -- Hide at runtime
		end
	end

	local function updateLabels(gold: number, treasure: number)
		goldLabel.Text = `{GOLD_EMOJI} {gold}`
		treasureLabel.Text = `{TREASURE_EMOJI} {treasure}`

		-- Apply visual state based on treasure amount
		if treasureLabelStates then
			if treasure == 0 then
				treasureLabelStates:apply(treasureLabel, "TreasureLabelEmpty")
			else
				treasureLabelStates:apply(treasureLabel, "TreasureLabelDefault")
			end
		end
	end

	updateLabels(0, 0)

	inventoryState:Observe(function(data: Network.InventoryState)
		updateLabels(data.gold, data.treasure)
	end)
end

view:initialize(setupStatusBar)
