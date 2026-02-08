--!strict

--[[
	NPCSpawnerView

	Pattern: A (Pure Client-Side Feedback)
	Purpose: Hides NPC spawner collision volumes at runtime

	Spawner parts are visible in Studio for easy editing but hidden in game.
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))

local view = AbstractView.new("NPCSpawnerView", "NPC")

local function setupSpawner(spawner: Instance)
	local part = spawner :: BasePart
	part.Transparency = 1
end

view:initialize(setupSpawner)
