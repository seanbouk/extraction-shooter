--!strict

--[[
	TimeOfDayTriggerView

	Pattern: A (Pure Client-Side Feedback)
	Purpose: Tweens the local player's time of day when they walk into a trigger zone

	When the local player touches a "TimeOfDayTrigger"-tagged part, this view
	tweens Lighting.ClockTime to the part's "Time" attribute. Each player sees
	the correct time of day for the part of the map they're on.

	Expected Hierarchy:
	BasePart (Tagged: "TimeOfDayTrigger")
	  Attributes:
	    Time (number) - Target ClockTime value (0-24)

	Studio Setup:
	1. Create a Part in Workspace covering the trigger zone
	2. Add attribute "Time" (number) set to desired ClockTime (e.g., 14 for 2 PM)
	3. Apply CollectionService tag "TimeOfDayTrigger" to the Part
	4. Set CanCollide = false and Transparency = 1 if desired
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))

local localPlayer = Players.LocalPlayer

local TWEEN_INFO = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local activeTween: Tween? = nil

local view = AbstractView.new("TimeOfDayTriggerView", "TimeOfDayTrigger")

local function setupTrigger(trigger: Instance)
	local part = trigger :: BasePart

	part.Touched:Connect(function(otherPart: BasePart)
		local character = localPlayer.Character
		if not character then
			return
		end
		if not otherPart:IsDescendantOf(character) then
			return
		end

		local targetTime = part:GetAttribute("Time") :: number?
		if not targetTime then
			return
		end

		if activeTween then
			activeTween:Cancel()
		end

		activeTween = TweenService:Create(Lighting, TWEEN_INFO, { ClockTime = targetTime })
		activeTween:Play()
	end)
end

view:initialize(setupTrigger)
