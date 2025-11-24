# Model Development Guide

This guide explains how to create Models in this Roblox MVC project.

## What is a Model?

Models represent the authoritative game state and live exclusively on the server. They are the single source of truth for all game data in your application.

## Architecture Overview

All models in this project follow an inheritance pattern based on `AbstractModel`:

- **AbstractModel**: Base class providing common functionality for all models
- **Concrete Models** (e.g., InventoryModel): Extend AbstractModel and add specific game logic

## Model Scopes

Models can have different scopes that determine their lifecycle and ownership:

### User-Scoped Models (`models/user/`)

User-scoped models are **per-player** and **persistent** (saved to DataStore):

- **Lifecycle**: Created when player joins, destroyed when player leaves
- **Persistence**: Automatically saved to DataStore
- **Owner ID**: Player's UserId (e.g., "123456789")
- **Use Cases**: Inventory, quests, player settings, progress
- **Example**: `InventoryModel` - each player has their own gold/treasure

### Server-Scoped Models (`models/server/`)

Server-scoped models are **per-server instance** and **ephemeral** (not saved):

- **Lifecycle**: Created once when server starts, persists until server shutdown
- **Persistence**: None - data resets when server restarts
- **Owner ID**: Fixed string "SERVER"
- **Use Cases**: Match state, server events, shared game state
- **Example**: `ShrineModel` - shared by all players in the server

### Choosing a Scope

| Scope | Location | Persistent | Per-Player | Use For |
|-------|----------|------------|------------|---------|
| **User** | `models/user/` | ✅ Yes | ✅ Yes | Player inventory, progress, settings |
| **Server** | `models/server/` | ❌ No | ❌ No | Match scores, timers, shared game state |

## Creating a New Model

### Step 1: Understand AbstractModel

All models inherit from `AbstractModel.lua` which provides:

- **`new(modelName: string, ownerId: string, scope: ModelScope)`**: Constructor for creating new instances with model name, owner identifier, and scope
- **`getOrCreate(modelName: string, ownerId: string, constructorFn: () -> AbstractModel)`**: Centralized registry management - gets existing instance or creates new one
- **`removeInstance(modelName: string, ownerId: string)`**: Centralized instance removal for cleanup
- **`fire(scope: "owner" | "all")`**: Broadcasts model state to clients and prints debug output
- **`ownerId: string`**: Property storing the unique identifier for the model owner
- **`remoteEvent: RemoteEvent`**: Auto-created RemoteEvent for state broadcasting (named `[ModelName]StateChanged`)

### Step 2: Determine Model Scope

#### Decision Tree: Choosing the Right Model Scope

Use this decision tree to determine which scope your model needs:

**Question 1: Does each player have their own separate copy of this data?**
- **Yes** → User-scoped (continue to Question 2)
- **No** → Go to Question 3

**Question 2: Should this data persist across server restarts and player sessions?**
- **Yes** → **User-scoped** (place in `models/user/`)
- **No** → User-scoped still appropriate if data is per-player but ephemeral

**Question 3: Is this data shared across all players in the server?**
- **Yes** → **Server-scoped** (place in `models/server/`)
- **No** → Reconsider Question 1 - data might be per-player after all

**Examples:**

✅ **User-scoped** (per-player, persistent):
- Player's inventory (gold, items, weapons)
- Quest progress and achievements
- Player settings and preferences
- Character stats and levels
- Owned cosmetics

✅ **Server-scoped** (shared, ephemeral):
- Match timer for all players
- Shared shrine donations (ShrineModel example)
- Current round number
- Server-wide events
- Leaderboard for current session

❌ **Common mistakes:**
- Making inventory Server-scoped (each player needs their own!)
- Making match timer User-scoped (all players should see the same timer!)
- Expecting Server-scoped data to persist (it won't - that's by design!)

#### Scope Selection Guidelines

Before creating your model, decide which scope it needs:

- **User-Scoped**: Place in `src/server/models/user/YourModel.lua` and pass `"User"` to AbstractModel
- **Server-Scoped**: Place in `src/server/models/server/YourModel.lua` and pass `"Server"` to AbstractModel

### Step 3: Create Your Model File

