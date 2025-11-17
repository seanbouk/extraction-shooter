# Model Development Guide

This guide explains how to create Models in this Roblox MVC project.

## What is a Model?

Models represent the authoritative game state and live exclusively on the server. They are the single source of truth for all game data in your application.

## Architecture Overview

All models in this project follow an inheritance pattern based on `AbstractModel`:

- **AbstractModel**: Base class providing common functionality for all models
- **Concrete Models** (e.g., InventoryModel): Extend AbstractModel and add specific game logic

## Creating a New Model

### Step 1: Understand AbstractModel

All models inherit from `AbstractModel.lua` which provides:

- **`new(modelName: string, ownerId: string)`**: Constructor for creating new instances with model name and owner identifier
- **`get(ownerId: string)`**: Static method to get or create an instance for a specific owner
- **`remove(ownerId: string)`**: Static method to remove an instance (used for cleanup)
- **`fire(scope: "owner" | "all")`**: Broadcasts model state to clients and prints debug output
- **`ownerId: string`**: Property storing the unique identifier for the model owner
- **`remoteEvent: RemoteEvent`**: Auto-created RemoteEvent for state broadcasting (named `[ModelName]StateChanged`)

### Step 2: Create Your Model File

Create a new ModuleScript in `src/server/models/YourModel.lua`:

```lua
--!strict

local AbstractModel = require(script.Parent.AbstractModel)

local YourModel = {}
YourModel.__index = YourModel
setmetatable(YourModel, AbstractModel)

export type YourModel = typeof(setmetatable({} :: {
	-- Define your model's properties here
	propertyName: propertyType,
}, YourModel)) & AbstractModel.AbstractModel

-- Registry to store instances per owner
local instances: { [string]: YourModel } = {}

function YourModel.new(ownerId: string): YourModel
	local self = AbstractModel.new("YourModel", ownerId) :: any
	setmetatable(self, YourModel)

	-- Initialize your properties
	self.propertyName = defaultValue

	return self :: YourModel
end

function YourModel.get(ownerId: string): YourModel
	if instances[ownerId] == nil then
		instances[ownerId] = YourModel.new(ownerId)
	end
	return instances[ownerId]
end

function YourModel.remove(ownerId: string): ()
	instances[ownerId] = nil
end

-- Add your model's methods here
function YourModel:yourMethod(): ()
	-- Implementation
end

return YourModel
```

### Step 3: Key Pattern Requirements

#### Inheritance Setup

```lua
setmetatable(YourModel, AbstractModel)
```

This line establishes the inheritance chain so your model inherits from AbstractModel.

#### Type Definition

```lua
export type YourModel = typeof(setmetatable({} :: {
	-- Your properties
}, YourModel)) & AbstractModel.AbstractModel
```

The `& AbstractModel.AbstractModel` ensures proper type inheritance and eliminates type warnings.

#### Constructor Pattern

```lua
function YourModel.new(ownerId: string): YourModel
	local self = AbstractModel.new("YourModel", ownerId) :: any
	setmetatable(self, YourModel)

	-- Initialize properties

	return self :: YourModel
end
```

**Important**:
- Pass the model name (e.g., `"YourModel"`) as the first parameter to `AbstractModel.new()`
- This creates a RemoteEvent named `YourStateChanged` in `ReplicatedStorage/Shared/Events/`
- Pass `ownerId` as the second parameter
- Cast `AbstractModel.new()` to `any` to allow metatable manipulation without type errors

### Step 4: Implement Per-Owner Registry Pattern

All models should use the per-owner registry pattern for proper instance management:

```lua
-- Registry to store instances per owner
local instances: { [string]: YourModel } = {}

function YourModel.get(ownerId: string): YourModel
	if instances[ownerId] == nil then
		instances[ownerId] = YourModel.new(ownerId)
	end
	return instances[ownerId]
end

function YourModel.remove(ownerId: string): ()
	instances[ownerId] = nil
end

-- Usage from a controller:
local playerModel = YourModel.get(tostring(player.UserId))
```

**Benefits:**
- Each owner (player, team, etc.) gets their own model instance
- Lazy initialization - instances created only when needed
- Proper cleanup via `remove()` prevents memory leaks
- Universal pattern works for players and other game entities

### Step 5: Broadcasting State Changes to Clients

Models automatically broadcast their state to clients using the `fire()` method. Every model method that changes state should call `fire()` with an explicit scope:

```lua
function YourModel:updateProperty(newValue): ()
	self.propertyName = newValue
	self:fire("owner")  -- Broadcast to owning player only
end

function YourModel:updatePublicProperty(newValue): ()
	self.publicProperty = newValue
	self:fire("all")  -- Broadcast to all connected players
end
```

#### Broadcast Scopes

- **`"owner"`**: Sends state only to the owning player using `FireClient(player, modelData)`
  - Use for private data: inventory, quest progress, personal stats
  - Most common for player-specific models

- **`"all"`**: Sends state to all connected players using `FireAllClients(modelData)`
  - Use for public data: equipped weapons, appearance, health (visible to others)
  - Use when other players need to see the change

