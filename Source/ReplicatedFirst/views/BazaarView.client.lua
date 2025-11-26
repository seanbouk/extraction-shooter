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

local IntentActions = require(ReplicatedStorage:WaitForChild("IntentActions"))
local StateEvents = require(ReplicatedStorage:WaitForChild("StateEvents"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local bazaarIntent = eventsFolder:WaitForChild("BazaarIntent") :: RemoteEvent
local inventoryStateChanged = eventsFolder:WaitForChild(StateEvents.Inventory.EventName) :: RemoteEvent

local BAZAAR_TAG = "Bazaar"
local TREASURE_COST = 200

local currentGold = 0

local function setupBazaar(bazaar: Instance)
	local base = bazaar:WaitForChild("Base")

	local proximityPrompt = base:WaitForChild("ProximityPrompt") :: ProximityPrompt
	local particleEmitter = base:WaitForChild("ParticleEmitter") :: ParticleEmitter
	local sound = base:WaitForChild("Sound") :: Sound

	local basePart: BasePart
	if base:IsA("BasePart") then
		basePart = base
	else
		local model = base :: Model
		if model.PrimaryPart then
			basePart = model.PrimaryPart
		else
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

	local function updateState(gold: number)
		if gold >= TREASURE_COST then
			basePart.Material = Enum.Material.Neon
			proximityPrompt.Enabled = true
		else
			basePart.Material = Enum.Material.Plastic
			proximityPrompt.Enabled = false
		end
	end

	updateState(currentGold)

	proximityPrompt.Triggered:Connect(function(player: Player)
		if player ~= localPlayer then
			return
		end

		local particleCount = particleEmitter.Rate
		particleEmitter:Emit(particleCount)

		sound:Play()

		bazaarIntent:FireServer(IntentActions.Bazaar.BuyTreasure)
	end)

	inventoryStateChanged.OnClientEvent:Connect(function(inventoryData: StateEvents.InventoryData)
		local localPlayerId = tostring(localPlayer.UserId)
		if inventoryData.ownerId == localPlayerId then
			currentGold = inventoryData.gold
			updateState(currentGold)
		end
	end)
end

for _, bazaar in ipairs(CollectionService:GetTagged(BAZAAR_TAG)) do
	task.spawn(function()
		setupBazaar(bazaar)
	end)
end

CollectionService:GetInstanceAddedSignal(BAZAAR_TAG):Connect(function(bazaar: Instance)
	task.spawn(function()
		setupBazaar(bazaar)
	end)
end)