#### For User-Scoped Models (`models/user/YourModel.lua`):

```lua
--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local YourModel = {}
YourModel.__index = YourModel
setmetatable(YourModel, AbstractModel)

export type YourModel = typeof(setmetatable({} :: {
	-- Define your model's properties here
	propertyName: propertyType,
}, YourModel)) & AbstractModel.AbstractModel

function YourModel.new(ownerId: string): YourModel
	local self = AbstractModel.new("YourModel", ownerId, "User") :: any
	setmetatable(self, YourModel)

	-- Initialize your properties
	self.propertyName = defaultValue

	return self :: YourModel
end

function YourModel.get(ownerId: string): YourModel
	return AbstractModel.getOrCreate("YourModel", ownerId, function()
		return YourModel.new(ownerId)
	end) :: YourModel
end

function YourModel.remove(ownerId: string): ()
	AbstractModel.removeInstance("YourModel", ownerId)
end

-- Add your model's methods here
function YourModel:yourMethod(): ()
	-- Implementation
	self:fire("owner") -- User-scoped models typically broadcast to owner
end

return YourModel
```

#### For Server-Scoped Models (`models/server/YourModel.lua`):

```lua
--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)

local YourModel = {}
YourModel.__index = YourModel
setmetatable(YourModel, AbstractModel)

export type YourModel = typeof(setmetatable({} :: {
	-- Define your model's properties here
	propertyName: propertyType,
}, YourModel)) & AbstractModel.AbstractModel

function YourModel.new(ownerId: string): YourModel
	local self = AbstractModel.new("YourModel", ownerId, "Server") :: any
	setmetatable(self, YourModel)

	-- Initialize your properties
	self.propertyName = defaultValue

	return self :: YourModel
end

function YourModel.get(ownerId: string): YourModel
	return AbstractModel.getOrCreate("YourModel", ownerId, function()
		return YourModel.new(ownerId)
	end) :: YourModel
end

function YourModel.remove(ownerId: string): ()
	AbstractModel.removeInstance("YourModel", ownerId)
end

-- Add your model's methods here
function YourModel:yourMethod(): ()
	-- Implementation
	self:fire("all") -- Server-scoped models typically broadcast to all
end

return YourModel
```

**Key Differences:**
- Require path: `script.Parent.Parent.AbstractModel` (up two levels from `user/` or `server/`)
- Scope parameter: `"User"` for user-scoped, `"Server"` for server-scoped
- Access pattern: User-scoped uses player UserId, Server-scoped uses `"SERVER"`
- Broadcast: User-scoped typically uses `"owner"`, Server-scoped typically uses `"all"`

### Step 4: Key Pattern Requirements

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
	local self = AbstractModel.new("YourModel", ownerId, "User") :: any
	setmetatable(self, YourModel)

	-- Initialize properties

	return self :: YourModel
end
```

**Important**:
- Pass the model name (e.g., `"YourModel"`) as the first parameter to `AbstractModel.new()`
- This creates a RemoteEvent named `YourStateChanged` in `ReplicatedStorage/Shared/Events/`
- Event names should be registered in `src/shared/StateEvents.lua` for type safety
- Pass `ownerId` as the second parameter
- Pass the scope (`"User"` or `"Server"`) as the third parameter
- Cast `AbstractModel.new()` to `any` to allow metatable manipulation without type errors

**Type Safety Tip:**
Define your model's state data type in `src/shared/StateEvents.lua` so views can use type-safe handlers:

```lua
-- In StateEvents.lua
export type YourModelData = {
    ownerId: string,
    property1: number,
    property2: string,
}

