--!strict

--[[
	BazaarView

	Handles client-side visual feedback for Bazaars.
	Uses CollectionService to find all instances tagged "Bazaar" and
	manages their visual state (open/closed) based on player's gold amount.
	When the player has 200+ gold, the Bazaar opens (Neon material, prompt enabled).
	When the player has less than 200 gold, the Bazaar closes (Plastic material, prompt disabled).

	Expected hierarchy:
	Bazaar [Tagged "Bazaar"]
	└─ Base (Part/Model)
	   ├─ Sound
	   ├─ ParticleEmitter
	   ├─ ProximityPrompt
	   └─ Decal
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

-- Import shared constants and state events
local IntentActions = require(ReplicatedStorage:WaitForChild("IntentActions"))
local StateEvents = require(ReplicatedStorage:WaitForChild("StateEvents"))

-- Get the remote events
local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local bazaarIntent = eventsFolder:WaitForChild("BazaarIntent") :: RemoteEvent
local inventoryStateChanged = eventsFolder:WaitForChild(StateEvents.Inventory.EventName) :: RemoteEvent

-- Constants
local BAZAAR_TAG = "Bazaar"
local TREASURE_COST = 200

-- Store current gold amount
local currentGold = 0

-- Sets up interaction handling for a single bazaar
local function setupBazaar(bazaar: Instance)
	-- Wait for the Base part/model
	local base = bazaar:WaitForChild("Base")

	-- Wait for required components
	local proximityPrompt = base:WaitForChild("ProximityPrompt") :: ProximityPrompt
	local particleEmitter = base:WaitForChild("ParticleEmitter") :: ParticleEmitter
	local sound = base:WaitForChild("Sound") :: Sound

	-- Get the Base part (assuming it's a BasePart)
	local basePart: BasePart
	if base:IsA("BasePart") then
		basePart = base
	else
		-- If Base is a Model, find the primary part or first part
		local model = base :: Model
		if model.PrimaryPart then
			basePart = model.PrimaryPart
		else
			-- Find first BasePart child
			for _, child in ipairs(model:GetDescendants()) do
				if child:IsA("BasePart") then
					basePart = child
					break
				end
			end
		end
	end

	if not basePart then
		warn("BazaarView: Could not find BasePart for " .. bazaar.Name)
		return
	end

	-- Function to update visual state based on gold amount
	local function updateState(gold: number)
		if gold >= TREASURE_COST then
			-- Open state: Neon material, prompt enabled
			basePart.Material = Enum.Material.Neon
			proximityPrompt.Enabled = true
		else
			-- Closed state: Plastic material, prompt disabled
			basePart.Material = Enum.Material.Plastic
			proximityPrompt.Enabled = false
		end
	end

	-- Initialize with current gold
	updateState(currentGold)

	-- Connect to proximity prompt trigger
	proximityPrompt.Triggered:Connect(function(player: Player)
		-- Only allow local player to trigger
		if player ~= localPlayer then
			return
		end

		-- Emit particles
		local particleCount = particleEmitter.Rate
		particleEmitter:Emit(particleCount)

		-- Play the sound
		sound:Play()

		-- Send intent to server to buy treasure
		bazaarIntent:FireServer(IntentActions.Bazaar.BuyTreasure)
	end)

	-- Listen for inventory updates to update state
	inventoryStateChanged.OnClientEvent:Connect(function(inventoryData: StateEvents.InventoryData)
		-- Only update if this is the local player's inventory
		local localPlayerId = tostring(localPlayer.UserId)
		if inventoryData.ownerId == localPlayerId then
			currentGold = inventoryData.gold
			updateState(currentGold)
		end
	end)
end

-- Initialize all existing bazaars
for _, bazaar in ipairs(CollectionService:GetTagged(BAZAAR_TAG)) do
	task.spawn(function()
		setupBazaar(bazaar)
	end)
end

-- Handle newly added bazaars
CollectionService:GetInstanceAddedSignal(BAZAAR_TAG):Connect(function(bazaar: Instance)
	task.spawn(function()
		setupBazaar(bazaar)
	end)
end)
