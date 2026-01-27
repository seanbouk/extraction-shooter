--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerScripts = localPlayer:WaitForChild("PlayerScripts")

local FAVOURS_TAG = "Favours"
local TOGGLE_EVENT_NAME = "FavoursToggleEvent"

-- Create the BindableEvent for toggle communication
local toggleEvent = Instance.new("BindableEvent")
toggleEvent.Name = TOGGLE_EVENT_NAME
toggleEvent.Parent = playerScripts

local function setupFavours(favours: Instance)
	if not favours:IsA("ScreenGui") then
		warn(`FavoursView: {favours.Name} is not a ScreenGui`)
		return
	end

	local screenGui = favours :: ScreenGui
	screenGui.Enabled = false

	toggleEvent.Event:Connect(function()
		screenGui.Enabled = not screenGui.Enabled
	end)
end

-- Standard CollectionService pattern
for _, favours in ipairs(CollectionService:GetTagged(FAVOURS_TAG)) do
	task.spawn(function()
		setupFavours(favours)
	end)
end

CollectionService:GetInstanceAddedSignal(FAVOURS_TAG):Connect(function(favours: Instance)
	task.spawn(function()
		setupFavours(favours)
	end)
end)
