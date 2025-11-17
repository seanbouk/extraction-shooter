# Controller Development Guide

This guide explains how to create Controllers in this Roblox MVC project.

## What is a Controller?

Controllers handle user intents from the client, validate them, and update Models accordingly. They live exclusively on the server and act as the gatekeeper between client requests and authoritative game state.

## Architecture Overview

All controllers in this project follow an inheritance pattern based on `AbstractController`:

- **AbstractController**: Base class that automatically creates RemoteEvents and provides inheritance infrastructure
- **Concrete Controllers** (e.g., CashMachineController): Extend AbstractController and implement specific business logic

## Data Flow

```
Client (View) → RemoteEvent (Intent) → Controller (Validation) → Model (State Update)
```

Controllers are responsible for:
- **Receiving** client intents via RemoteEvents
- **Validating** requests (anti-cheat, permissions, game rules)
- **Updating** models with validated data
- **Never** directly manipulating Views or client state

## Creating a New Controller

### Step 1: Understand AbstractController

All controllers inherit from `AbstractController.lua` which provides:

- **`new(controllerName: string)`**: Constructor that creates the controller and its RemoteEvent
- **`remoteEvent: RemoteEvent`**: Automatically created RemoteEvent for client-server communication

**Automatic RemoteEvent Creation:**
- Takes the controller name (e.g., "CashMachineController")
- Removes "Controller" suffix
- Adds "Intent" suffix
- Creates `[Name]Intent` in `ReplicatedStorage/Shared/Events/`
- Example: `CashMachineController` → `CashMachineIntent`

### Step 2: Create Your Controller File

Create a new ModuleScript in `src/server/controllers/YourController.lua`:

```lua
--!strict

local AbstractController = require(script.Parent.AbstractController)
local YourModel = require(script.Parent.Parent.models.YourModel)

local YourController = {}
YourController.__index = YourController
setmetatable(YourController, AbstractController)

export type YourController = typeof(setmetatable({}, YourController)) & AbstractController.AbstractController

function YourController.new(): YourController
	local self = AbstractController.new("YourController") :: any
	setmetatable(self, YourController)

	-- Set up event listener
	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string, ...)
		-- Validate the request
		if not isValidAction(action) then
			warn("Invalid action from " .. player.Name .. ": " .. tostring(action))
			return
		end

		-- Check permissions/anti-cheat
		if not canPlayerDoThis(player) then
			warn("Unauthorized action attempt from " .. player.Name)
			return
		end

		-- Update the model (per-player instance)
		local model = YourModel.get(tostring(player.UserId))

		if action == "SomeAction" then
			model:performAction(...)
		elseif action == "AnotherAction" then
			model:performOtherAction(...)
		end
	end)

	print("YourController initialized")

	return self :: YourController
end

return YourController
```

### Step 3: Key Pattern Requirements

#### Inheritance Setup

```lua
setmetatable(YourController, AbstractController)
```

This establishes the inheritance chain so your controller inherits from AbstractController.

#### Type Definition

```lua
export type YourController = typeof(setmetatable({}, YourController)) & AbstractController.AbstractController
```

The `& AbstractController.AbstractController` ensures proper type inheritance and eliminates type warnings.

#### Constructor Pattern

```lua
function YourController.new(): YourController
	local self = AbstractController.new("YourController") :: any
	setmetatable(self, YourController)

	-- Set up your event listeners here

	return self :: YourController
end
```

**Important**:
- Pass your controller's name to `AbstractController.new()`
- Cast to `any` to allow metatable manipulation
- Set up event listeners in the constructor

### Step 4: Initialize Your Controller

Controllers are automatically initialized by `ControllerRunner.server.lua` in the `controllers/` folder. The ControllerRunner uses auto-discovery to find and initialize all controllers:

```lua
--!strict

-- Auto-discover and initialize all controllers (skip Abstract)
local controllersFolder = script.Parent
local controllers = {}

for _, moduleScript in controllersFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") and not moduleScript.Name:find("^Abstract") then
		local Controller = require(moduleScript)
		Controller.new()
		table.insert(controllers, Controller)
		print("ControllerRunner: Initialized controller - " .. moduleScript.Name)
	end
end

print("ControllerRunner: All " .. #controllers .. " controller(s) initialized")
```

**Important**: You don't need to manually add your controller to ControllerRunner. Simply create it in the `controllers/` folder and it will be automatically discovered and initialized.

## Example: CashMachineController

The `CashMachineController.lua` file demonstrates a complete controller implementation:

