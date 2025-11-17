--!strict

local Players = game:GetService("Players")

-- Auto-discover and require all models (skip Abstract)
local modelsFolder = script.Parent
local models = {}

type ModelClass = {
	get: (ownerId: string) -> any,
	remove: (ownerId: string) -> (),
}

for _, moduleScript in modelsFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") and not moduleScript.Name:find("^Abstract") then
		local model = require(moduleScript) :: ModelClass
		table.insert(models, model)
		print("ModelRunner: Discovered model - " .. moduleScript.Name)
	end
end

-- Handle player initialization
Players.PlayerAdded:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Initializing models for player " .. player.Name)

	for _, model in models do
		-- Get or create model instance for this player
		local instance = model.get(ownerId)

		-- Broadcast initial state to the player
		instance:fire("owner")
	end
end)

-- Handle player cleanup
Players.PlayerRemoving:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Cleaning up models for player " .. player.Name)

	for _, model in models do
		model.remove(ownerId)
	end
end)

print("ModelRunner: Initialized with " .. #models .. " model(s)")