-- Views can then use:
stateChanged.OnClientEvent:Connect(function(data: StateEvents.YourModelData)
    -- Type-safe handling
end)
```

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
	AbstractModel.removeInstance("YourModel", ownerId)
end

-- Usage from a controller (User-scoped):
local playerModel = YourModel.get(tostring(player.UserId))

-- Usage from a controller (Server-scoped):
local sharedModel = YourModel.get("SERVER")
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
4. For "owner" scope, the server uses `FireClient(player, modelData)` which already ensures only the owner receives the event - Views don't need to filter. For "all" scope, Views may need to filter by `ownerId` if they only want to display data relevant to the local player.

## Examples

### Example 1: InventoryModel (User-Scoped)

The `InventoryModel.lua` file in `src/server/models/user/` demonstrates a User-scoped model with per-owner registry pattern and state broadcasting:

### Features:
- Per-owner registry pattern via `get(ownerId)` method
- Properties: `gold: number`, `treasure: number`, `ownerId: string`
- Custom method: `addGold(amount: number)` - broadcasts with `"owner"` scope
- State broadcasting: Automatically creates `InventoryStateChanged` RemoteEvent
- Inherits `fire()` from AbstractModel for debugging and client synchronization
- Cleanup method: `remove(ownerId)` for player lifecycle management

### Usage in Production:
User-scoped models are initialized automatically when players join:
- `ModelRunner.server.lua` creates inventories in the PlayerAdded handler
- Controllers access instances via `InventoryModel.get(tostring(player.UserId))`
- Properties can be modified directly or through custom methods
- State changes are automatically broadcast to clients via RemoteEvents
- Cleanup happens automatically in the PlayerRemoving handler

### Example 2: ShrineModel (Server-Scoped)

The `ShrineModel.lua` file in `src/server/models/server/` demonstrates a Server-scoped model:

### Features:
- Server-scoped (single instance shared by all players)
- Properties: `treasure: number`, `userID: string`
- Custom method: `donate(playerUserId: string, amount: number)` - broadcasts with `"all"` scope
- State broadcasting: Automatically creates `ShrineStateChanged` RemoteEvent
- Ephemeral: Data resets when server restarts (no DataStore persistence)
- Access pattern: `ShrineModel.get("SERVER")` returns the shared instance

### Usage in Production:
Server-scoped models are initialized once when the server starts:
- `ModelRunner.server.lua` creates the server instance on startup
- Controllers access the shared instance via `ShrineModel.get("SERVER")`
- All players interact with the same model instance
- State changes broadcast to all clients via `fire("all")`
- No cleanup on player leave (persists for server lifetime)

## File Locations

- **AbstractModel**: `src/server/models/AbstractModel.lua`
- **ModelRunner**: `src/server/models/ModelRunner.server.lua`
- **User-Scoped Models**: `src/server/models/user/YourModel.lua`
- **Server-Scoped Models**: `src/server/models/server/YourModel.lua`
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

Player lifecycle is automatically handled by `ModelRunner.server.lua` in the `models/` folder. The ModelRunner:

- **Auto-discovers** all models in `models/user/` and `models/server/` folders
- **Server-scoped models**: Initialized once on server startup with ownerId "SERVER"
- **User-scoped models**: Initialized when players join (PlayerAdded event)
- **Loads** saved data from DataStore via PersistenceServer (User-scoped only; kicks player if load fails)
- **Applies** loaded data to model instances (or uses defaults for new players)
- **Cleans up** User-scoped model instances when players leave (PlayerRemoving event)
- **Server-scoped models**: Persist for server lifetime (no per-player cleanup)

```lua
--!strict

local Players = game:GetService("Players")

-- Initialize PersistenceServer before any models are used
local PersistenceServer = require(script.Parent.Parent.services.PersistenceServer)
PersistenceServer.init()

-- Auto-discover and require all models (skip Abstract)
local modelsFolder = script.Parent
local models = {}

type ModelClass = {
	get: (ownerId: string) -> any,
	remove: (ownerId: string) -> (),
}

type ModelScope = "User" | "Server"

type ModelInfo = {
	class: ModelClass,
	name: string,
	scope: ModelScope,
}

local modelInfos: { ModelInfo } = {}

-- Helper function to discover models in a folder with a specific scope
local function discoverModelsInFolder(folder: Instance, scope: ModelScope)
	for _, moduleScript in folder:GetChildren() do
		if moduleScript:IsA("ModuleScript") and not moduleScript.Name:find("^Abstract") then
			local model = require(moduleScript) :: ModelClass
			table.insert(models, model)
			table.insert(modelInfos, {
				class = model,
				name = moduleScript.Name,
				scope = scope,
			})
			print("ModelRunner: Discovered " .. scope .. "-scoped model - " .. moduleScript.Name)
		end
	end
