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

- **`new(controllerName: string)`**: Constructor that creates the controller and its RemoteEvent, and prints initialization message
- **`remoteEvent: RemoteEvent`**: Automatically created RemoteEvent for client-server communication
- **`dispatchAction(actionsTable, action, player, ...)`**: Validates and executes actions from an ACTIONS table, with automatic error handling

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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
local YourModel = require(script.Parent.Parent.models.user.YourModel) -- or .server.YourModel
local IntentActions = require(ReplicatedStorage.IntentActions)

local YourController = {}
YourController.__index = YourController
setmetatable(YourController, AbstractController)

export type YourController = typeof(setmetatable({}, YourController)) & AbstractController.AbstractController

function YourController.new(): YourController
	local self = AbstractController.new("YourController") :: any
	setmetatable(self, YourController)

	-- Set up event listener with strongly-typed action parameter
	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: IntentActions.YourFeatureAction, ...)
		-- Check permissions/anti-cheat
		if not canPlayerDoThis(player) then
			warn("Unauthorized action attempt from " .. player.Name)
			return
		end

		-- Get the model
		-- For User-scoped models: get per-player instance
		local model = YourModel.get(tostring(player.UserId))
		-- For Server-scoped models: get shared instance
		-- local model = YourModel.get("SERVER")

		-- Use IntentActions constants instead of magic strings
		if action == IntentActions.YourFeature.SomeAction then
			model:performAction(...)
		elseif action == IntentActions.YourFeature.AnotherAction then
			model:performOtherAction(...)
		end
	end)

	-- Note: AbstractController.new() automatically prints initialization message

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

From a LocalScript (View), fire intents to your controller using IntentActions constants:

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import shared constants
local IntentActions = require(ReplicatedStorage:WaitForChild("IntentActions"))

-- Wait for the remote event
local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local yourIntent = eventsFolder:WaitForChild("YourIntent") :: RemoteEvent

-- Fire an intent with typed constant (not magic string)
yourIntent:FireServer(IntentActions.YourFeature.ActionName, arg1, arg2)
```

## Best Practices

### 1. Intent-Based Naming

Use intent-based names that describe what the player is **trying** to do, not commands:

✅ **Good**: `RequestPurchase`, `AttemptEquip`, `TryCollect`
❌ **Bad**: `SetInventory`, `UpdateGold`, `ChangeWeapon`

### 2. Always Validate

**NEVER** trust the client. Always validate:

```lua
-- Validate action (use IntentActions constants)
if action ~= IntentActions.YourFeature.ValidAction1 and action ~= IntentActions.YourFeature.ValidAction2 then
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

Always use `--!strict` and type all parameters with the most specific types available:

```lua
-- Use the exported action types from IntentActions for compile-time safety
self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: IntentActions.CashMachineAction, amount: number)
	-- Now Luau knows action can ONLY be "Withdraw" or "Deposit"
	-- Provides autocomplete and catches invalid action strings at compile-time
end)
```

### 6. Action Patterns

Use action-based patterns for multiple operations with IntentActions constants:

```lua
-- Use IntentActions constants instead of magic strings
if action == IntentActions.CashMachine.Withdraw then
	model:addGold(amount)
elseif action == IntentActions.CashMachine.Deposit then
	model:addGold(-amount)
elseif action == IntentActions.CashMachine.Transfer then
	model:transferGold(targetPlayer, amount)
else
	warn("Unknown action: " .. action)
end
```

## Common Patterns

### Decision Tree: Choosing Controller Action Pattern

Use this decision tree to determine which pattern to use for your controller:

**Question: How many distinct actions will this controller handle?**

- **1 action** → **Single Action Controller** (no action parameter needed)
- **2-3 actions** → **Either pattern works** (if/else is simpler for small numbers)
- **4+ actions** → **Lookup Table pattern** (more maintainable, easier to extend)

**Benefits of each approach:**

✅ **Single Action Controller** (no action parameter):
- Simplest pattern for controllers with one responsibility
- No action validation needed
- Clear and straightforward

✅ **if/else pattern** (2-3 actions):
- Simple to understand and write
- Good for small number of related actions
- Linear control flow is easy to follow

