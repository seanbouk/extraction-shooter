--!strict

local InventoryModel = require(script.Parent.models.InventoryModel)

print("\n--- Test 1: Get singleton instance and modify ---")
local inventory1 = InventoryModel.get()

inventory1:addGold(100)
inventory1.treasure = 5

inventory1:fire()

print("\n--- Test 2: Get singleton again and verify same instance ---")
local inventory2 = InventoryModel.get()

print("inventory1 == inventory2:", inventory1 == inventory2)

inventory2:addGold(50)
inventory2.treasure = 10

inventory2:fire()