**Important**: The `scope` parameter is **required**. There is no default to force explicit decisions about data visibility.

#### Example: Private vs Public Data

```lua
-- Private: Only the player should see their gold
function InventoryModel:addGold(amount: number): ()
	self.gold += amount
	self:fire("owner")
end

-- Public: Everyone should see the equipped weapon
function AppearanceModel:setWeapon(weaponId: string): ()
	self.equippedWeapon = weaponId
	self:fire("all")
end

-- Public: Everyone should see health changes
function HealthModel:takeDamage(amount: number): ()
	self.health -= amount
	self:fire("all")
end
```

#### How It Works

1. When `fire()` is called, AbstractModel broadcasts the **entire model state** to clients
2. A RemoteEvent named `[ModelName]StateChanged` is automatically created in `ReplicatedStorage/Shared/Events/`
3. Client-side Views listen to this RemoteEvent and update the UI
4. Views filter updates by `ownerId` to display only relevant data

## Example: InventoryModel

The `InventoryModel.lua` file in `src/server/models/` demonstrates the per-owner registry pattern and state broadcasting:

### Features:
- Per-owner registry pattern via `get(ownerId)` method
- Properties: `gold: number`, `treasure: number`, `ownerId: string`
- Custom method: `addGold(amount: number)` - broadcasts with `"owner"` scope
- State broadcasting: Automatically creates `InventoryStateChanged` RemoteEvent
- Inherits `fire()` from AbstractModel for debugging and client synchronization
- Cleanup method: `remove(ownerId)` for player lifecycle management

### Usage in Production:
Models are initialized automatically when players join:
- `ControllerRunner.server.lua` creates inventories in the PlayerAdded handler
- Controllers access instances via `InventoryModel.get(ownerId)`
- Properties can be modified directly or through custom methods
- State changes are automatically broadcast to clients via RemoteEvents
- Cleanup happens automatically in the PlayerRemoving handler

## File Locations

- **AbstractModel**: `src/server/models/AbstractModel.lua`
- **Your Models**: `src/server/models/YourModel.lua`
- **Test Scripts**: `src/server/YourModelTest.server.lua`

## Testing Your Model

Create a test script in `src/server/` to verify your model:

```lua
--!strict

local YourModel = require(script.Parent.models.YourModel)

print("\n--- Testing YourModel ---")

-- Test per-owner instances
local owner1 = YourModel.get("owner1")
local owner2 = YourModel.get("owner2")

-- Test your methods
owner1:yourMethod()

-- Verify instances are different
print("owner1 == owner2:", owner1 == owner2) -- Should be false

-- Debug output
owner1:fire()
owner2:fire()

-- Test cleanup
YourModel.remove("owner1")
```

## Best Practices

1. **Always use `--!strict`** for type safety
2. **Include the `& AbstractModel.AbstractModel`** in your type definition to avoid warnings
3. **Pass model name first** to `AbstractModel.new("YourModel", ownerId)` - this creates the RemoteEvent
4. **Cast `AbstractModel.new()` to `any`** in your constructor
5. **Use per-owner registry pattern** for player-specific or entity-specific state
6. **Use player.UserId as owner ID** for player-owned models: `tostring(player.UserId)`
7. **Implement cleanup** in player lifecycle events (PlayerRemoving)
8. **Always call `fire()` with explicit scope** - `"owner"` for private data, `"all"` for public data
9. **Think about data visibility** - Does this state need to be visible to other players?
10. **Use `fire()` for debugging** during development to inspect model state
11. **Define clear types** for all properties and method parameters

## Common Patterns

### Per-Player Model with Registry

```lua
local PlayerInventory = {}
local instances: { [string]: PlayerInventory } = {}

function PlayerInventory.new(ownerId: string): PlayerInventory
	local self = AbstractModel.new("PlayerInventory", ownerId) :: any
	setmetatable(self, PlayerInventory)

	self.items = {}

	return self :: PlayerInventory
end

function PlayerInventory.get(ownerId: string): PlayerInventory
	if instances[ownerId] == nil then
		instances[ownerId] = PlayerInventory.new(ownerId)
	end
	return instances[ownerId]
end

function PlayerInventory.remove(ownerId: string): ()
	instances[ownerId] = nil
end

-- Usage in controller:
local inventory = PlayerInventory.get(tostring(player.UserId))
```

### Player Lifecycle Management

Add to `ControllerRunner.server.lua` to clean up models when players leave:

```lua
local Players = game:GetService("Players")

Players.PlayerRemoving:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	YourModel.remove(ownerId)
	print("Cleaned up models for player " .. player.Name)
end)
```

## Next Steps

After creating your model:

1. **Create a Controller** (`src/server/controllers/`) to handle user intents and update your model
2. **Create a View** (`src/client/views/`) to display model state to players
3. **Set up RemoteEvents** (`src/shared/events/`) for communication between client and server

See the main [README.md](README.md) for the complete MVC architecture overview.