✅ **Lookup Table pattern** (4+ actions, RECOMMENDED):
- More scalable - easy to add new actions
- Better separation of concerns (functions are modular)
- Consistent organization across controllers
- AbstractController's `dispatchAction` handles validation
- Easier to test individual actions
- Better for code reviews

**Examples:**

**Single action:**
- ShopController → handles "PurchaseItem" only
- DonateController → handles "Donate" only

**2-3 actions (either pattern works):**
- EquipmentController → "Equip", "Unequip" (2 actions)
- TradeController → "SendOffer", "Accept", "Decline" (3 actions)

**4+ actions (use lookup table):**
- InventoryController → "Equip", "Unequip", "Drop", "Use", "Stack", "Split" (6 actions)
- SocialController → "SendFriendRequest", "AcceptRequest", "Block", "Unblock", "Mute" (5 actions)

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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IntentActions = require(ReplicatedStorage.IntentActions)

function InventoryController.new(): InventoryController
	local self = AbstractController.new("InventoryController") :: any
	setmetatable(self, InventoryController)

	-- Use strongly-typed action parameter for compile-time safety
	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: IntentActions.InventoryAction, ...)
		local inventory = InventoryModel.get(tostring(player.UserId))

		-- Use IntentActions constants
		if action == IntentActions.Inventory.Equip then
			local itemId = ...
			inventory:equipItem(player, itemId)
		elseif action == IntentActions.Inventory.Unequip then
			local slot = ...
			inventory:unequipSlot(player, slot)
		elseif action == IntentActions.Inventory.Drop then
			local itemId = ...
			inventory:dropItem(player, itemId)
		else
			warn("Unknown action: " .. action)
		end
	end)

	return self :: InventoryController
end
```

### Multi-Action Controller (lookup table pattern - RECOMMENDED)

For better scalability and maintainability, use named functions with a lookup table and IntentActions constants:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbstractController = require(script.Parent.AbstractController)
local InventoryModel = require(script.Parent.Parent.models.user.InventoryModel)
local IntentActions = require(ReplicatedStorage.IntentActions)

-- Define action functions at module level
local function withdraw(inventory: any, amount: number, player: Player)
	inventory:addGold(amount)
	print(player.Name .. " withdrew " .. amount .. " gold. New balance: " .. inventory.gold)
end

local function deposit(inventory: any, amount: number, player: Player)
	inventory:addGold(-amount)
	print(player.Name .. " deposited " .. amount .. " gold. New balance: " .. inventory.gold)
end

-- Map IntentActions constants to functions
local ACTIONS = {
	[IntentActions.CashMachine.Withdraw] = withdraw,
	[IntentActions.CashMachine.Deposit] = deposit,
}

function CashMachineController.new(): CashMachineController
	local self = AbstractController.new("CashMachineController") :: any
	setmetatable(self, CashMachineController)

	-- Use strongly-typed action parameter for compile-time safety
	self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: IntentActions.CashMachineAction, amount: number)
		-- Validate amount
		if amount <= 0 then
			warn("Invalid amount received from " .. player.Name .. ": " .. tostring(amount))
			return
		end

		-- Get model
		local inventory = InventoryModel.get(tostring(player.UserId))

		-- Dispatch action (AbstractController handles validation and execution)
		self:dispatchAction(ACTIONS, action, player, inventory, amount, player)
	end)

	return self :: CashMachineController
end
```

**Benefits of named function + lookup table + IntentActions pattern:**
- Easy to add new actions - define the function and add it to the table
- Each action is a named, reusable function (better for testing and debugging)
- Clean separation between validation and business logic
- Very readable event handler
- Consistent code organization across controllers
- AbstractController's `dispatchAction` method handles action validation automatically
- **Type-safe action strings** - no magic strings, prevents typos
- **Single source of truth** - all actions defined in IntentActions module

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
local events = ReplicatedStorage:WaitForChild("Events")
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

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
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
2. View fires RemoteEvent: PurchaseIntent:FireServer(IntentActions.Shop.BuySword, "FireSword")
3. Controller receives intent, validates player can afford it
4. Controller updates InventoryModel: inventory:addItem(player, "FireSword")
5. Model updates its state and broadcasts to all clients
6. Views receive broadcast and update UI
```

### Shared Constants (IntentActions)

All intent action strings are centralized in `src/shared/IntentActions.lua`:

**In Views (Client):**
```lua
local IntentActions = require(ReplicatedStorage:WaitForChild("IntentActions"))
cashMachineIntent:FireServer(IntentActions.CashMachine.Withdraw, amount)
```

**In Controllers (Server):**
```lua
local IntentActions = require(ReplicatedStorage.IntentActions)

