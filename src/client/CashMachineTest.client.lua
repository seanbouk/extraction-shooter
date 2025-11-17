--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the remote event to be created
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local eventsFolder = sharedFolder:WaitForChild("Events")
local cashMachineIntent = eventsFolder:WaitForChild("CashMachineIntent") :: RemoteEvent

-- Wait 5 seconds before starting
task.wait(5)

print("CashMachineTest: Starting test loop")

-- Test loop: fire random action every 5 seconds
while true do
	-- Randomly choose Withdraw or Deposit
	local actions = { "Withdraw", "Deposit" }
	local randomAction = actions[math.random(1, 2)]

	-- Fire the remote event
	cashMachineIntent:FireServer(randomAction, 5)
	print("CashMachineTest: Sent " .. randomAction .. " request for 5 gold")

	-- Wait 5 seconds before next test
	task.wait(5)
end
