--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))

local favoursState = Network.State.Favours

local view = AbstractView.new("FavoursView", "Favours")
local toggleEvent = view:createEvent("FavoursToggleEvent")

-- Track UI frames by favour type
local typeItemFrames: { [string]: Frame } = {}

-- Aggregate counts by favour type from the favours dictionary
local function getCountsByType(favours: { [string]: Network.FavoursState }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, favour in pairs(favours) do
		local favourType = favour.favourType
		if favourType and favourType ~= "" then
			counts[favourType] = (counts[favourType] or 0) + 1
		end
	end
	return counts
end

-- Update UI to reflect current counts
local function updateUI(container: Frame, itemTemplate: Frame, favours: { [string]: Network.FavoursState })
	local counts = getCountsByType(favours)

	-- Remove items for types no longer present
	for favourType, frame in pairs(typeItemFrames) do
		if not counts[favourType] then
			frame:Destroy()
			typeItemFrames[favourType] = nil
		end
	end

	-- Create or update items for each type
	for favourType, count in pairs(counts) do
		local itemFrame = typeItemFrames[favourType]

		if not itemFrame then
			-- Clone template and set up new item
			itemFrame = itemTemplate:Clone()
			itemFrame.Name = favourType
			itemFrame.Visible = true
			itemFrame.Parent = container
			typeItemFrames[favourType] = itemFrame
		end

		-- Update labels
		local typeLabel = itemFrame:FindFirstChild("TypeLabel") :: TextLabel?
		local countLabel = itemFrame:FindFirstChild("CountLabel") :: TextLabel?

		if typeLabel then
			typeLabel.Text = favourType
		end

		if countLabel then
			countLabel.Text = tostring(count)
		end
	end
end

local function setupFavours(favours: Instance)
	if not favours:IsA("ScreenGui") then
		warn(`FavoursView: {favours.Name} is not a ScreenGui`)
		return
	end

	local screenGui = favours :: ScreenGui
	screenGui.Enabled = false

	-- Get Container and Item template
	local container = screenGui:WaitForChild("Container") :: Frame
	local itemTemplate = container:WaitForChild("Item") :: Frame

	-- Hide template (used for cloning only)
	itemTemplate.Visible = false

	toggleEvent.Event:Connect(function()
		screenGui.Enabled = not screenGui.Enabled
	end)

	-- Observe favour state changes (receives dictionary of all favours)
	favoursState:Observe(function(favours: { [string]: Network.FavoursState })
		updateUI(container, itemTemplate, favours)
	end)
end

view:initialize(setupFavours)