-- Use exported types for strong typing
local ACTIONS = {
	[IntentActions.CashMachine.Withdraw] = withdraw,
	[IntentActions.CashMachine.Deposit] = deposit,
}

-- Type the action parameter with the exported type
self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: IntentActions.CashMachineAction, ...)
	-- Now Luau knows action can ONLY be "Withdraw" or "Deposit"
end)
```

**Exported Types:**
IntentActions.lua exports union types for each feature:
```lua
export type CashMachineAction = "Withdraw" | "Deposit"
export type BazaarAction = "BuyTreasure"
export type ShrineAction = "Donate"
```

**Benefits:**
- **Compile-time type safety** - prevents typos causing runtime errors
- **Strong typing** - action parameters are constrained to valid values only
- **Autocomplete support** - your IDE knows which actions are valid
- **Single source of truth** for all action strings
- **Easy refactoring** - change in one place, affects both views and controllers
- **Self-documenting code** - developers can see valid actions from the type
- **No more magic strings** scattered across the codebase

## Working with IntentActions

When creating a new controller, you need to add action constants to IntentActions for type-safe communication between views and controllers.

### What are IntentActions?

IntentActions is a centralized module (`src/shared/IntentActions.lua`) that provides:
- **Action constants** - Single source of truth for all user intent strings
- **Exported action types** - Type-safe action parameters for controllers
- **Complete MVC type safety** - From view through controller

### When to Add New Actions

Add new actions to IntentActions when:
- ✅ You create a new controller that handles user intents
- ✅ You're adding new functionality to an existing controller
- ✅ A view needs to send a new type of user intent to the server

### Step-by-Step: Adding New Actions

**1. Open `src/shared/IntentActions.lua`**

**2. Add action constants:**

Group related actions by feature:

```lua
local IntentActions = {
    -- ... existing actions ...
    YourFeature = {
        ActionName = "ActionName",
        AnotherAction = "AnotherAction",
    },
}
```

**3. Add exported type:**

Create a union type of all action strings:

```lua
-- ... existing type exports ...
export type YourFeatureAction = "ActionName" | "AnotherAction"
```

**4. Return the module:**

```lua
return IntentActions
```

### Action Naming Conventions

Actions should describe **what the user wants to do** (their intent), not what will happen (commands).

✅ **Good action names** (intent-focused, verb-based):
- `PurchaseWeapon` - User wants to buy a weapon
- `EquipItem` - User wants to equip an item
- `Donate` - User wants to donate
- `BuyTreasure` - User wants to purchase treasure
- `WithdrawGold` - User wants to withdraw from bank
- `AcceptQuest` - User wants to accept a quest

❌ **Bad action names** (command-like or too vague):
- `SetInventory` - Sounds like a command, not an intent
- `Update` - Too vague, update what?
- `Click` - Describes UI interaction, not intent
- `Execute` - Generic and unclear
- `Process` - Implementation detail, not user intent
- `Handle` - Developer jargon, not user-facing

### Example: Adding CashMachine Actions

**In IntentActions.lua:**

```lua
local IntentActions = {
    CashMachine = {
        Withdraw = "Withdraw",
        Deposit = "Deposit",
    },
    -- ... other features ...
}

export type CashMachineAction = "Withdraw" | "Deposit"

return IntentActions
```

**In Controller:**

```lua
local IntentActions = require(ReplicatedStorage.IntentActions)

local function withdraw(inventory: any, amount: number, player: Player)
    inventory:addGold(amount)
end

local function deposit(inventory: any, amount: number, player: Player)
    inventory:addGold(-amount)
end

-- Map IntentActions constants to handler functions
local ACTIONS = {
    [IntentActions.CashMachine.Withdraw] = withdraw,
    [IntentActions.CashMachine.Deposit] = deposit,
}

-- Use typed action parameter
self.remoteEvent.OnServerEvent:Connect(function(
    player: Player,
    action: IntentActions.CashMachineAction,  -- Type-safe!
    amount: number
)
    -- Validate and dispatch
    self:dispatchAction(ACTIONS, action, player, inventory, amount, player)
end)
```

**In View:**

```lua
local IntentActions = require(ReplicatedStorage:WaitForChild("IntentActions"))