### Features:
- Extends AbstractController
- Handles two actions: "Withdraw" and "Deposit"
- Validates action type and amount
- Updates InventoryModel based on validated requests
- Prints transaction results for debugging

### RemoteEvent Created:
- Name: `CashMachineIntent`
- Location: `ReplicatedStorage/Shared/Events/CashMachineIntent`

### Event Signature:
```lua
CashMachineIntent:FireServer(action: string, amount: number)
```

### Testing:
See `src/client/CashMachineTest.client.lua` for a complete example of how to:
- Wait for the RemoteEvent to be created
- Fire requests with proper parameters
- Test different actions

## File Locations

- **AbstractController**: `src/server/controllers/AbstractController.lua`
- **Your Controllers**: `src/server/controllers/YourController.lua`
- **Controller Initialization**: `src/server/controllers/ControllerRunner.server.lua`
- **RemoteEvents** (auto-created): `ReplicatedStorage/Shared/Events/`

## Client-Side Usage

From a LocalScript (View), fire intents to your controller:

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for the remote event
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local eventsFolder = sharedFolder:WaitForChild("Events")
local yourIntent = eventsFolder:WaitForChild("YourIntent") :: RemoteEvent

-- Fire an intent
yourIntent:FireServer("ActionName", arg1, arg2)
```

## Best Practices

### 1. Intent-Based Naming

Use intent-based names that describe what the player is **trying** to do, not commands:

✅ **Good**: `RequestPurchase`, `AttemptEquip`, `TryCollect`
❌ **Bad**: `SetInventory`, `UpdateGold`, `ChangeWeapon`

### 2. Always Validate

**NEVER** trust the client. Always validate:

```lua
-- Validate action
if action ~= "ValidAction1" and action ~= "ValidAction2" then
	warn("Invalid action: " .. tostring(action))
	return
end

-- Validate parameters
if type(amount) ~= "number" or amount <= 0 then
	warn("Invalid amount: " .. tostring(amount))
	return
end

-- Validate permissions
if not canPlayerAfford(player, cost) then
	warn("Player cannot afford this")
	return
end
```

### 3. Server Authority

Controllers enforce server authority:

```lua
-- ❌ DON'T: Trust client-provided data directly
local goldAmount = clientProvidedAmount

-- ✅ DO: Validate and use server-authoritative data
if type(clientProvidedAmount) == "number" and clientProvidedAmount > 0 then
	local model = InventoryModel.get()
	model:addGold(clientProvidedAmount)
end
```

### 4. Error Handling Philosophy

Follow the "fail fast" philosophy:

**Use `error()`** for configuration issues:
```lua
if not self.remoteEvent then
	error("RemoteEvent not created for " .. controllerName)
end
```

**Use `warn()` and `return`** for runtime validation failures:
```lua
if not isValid then
	warn("Invalid request from " .. player.Name)
	return
end
```

### 5. Type Safety

Always use `--!strict` and type all parameters:

```lua
self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string, amount: number)
	-- Fully typed function
end)
```

### 6. Action Patterns

Use action-based patterns for multiple operations:

```lua
if action == "Withdraw" then
	model:addGold(amount)
elseif action == "Deposit" then
	model:addGold(-amount)
elseif action == "Transfer" then
	model:transferGold(targetPlayer, amount)
else
	warn("Unknown action: " .. action)
end
```

## Common Patterns

### Single Action Controller

For controllers with one primary action:

```lua
function PurchaseController.new(): PurchaseController
	local self = AbstractController.new("PurchaseController") :: any
	setmetatable(self, PurchaseController)

	self.remoteEvent.OnServerEvent:Connect(function(player: Player, itemId: string)
		-- Validate and process purchase
		local shop = ShopModel.get(tostring(player.UserId))
		shop:purchaseItem(player, itemId)
	end)

	return self :: PurchaseController
end
```

### Multi-Action Controller (if/else pattern)

For controllers handling multiple related actions:

```lua
function InventoryController.new(): InventoryController
	local self = AbstractController.new("InventoryController") :: any
	setmetatable(self, InventoryController)

	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string, ...)
		local inventory = InventoryModel.get(tostring(player.UserId))

		if action == "Equip" then
			local itemId = ...
			inventory:equipItem(player, itemId)
		elseif action == "Unequip" then
			local slot = ...
			inventory:unequipSlot(player, slot)
		elseif action == "Drop" then
			local itemId = ...
			inventory:dropItem(player, itemId)
		else
			warn("Unknown action: " .. action)
		end
	end)

	return self :: InventoryController
