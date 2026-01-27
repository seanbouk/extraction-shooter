--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))

local view = AbstractView.new("CandlesView", "Candles")
local toggleEvent = view:createEvent("CandlesToggleEvent")

local function setupCandles(candles: Instance)
	if not candles:IsA("ScreenGui") then
		warn(`CandlesView: {candles.Name} is not a ScreenGui`)
		return
	end

	local screenGui = candles :: ScreenGui
	screenGui.Enabled = false

	toggleEvent.Event:Connect(function()
		screenGui.Enabled = not screenGui.Enabled
	end)
end

view:initialize(setupCandles)