-- Type-safe constant usage
remoteEvent:FireServer(IntentActions.CashMachine.Withdraw, 100)
```

### Multiple Actions in One Feature

When you have multiple related actions, group them under one feature:

```lua
-- IntentActions.lua
Shop = {
    BuyWeapon = "BuyWeapon",
    SellWeapon = "SellWeapon",
    PreviewWeapon = "PreviewWeapon",
    CompareWeapons = "CompareWeapons",
},

export type ShopAction = "BuyWeapon" | "SellWeapon" | "PreviewWeapon" | "CompareWeapons"
```

**Controller uses lookup table pattern:**

```lua
local function buyWeapon(player: Player, shop: any, weaponId: string)
    -- implementation
end

local function sellWeapon(player: Player, shop: any, weaponId: string)
    -- implementation
end

local function previewWeapon(player: Player, shop: any, weaponId: string)
    -- implementation
end

local function compareWeapons(player: Player, shop: any, weaponId1: string, weaponId2: string)
    -- implementation
end

local ACTIONS = {
    [IntentActions.Shop.BuyWeapon] = buyWeapon,
    [IntentActions.Shop.SellWeapon] = sellWeapon,
    [IntentActions.Shop.PreviewWeapon] = previewWeapon,
    [IntentActions.Shop.CompareWeapons] = compareWeapons,
}
```

### Single Action Feature

For controllers with only one action, you still benefit from the pattern:

```lua
-- IntentActions.lua
Shrine = {
    Donate = "Donate",
},

export type ShrineAction = "Donate"
```

This provides:
- Consistent pattern across all controllers
- Easy to add more actions later
- Type safety even for single actions
- Self-documenting code

### Updating Existing Actions

**Adding a new action to existing feature:**

```lua
-- Before
CashMachine = {
    Withdraw = "Withdraw",
    Deposit = "Deposit",
},

export type CashMachineAction = "Withdraw" | "Deposit"

-- After (adding Transfer)
CashMachine = {
    Withdraw = "Withdraw",
    Deposit = "Deposit",
    Transfer = "Transfer",  -- New action
},

export type CashMachineAction = "Withdraw" | "Deposit" | "Transfer"  -- Update type
```

**Then update controller:**

1. Add handler function
2. Add to ACTIONS table
3. Update OnServerEvent type annotation (already covered by union type)

### Type Safety Benefits

**Compile-time checking:**
```lua
-- ✓ Correct - Luau knows this is valid
remoteEvent:FireServer(IntentActions.CashMachine.Withdraw, 100)

-- ✗ Type error - "Withdraww" is not a valid action (typo caught!)
remoteEvent:FireServer(IntentActions.CashMachine.Withdraww, 100)

-- ✗ Type error - "Hack" is not a CashMachineAction
local action: IntentActions.CashMachineAction = "Hack"
```

**IDE autocomplete:**
```lua
-- Type IntentActions.CashMachine. and see:
-- - Withdraw
-- - Deposit
```

**Refactoring safety:**
```lua
-- Change "Withdraw" to "WithdrawFunds" in IntentActions
-- Luau will show type errors at every usage site, guiding you to update them all
```

### Troubleshooting

**Problem:** Type errors in controller OnServerEvent
- Check: Did you export the type from IntentActions?
- Fix: Add `export type YourFeatureAction = "Action1" | "Action2"`

**Problem:** Action not in ACTIONS table at runtime
- Check: Did you map the IntentActions constant to a function?
- Fix: `[IntentActions.Feature.Action] = handlerFunction`

**Problem:** View sending wrong action string
- Check: Are you using IntentActions constants, not magic strings?
- Fix: Use `IntentActions.Feature.Action` instead of `"Action"`

**Problem:** Adding action but IDE doesn't show autocomplete
- Check: Did you add it to both the constant table AND the exported type?
- Fix: Update both `YourFeature = { NewAction = "NewAction" }` AND `export type YourFeatureAction = "..." | "NewAction"`

### Benefits Summary

✅ **Type Safety** - Catch typos and type mismatches at compile-time
✅ **Single Source of Truth** - Action strings defined once, used everywhere
✅ **IDE Autocomplete** - Type `IntentActions.` and see all features and actions
✅ **Refactoring Safety** - Change once, errors guide you to all usages
✅ **Self-Documenting** - Types show valid actions at a glance
✅ **Complete MVC Type Safety** - From view through controller with zero runtime overhead
✅ **Consistent Pattern** - All controllers use the same approach

### Understanding Type Safety: Compile-Time vs Runtime

It's important to understand the distinction between compile-time type checking and runtime behavior in the IntentActions pattern.

#### What Happens at Compile-Time

When you write code with type annotations:

```lua
self.remoteEvent.OnServerEvent:Connect(function(player: Player, action: IntentActions.CashMachineAction, amount: number)
    -- Luau's type checker validates your code
end)
```

**Compile-time benefits:**
- Luau validates that `action` is used consistently with the `CashMachineAction` type
- Your IDE provides autocomplete for valid actions
- Type errors are caught during development, not in production
- Refactoring tools can find all usages of a specific action type

**What types DON'T do:**
- They don't prevent clients from sending arbitrary data
- They don't exist at runtime (type erasure)
- They don't validate network input

#### What Happens at Runtime

When a client fires a RemoteEvent:

```lua
-- Client sends:
cashMachineIntent:FireServer("Withdraw", 50)

