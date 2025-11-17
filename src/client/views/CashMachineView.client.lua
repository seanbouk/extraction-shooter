--!strict

--[[
	CashMachineView

	Handles client-side visual and audio feedback for Cash Machines.
	Uses CollectionService to find all instances tagged "CashMachine" and
	connects to their ProximityPrompts to play particles and sounds.

	Expected hierarchy:
	Cash Machine [Tagged "CashMachine"]
	├─ PackageLink
	└─ Base (Part/Model)
	   ├─ Sound (named "Sound")
	   ├─ ParticleEmitter
	   ├─ ProximityPrompt
	   └─ Decal
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get the remote event for cash machine intents
local eventsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
local cashMachineIntent = eventsFolder:WaitForChild("CashMachineIntent") :: RemoteEvent

-- Constants
local CASH_MACHINE_TAG = "CashMachine"
local WITHDRAW_AMOUNT = 50

-- Sets up interaction handling for a single cash machine
local function setupCashMachine(cashMachine: Instance)
	-- Wait for the Base part/model
	local base = cashMachine:WaitForChild("Base")

	-- Wait for required components
	local proximityPrompt = base:WaitForChild("ProximityPrompt") :: ProximityPrompt
	local particleEmitter = base:WaitForChild("ParticleEmitter") :: ParticleEmitter
	local sound = base:WaitForChild("Sound") :: Sound

	-- Connect to proximity prompt trigger
	proximityPrompt.Triggered:Connect(function(player: Player)
		-- Emit particles based on the Rate value
		local particleCount = particleEmitter.Rate
		particleEmitter:Emit(particleCount)

		-- Play the sound
		sound:Play()

		-- Send intent to server to withdraw gold
		cashMachineIntent:FireServer("Withdraw", WITHDRAW_AMOUNT)
	end)

	print(`CashMachineView: Setup complete for {cashMachine.Name}`)
end

-- Initialize all existing cash machines
for _, cashMachine in ipairs(CollectionService:GetTagged(CASH_MACHINE_TAG)) do
	task.spawn(function()
		setupCashMachine(cashMachine)
	end)
end

-- Handle newly added cash machines
CollectionService:GetInstanceAddedSignal(CASH_MACHINE_TAG):Connect(function(cashMachine: Instance)
	task.spawn(function()
		setupCashMachine(cashMachine)
	end)
end)

print("CashMachineView: Initialized")
