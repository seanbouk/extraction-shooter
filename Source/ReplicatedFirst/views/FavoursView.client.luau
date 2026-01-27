--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))

local view = AbstractView.new("FavoursView", "Favours")
local toggleEvent = view:createEvent("FavoursToggleEvent")

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

view:initialize(setupFavours)
