--!strict

local InventoryModel = require(script.Parent.models.InventoryModel)

print("\n--- Test 1: Get inventory for player 1 and modify ---")
local player1Id = "player1"
local inventory1 = InventoryModel.get(player1Id)

inventory1:addGold(100)
inventory1.treasure = 5

print("Player 1 inventory:")
inventory1:fire()

print("\n--- Test 2: Get inventory for player 2 and modify ---")
local player2Id = "player2"
local inventory2 = InventoryModel.get(player2Id)

inventory2:addGold(50)
inventory2.treasure = 10

print("Player 2 inventory:")
inventory2:fire()

print("\n--- Test 3: Verify instances are different ---")
print("inventory1 == inventory2:", inventory1 == inventory2)
print("Expected: false (different players have different inventories)")

print("\n--- Test 4: Get player 1 inventory again and verify same instance ---")
local inventory1Again = InventoryModel.get(player1Id)
print("inventory1 == inventory1Again:", inventory1 == inventory1Again)
print("Expected: true (same player gets same inventory)")

print("\n--- Test 5: Verify player 1 inventory unchanged ---")
print("Player 1 inventory (should still have gold=100, treasure=5):")
inventory1Again:fire()

print("\n--- Test 6: Cleanup player 1 ---")
InventoryModel.remove(player1Id)
print("Removed player 1 inventory")

print("\n--- Test 7: Get player 1 inventory after cleanup (should be new) ---")
local inventory1New = InventoryModel.get(player1Id)
print("Player 1 new inventory (should have gold=0, treasure=0):")
inventory1New:fire()
