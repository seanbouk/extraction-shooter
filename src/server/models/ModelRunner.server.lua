--!strict

local Players = game:GetService("Players")

-- Initialize PersistenceManager before any models are used
local PersistenceManager = require(script.Parent.Parent.services.PersistenceManager)
PersistenceManager.init()

-- Auto-discover and require all models (skip Abstract)
local modelsFolder = script.Parent
local models = {}

type ModelClass = {
	get: (ownerId: string) -> any,
	remove: (ownerId: string) -> (),
}

type ModelInfo = {
	class: ModelClass,
	name: string,
}

local modelInfos: { ModelInfo } = {}

for _, moduleScript in modelsFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") and not moduleScript.Name:find("^Abstract") then
		local model = require(moduleScript) :: ModelClass
		table.insert(models, model)
		table.insert(modelInfos, {
			class = model,
			name = moduleScript.Name,
		})
		print("ModelRunner: Discovered model - " .. moduleScript.Name)
	end
end

-- Handle player initialization
Players.PlayerAdded:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Initializing models for player " .. player.Name)

	for _, modelInfo in modelInfos do
		-- Load data from DataStore for this model
		local loadedData = PersistenceManager:loadModel(modelInfo.name, ownerId)

		-- Get or create model instance for this player (with defaults)
		local instance = modelInfo.class.get(ownerId)

		-- Apply loaded data if it exists (overwrites defaults)
		if loadedData then
			instance:_applyLoadedData(loadedData)
		end

		-- Broadcast initial state to the player (skip persistence to avoid overwriting)
		instance:fire("owner", true)
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
