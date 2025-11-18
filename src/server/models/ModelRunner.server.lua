--!strict

local Players = game:GetService("Players")

-- Initialize PersistenceServer before any models are used
local PersistenceServer = require(script.Parent.Parent.services.PersistenceServer)
PersistenceServer.init()

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
		local success, loadedData = PersistenceServer:loadModel(modelInfo.name, ownerId)

		-- If load failed, kick the player to prevent data loss
		if not success then
			player:Kick("Roblox servers are busy right now. Please rejoin to try again. Your progress is safe!")
			return -- Stop processing this player
		end

		-- Get or create model instance for this player (with defaults)
		local instance = modelInfo.class.get(ownerId)

		-- Apply loaded data if it exists (overwrites defaults)
		if loadedData then
			instance:_applyLoadedData(loadedData)
		end

		-- Don't fire initial state here - client will request when ready
		-- This prevents race condition where RemoteEvent hasn't replicated yet
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