end

-- Discover User-scoped models
local userFolder = modelsFolder:FindFirstChild("user")
if userFolder then
	discoverModelsInFolder(userFolder, "User")
end

-- Discover Server-scoped models
local serverFolder = modelsFolder:FindFirstChild("server")
if serverFolder then
	discoverModelsInFolder(serverFolder, "Server")
end

-- Initialize Server-scoped models once (ephemeral, shared by all players)
print("ModelRunner: Initializing Server-scoped models")
for _, modelInfo in modelInfos do
	if modelInfo.scope == "Server" then
		local instance = modelInfo.class.get("SERVER")
		print("ModelRunner: Initialized Server-scoped model - " .. modelInfo.name)
	end
end

-- Handle player initialization
Players.PlayerAdded:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Initializing models for player " .. player.Name)

	for _, modelInfo in modelInfos do
		-- Only initialize User-scoped models per player
		if modelInfo.scope == "User" then
			-- Load data from DataStore for this model
			local success, loadedData = PersistenceServer:loadModel(modelInfo.name, ownerId)

			-- If load failed, kick the player to prevent data loss
			if not success then
				player:Kick("Roblox servers are busy right now. Please rejoin to try again. Your progress is safe!")
				return -- Stop processing this player
			end

			-- Get or create model instance for this player (with defaults)
			local instance = modelInfo.class.get(ownerId)

			-- Apply loaded data if it exists (overwrites defaults)
			if loadedData then
				instance:_applyLoadedData(loadedData)
			end

			-- Don't fire initial state here - client will request when ready
			-- This prevents race condition where RemoteEvent hasn't replicated yet
		end
	end
end)

-- Handle player cleanup
Players.PlayerRemoving:Connect(function(player: Player)
	local ownerId = tostring(player.UserId)
	print("ModelRunner: Cleaning up models for player " .. player.Name)

	-- Only remove User-scoped models (Server-scoped persist for server lifetime)
	for _, modelInfo in modelInfos do
		if modelInfo.scope == "User" then
			modelInfo.class.remove(ownerId)
		end
	end
end)
```

**Important**: You don't need to manually add your model to ModelRunner. Simply create it in the `models/user/` or `models/server/` folder and it will be automatically discovered and managed.

## Working with StateEvents

When you create a new model that broadcasts state to clients, you should add it to the `StateEvents` module for type-safe state synchronization.

### What are StateEvents?

StateEvents is a centralized module (`src/shared/StateEvents.lua`) that provides:
- **Event name constants** - Single source of truth for RemoteEvent names
- **Exported data types** - Type-safe state data structures for views
- **Complete MVC type safety** - From model through view

### When to Add a New State Event

Add a new state event to StateEvents when:
- ✅ You create a new model that broadcasts state to clients
- ✅ Views need to observe changes in a model's state
- ✅ You want type-safe state synchronization between server and client

### When to Reuse an Existing State Event

Reuse an existing event when:
- ✅ Multiple views observe the same model (e.g., StatusBarView and InventoryUIView both use InventoryStateChanged)
- ✅ Data structure is the same, just different UI presentation

### Step-by-Step: Adding a New State Event

**1. Open `src/shared/StateEvents.lua`**

**2. Add event name constant:**

Match your model name exactly (AbstractModel uses this for auto-creation):

```lua
local StateEvents = {
    -- ... existing events ...
    YourModel = {
        EventName = "YourModelStateChanged",
    },
}
```

**Naming convention:** `[ModelName]StateChanged` (e.g., "InventoryStateChanged", "ShrineStateChanged")

**3. Add exported data type:**

Match your model's properties that views need to observe:

```lua
-- ... existing type exports ...
export type YourModelData = {
    ownerId: string,  -- ALWAYS include (required for filtering)
    property1: type,
    property2: type,
}
```

**4. Return the module:**

```lua
return StateEvents
```

### State Data Type Guidelines

**Always include:**
- `ownerId: string` - Required for filtering, even if not always used by views

**Include properties that:**
- ✅ Views need to display (e.g., gold amount, treasure count)
- ✅ Change over time (e.g., health, score, progress)
- ✅ Are broadcast by the model (via `self:fire()`)

**Don't include:**
- ❌ Internal model state that clients never see
- ❌ Computed values that views calculate themselves (unless expensive)
- ❌ Sensitive data that shouldn't be visible to clients

### Example: InventoryModel State Event

**In StateEvents.lua:**

```lua
Inventory = {
    EventName = "InventoryStateChanged",
},