end
```

### Multi-Action Controller (lookup table pattern)

For better scalability, use a lookup table to define actions:

```lua
local ACTIONS = {
	Withdraw = function(inventory: any, amount: number, player: Player)
		inventory:addGold(amount)
		print(player.Name .. " withdrew " .. amount .. " gold. New balance: " .. inventory.gold)
	end,
	Deposit = function(inventory: any, amount: number, player: Player)
		inventory:addGold(-amount)
		print(player.Name .. " deposited " .. amount .. " gold. New balance: " .. inventory.gold)
	end,
}

function CashMachineController.new(): CashMachineController
	local self = AbstractController.new("CashMachineController") :: any
	setmetatable(self, CashMachineController)

	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string, amount: number)
		-- Validate amount
		if amount <= 0 then
			warn("Invalid amount received from " .. player.Name .. ": " .. tostring(amount))
			return
		end

		-- Validate and execute action
		local actionFunc = ACTIONS[action]
		if not actionFunc then
			warn("Invalid action received from " .. player.Name .. ": " .. tostring(action))
			return
		end

		actionFunc(InventoryModel.get(tostring(player.UserId)), amount, player)
	end)

	return self :: CashMachineController
end
```

**Benefits of lookup table pattern:**
- Easy to add new actions - just add to the table
- Each action fully encapsulates its behavior
- Clean separation between validation and business logic
- Very readable event handler

### Anti-Cheat Integration

Add anti-cheat checks in your validation:

```lua
self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: string, targetPosition: Vector3)
	-- Distance check
	local character = player.Character
	if not character then return end

	local distance = (character.HumanoidRootPart.Position - targetPosition).Magnitude
	if distance > MAX_INTERACTION_DISTANCE then
		warn("Player too far from target: " .. player.Name)
		return
	end

	-- Rate limiting
	local lastAction = lastActionTime[player.UserId] or 0
	if tick() - lastAction < COOLDOWN_TIME then
		warn("Action cooldown active for: " .. player.Name)
		return
	end
	lastActionTime[player.UserId] = tick()

	-- Process valid action
	local model = YourModel.get(tostring(player.UserId))
	model:performAction(player, targetPosition)
end)
```

## Testing Your Controller

### Server-Side Test (Optional)

Create a test script in `src/server/` for unit testing:

```lua
--!strict

local YourController = require(script.Parent.controllers.YourController)

print("\n--- Testing YourController ---")

-- Initialize controller
local controller = YourController.new()

-- Verify RemoteEvent was created
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")
local intent = events:FindFirstChild("YourIntent")

if intent then
	print("✓ RemoteEvent created successfully: " .. intent.Name)
else
	warn("✗ RemoteEvent not found")
end
```

### Client-Side Test

Create a LocalScript in `src/client/` to test the full flow:

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local eventsFolder = sharedFolder:WaitForChild("Events")
local yourIntent = eventsFolder:WaitForChild("YourIntent") :: RemoteEvent

-- Test after delay
task.wait(2)

print("Testing YourController...")
yourIntent:FireServer("TestAction", testData)
```

## Adding New Controllers

1. **Create** `YourController.lua` in `src/server/controllers/`
2. **Extend** AbstractController using the pattern above
3. **That's it!** ControllerRunner will automatically discover and initialize your controller
4. **Test** from client using the auto-created RemoteEvent

**Note**: Controllers are auto-discovered by ControllerRunner. Any ModuleScript in the `controllers/` folder (except those starting with "Abstract") will be automatically required and initialized.

## Relationship to Models and Views

### Controllers → Models
- Controllers **update** models
- Controllers **never read** from models for validation (use server authority)
- Models handle their own state and broadcasting

### Controllers ← Views
- Views **send intents** to controllers via RemoteEvents
- Views **never directly** call controller methods
- Communication is always through RemoteEvents

### Complete Flow Example

```
1. Player clicks button (View)
2. View fires RemoteEvent: PurchaseIntent:FireServer("BuySword", "FireSword")
3. Controller receives intent, validates player can afford it
4. Controller updates InventoryModel: inventory:addItem(player, "FireSword")
5. Model updates its state and broadcasts to all clients
6. Views receive broadcast and update UI
```

## Next Steps

After creating your controller:

1. **Create a Model** (`src/server/models/`) to store the game state your controller modifies
2. **Create a View** (`src/client/views/`) to display state and send intents to your controller
3. **Test the flow** end-to-end with both server and client scripts

See the main [README.md](README.md) for the complete MVC architecture overview.
