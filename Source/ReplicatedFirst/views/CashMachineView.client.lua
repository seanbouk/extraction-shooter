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

local Network = require(ReplicatedStorage:WaitForChild("Network"))

local cashMachineIntent = Network.Intent.CashMachine

local CASH_MACHINE_TAG = "CashMachine"
local WITHDRAW_AMOUNT = 50

local function setupCashMachine(cashMachine: Instance)
	local base = cashMachine:WaitForChild("Base")

	local proximityPrompt = base:WaitForChild("ProximityPrompt") :: ProximityPrompt
	local particleEmitter = base:WaitForChild("ParticleEmitter") :: ParticleEmitter
	local sound = base:WaitForChild("Sound") :: Sound

	proximityPrompt.Triggered:Connect(function(player: Player)
		local particleCount = particleEmitter.Rate
		particleEmitter:Emit(particleCount)

		sound:Play()

		cashMachineIntent:FireServer(Network.Actions.CashMachine.Withdraw, WITHDRAW_AMOUNT)
	end)
end

for _, cashMachine in ipairs(CollectionService:GetTagged(CASH_MACHINE_TAG)) do
	task.spawn(function()
		setupCashMachine(cashMachine)
	end)
end

CollectionService:GetInstanceAddedSignal(CASH_MACHINE_TAG):Connect(function(cashMachine: Instance)
	task.spawn(function()
		setupCashMachine(cashMachine)
	end)
end)