export type InventoryData = {
    ownerId: string,
    gold: number,
    treasure: number,
}
```

**How it's used:**

1. **AbstractModel auto-creates RemoteEvent:**
   - `AbstractModel.new("InventoryModel", ...)` creates RemoteEvent "InventoryStateChanged"
   - Event is placed in ReplicatedStorage → Events

2. **Model broadcasts state:**
   ```lua
   function InventoryModel:addGold(amount: number): ()
       self.gold += amount
       self:fire("owner")  -- Broadcasts InventoryData to owner
   end
   ```

3. **Views observe state with type safety:**
   ```lua
   local StateEvents = require(ReplicatedStorage.Shared.StateEvents)
   local inventoryStateChanged = eventsFolder:WaitForChild(StateEvents.Inventory.EventName)

   inventoryStateChanged.OnClientEvent:Connect(function(data: StateEvents.InventoryData)
       -- Type-safe! Luau knows: data.gold (number), data.treasure (number)
       updateLabels(data.gold, data.treasure)
   end)
   ```

### Example: ShrineModel State Event (Server-Scoped)

**In StateEvents.lua:**

```lua
Shrine = {
    EventName = "ShrineStateChanged",
},

export type ShrineData = {
    ownerId: string,  -- For server-scoped, use "SERVER"
    treasure: number,
    userId: string,  -- Last donor
}
```

**Key difference for Server-scoped models:**
- `ownerId` is always "SERVER" (not a player UserId)
- Typically broadcast with `fire("all")` since data is shared
- All clients receive the same state

### Common Patterns

#### User-Scoped Model (Private Data)

```lua
-- StateEvents.lua
PlayerQuest = {
    EventName = "PlayerQuestStateChanged",
},

export type PlayerQuestData = {
    ownerId: string,
    questId: string,
    progress: number,
    isComplete: boolean,
}

-- Model broadcasts with fire("owner") - only that player sees it
```

#### Server-Scoped Model (Public Data)

```lua
-- StateEvents.lua
MatchTimer = {
    EventName = "MatchTimerStateChanged",
},

export type MatchTimerData = {
    ownerId: string,  -- "SERVER"
    timeRemaining: number,
    matchState: string,
}

-- Model broadcasts with fire("all") - all players see it
```

### Troubleshooting

**Problem:** Views not receiving state updates
- Check: Does event name match model name? (`InventoryModel` → `"InventoryStateChanged"`)
- Check: Is the type exported from StateEvents.lua?
- Check: Are you using `StateEvents.ModelName.EventName` in view?

**Problem:** Type errors in view
- Check: Did you export the data type? (`export type ModelData = {...}`)
- Check: Are you using the correct type annotation? (`data: StateEvents.ModelData`)
- Check: Do the properties match your model's actual properties?

**Problem:** Wrong players receiving state
- Check: Are you using correct scope in `fire()`? ("owner" vs "all")
- Check: Is ownerId filtering applied correctly in view? (Usually not needed!)
- Check: For user-scoped models, fire("owner") already filters to that player

### Benefits of Using StateEvents

✅ **Type Safety** - Catch typos and type mismatches at compile-time
✅ **Single Source of Truth** - Event names defined once, used everywhere
✅ **IDE Autocomplete** - Type `StateEvents.` and see all available events
✅ **Refactoring Safety** - Change once, errors guide you to all usages
✅ **Self-Documenting** - Types show what data models broadcast
✅ **Complete MVC Type Safety** - From model through view with zero runtime overhead

## Next Steps

After creating your model:

1. **Create a Controller** (`src/server/controllers/`) to handle user intents and update your model
2. **Create a View** (`src/client/views/`) to display model state to players
3. **Set up RemoteEvents** (`src/shared/events/`) for communication between client and server

See the main [README.md](README.md) for the complete MVC architecture overview.