-- Network transmits:
[PlayerInstance] "Withdraw" 50

-- Server receives:
function(player, action, amount)
    -- action is just a string - could be anything!
end
```

**Runtime reality:**
- All type annotations are erased - `action: IntentActions.CashMachineAction` becomes just `action`
- The value is a plain string that the client sent
- A malicious client could send `"HackAction"` or any other string
- **No automatic validation happens from the type system**

#### Where Real Validation Happens

The ACTIONS table pattern provides your runtime security:

```lua
local ACTIONS = {
    [IntentActions.CashMachine.Withdraw] = withdraw,
    [IntentActions.CashMachine.Deposit] = deposit,
}

-- In AbstractController.dispatchAction:
local actionFunc = actionsTable[action]
if not actionFunc then
    warn("Invalid action: " .. tostring(action))  -- Runtime validation!
    return
end
```

**This table lookup is your actual security:**
- If `action` isn't a key in the table, `actionFunc` is `nil`
- The `if not actionFunc` check catches invalid actions
- Only actions you explicitly defined in ACTIONS can execute

#### Two-Layer Defense Strategy

The IntentActions pattern provides defense in depth:

**Layer 1: Compile-Time Types (Developer Safety)**
- Catches typos and mistakes during development
- Provides IDE support and documentation
- Prevents internal bugs in your own code
- Makes refactoring safer

**Layer 2: Runtime Validation (Security)**
- ACTIONS table lookup rejects invalid actions
- Parameter validation (like `amount <= 0` checks)
- Protects against malicious clients
- Provides actual security guarantees

#### Example: The Complete Flow

```lua
-- CLIENT: View code (compile-time checking)
cashMachineIntent:FireServer(
    IntentActions.CashMachine.Withdraw,  -- Luau knows this is "Withdraw"
    50
)

-- NETWORK: What actually transmits
-- Just the string "Withdraw" and number 50

-- SERVER: Controller receives (compile-time + runtime)
self.remoteEvent.OnServerEvent:Connect(function(
    player: Player,
    action: IntentActions.CashMachineAction,  -- Compile-time: helps you write correct code
    amount: number
)
    -- Runtime validation
    if amount <= 0 then
        warn("Invalid amount")
        return
    end

    -- Runtime security via table lookup
    self:dispatchAction(ACTIONS, action, player, inventory, amount, player)
    -- If action isn't in ACTIONS, dispatchAction warns and returns
end)
```

#### Key Takeaway

**Types guide honest developers to write correct code. Runtime validation protects against malicious actors.**

Don't rely on types alone for security - always validate untrusted input at runtime. The IntentActions pattern gives you both: excellent developer experience through types, and robust security through table-based validation.

## Next Steps

After creating your controller:

1. **Create a Model** (`src/server/models/`) to store the game state your controller modifies
2. **Create a View** (`src/client/views/`) to display state and send intents to your controller
3. **Test the flow** end-to-end with both server and client scripts

See the main [README.md](README.md) for the complete MVC architecture overview.
