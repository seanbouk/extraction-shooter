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

- **`new()`**: Constructor for creating new instances
- **`fire()`**: Debug method that prints all instance properties

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

-- Add constructor, singleton, or factory methods here
function YourModel.new(): YourModel
	local self = AbstractModel.new() :: any
	setmetatable(self, YourModel)

	-- Initialize your properties
	self.propertyName = defaultValue

	return self :: YourModel
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
function YourModel.new(): YourModel
	local self = AbstractModel.new() :: any
	setmetatable(self, YourModel)

	-- Initialize properties

	return self :: YourModel
end
```

**Important**: Cast `AbstractModel.new()` to `any` to allow metatable manipulation without type errors.

### Step 4: Choose Your Instance Pattern

#### Option A: Regular Constructor (Multiple Instances)

Use when you need multiple independent instances:

```lua
function YourModel.new(): YourModel
	local self = AbstractModel.new() :: any
	setmetatable(self, YourModel)

	self.property = defaultValue

	return self :: YourModel
end

-- Usage:
local instance1 = YourModel.new()
local instance2 = YourModel.new()
```

#### Option B: Singleton Pattern (One Instance)

Use when you need exactly one shared instance across the entire game:

```lua
local instance: YourModel? = nil

function YourModel.get(): YourModel
	if instance == nil then
		local self = AbstractModel.new() :: any
		setmetatable(self, YourModel)

		self.property = defaultValue

		instance = self
	end

	return instance :: YourModel
end

-- Usage:
local instance = YourModel.get()
```

## Example: InventoryModel

The `InventoryModel.lua` file in `src/server/models/` demonstrates the singleton pattern:

### Features:
- Singleton pattern via `get()` method
- Properties: `gold: number`, `treasure: number`
- Custom method: `addGold(amount: number)`
- Inherits `fire()` from AbstractModel for debugging

### Testing:
See `src/server/InventoryTest.server.lua` for a complete example of how to:
- Get the singleton instance
- Modify properties
- Call methods
- Use inherited `fire()` for debugging
- Verify singleton behavior

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

local instance = YourModel.new() -- or .get() for singleton

-- Test your methods
instance:yourMethod()

-- Debug output
instance:fire()
```

## Best Practices

1. **Always use `--!strict`** for type safety
2. **Include the `& AbstractModel.AbstractModel`** in your type definition to avoid warnings
3. **Cast `AbstractModel.new()` to `any`** in your constructor
4. **Use singleton pattern** for global game state (leaderboards, game settings)
5. **Use regular constructors** for per-player or per-object state
6. **Use `fire()` for debugging** during development to inspect model state
7. **Define clear types** for all properties and method parameters

## Common Patterns

### Per-Player Model

```lua
local PlayerInventory = {}

function PlayerInventory.new(player: Player): PlayerInventory
	local self = AbstractModel.new() :: any
	setmetatable(self, PlayerInventory)

	self.player = player
	self.items = {}

	return self :: PlayerInventory
end
```

### Global Game State

```lua
local GameSettings = {}
local instance: GameSettings? = nil

function GameSettings.get(): GameSettings
	if instance == nil then
		local self = AbstractModel.new() :: any
		setmetatable(self, GameSettings)

		self.roundTime = 300
		self.maxPlayers = 12

		instance = self
	end

	return instance :: GameSettings
end
```

## Next Steps

After creating your model:

1. **Create a Controller** (`src/server/controllers/`) to handle user intents and update your model
2. **Create a View** (`src/client/views/`) to display model state to players
3. **Set up RemoteEvents** (`src/shared/events/`) for communication between client and server

See the main [README.md](README.md) for the complete MVC architecture overview.
