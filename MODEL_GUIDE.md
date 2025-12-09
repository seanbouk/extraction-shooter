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

### Entity-Scoped Models (`models/entity/`)

Entity-scoped models are **per-player instances** and **persistent** (saved to DataStore):

- **Lifecycle**: Multiple instances per player, created on-demand, destroyed when player leaves
- **Persistence**: Automatically saved to DataStore with composite keys (ModelName_UserId_ModelId)
- **Owner ID**: Composite key of UserId + ModelId (e.g., "123456789_pet1")
- **Use Cases**: Pets, player-owned bases, character slots, equipment slots, squadmates
- **Example**: `PetModel` - each player can have multiple pets (pet1, pet2, pet3, etc.)
- **ID Strategy**: Application-specific - sequential numbers, UUIDs, or semantic identifiers

### Choosing a Scope

| Scope | Location | Persistent | Per-Player | Multiple Instances | Use For |
|-------|----------|------------|------------|-------------------|---------|
| **User** | `models/user/` | ✅ Yes | ✅ Yes | ❌ One per player | Player inventory, progress, settings |
| **Server** | `models/server/` | ❌ No | ❌ No | ❌ One for server | Match scores, timers, shared game state |
| **Entity** | `models/entity/` | ✅ Yes | ✅ Yes | ✅ Many per player | Pets, bases, character slots, equipment |

## Creating a New Model

### Step 1: Understand AbstractModel

All models inherit from `AbstractModel.lua` which provides:

- **`new(modelName: string, ownerId: string, scope: ModelScope)`**: Constructor for creating new instances with model name, owner identifier, and scope
- **`getOrCreate(modelName: string, ownerId: string, constructorFn: () -> AbstractModel)`**: Centralized registry management - gets existing instance or creates new one
- **`removeInstance(modelName: string, ownerId: string)`**: Centralized instance removal for cleanup
- **`syncState(skipPersistence: boolean?)`**: Syncs model state to clients via Bolt RemoteProperty and triggers DataStore persistence (User-scoped only). Automatically detects scope for filtering.
- **`ownerId: string`**: Property storing the unique identifier for the model owner
- **`_stateProperty: RemoteProperty`**: Bolt RemoteProperty for state synchronization (registered via Network.registerState())

### Step 2: Determine Model Scope

#### Decision Tree: Choosing the Right Model Scope

Use this decision tree to determine which scope your model needs:

**Question 1: Does each player need multiple instances of this data?**
- **Yes** → **Entity-scoped** (place in `models/entity/`)
  - Player has multiple pets: EntityModel
  - Player has multiple bases: EntityModel
  - Player has multiple character slots: EntityModel
- **No** → Continue to Question 2

**Question 2: Does each player have their own separate copy of this data?**
- **Yes** → User-scoped (continue to Question 3)
- **No** → Go to Question 4

**Question 3: Should this data persist across server restarts and player sessions?**
- **Yes** → **User-scoped** (place in `models/user/`)
- **No** → User-scoped still appropriate if data is per-player but ephemeral

**Question 4: Is this data shared across all players in the server?**
- **Yes** → **Server-scoped** (place in `models/server/`)
- **No** → Reconsider Question 2 - data might be per-player after all

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
	self:syncState() -- User-scoped models automatically sync to owner
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
	self:syncState() -- Server-scoped models automatically sync to all
end

return YourModel
```

#### For Entity-Scoped Models (`models/entity/YourModel.lua`):

```lua
--!strict

local AbstractModel = require(script.Parent.Parent.AbstractModel)
local PersistenceService = require(script.Parent.Parent.Parent.services.PersistenceService)

local YourModel = {}
YourModel.__index = YourModel
setmetatable(YourModel, AbstractModel)

export type YourModel = typeof(setmetatable({} :: {
	-- Define your model's properties here
	propertyName: propertyType,
}, YourModel)) & AbstractModel.AbstractModel

function YourModel.new(ownerId: string, modelId: string): YourModel
	-- Entity models require both ownerId and modelId
	-- Optional: Pass "all" as 5th parameter for broadcast sync instead of owner-only
	local self = AbstractModel.new("YourModel", ownerId, "Entity", modelId) :: any
	setmetatable(self, YourModel)

	-- Initialize your properties
	self.propertyName = defaultValue

	return self :: YourModel
end

function YourModel.get(ownerId: string, modelId: string): YourModel
	return AbstractModel.getOrCreate("YourModel", ownerId, function()
		return YourModel.new(ownerId, modelId)
	end, modelId) :: YourModel
end

function YourModel.remove(ownerId: string, modelId: string): ()
	AbstractModel.removeInstance("YourModel", ownerId, modelId)
end

-- REQUIRED: Static method to load all entities for a player
-- Called by ModelRunner when player joins
function YourModel.loadAllForOwner(ownerId: string): boolean
	-- Get entity IDs for this player from somewhere (e.g., UserModel, external list, etc.)
	-- For example: local entityIds = UserModel.get(ownerId).yourModelIds
	local entityIds = {"1", "2", "3"} -- Example: sequential IDs

	-- Load each entity from DataStore
	for _, entityId in entityIds do
		local success, loadedData = PersistenceService:loadModel("YourModel", ownerId, entityId)

		if not success then
			return false -- Loading failed, player will be kicked
		end

		-- Create instance
		local entity = YourModel.get(ownerId, entityId)

		-- Apply loaded data if it exists
		if loadedData then
			entity:_applyLoadedData(loadedData)
		end

		-- Sync initial state (skip persistence since we just loaded)
		entity:syncState(true)
	end

	return true
end

-- REQUIRED: Static method to remove all entities for a player
-- Called by ModelRunner when player leaves
function YourModel.removeAllEntitiesForOwner(ownerId: string): ()
	AbstractModel.removeAllEntitiesForOwner("YourModel", ownerId)
end

-- Add your model's methods here
function YourModel:yourMethod(): ()
	-- Implementation
	self:syncState() -- Entity models default to owner-only sync
end

-- Example: Method that broadcasts to all players (requires "all" syncScope in constructor)
function YourModel:broadcastMethod(): ()
	-- Only works if you passed "all" as syncScope to AbstractModel.new()
	self:syncState() -- Will broadcast to all players
end

return YourModel
```

**Key Differences:**
- Require path: `script.Parent.Parent.AbstractModel` (up two levels from `user/`, `server/`, or `entity/`)
- Scope parameter: `"User"` for user-scoped, `"Server"` for server-scoped, `"Entity"` for entity-scoped
- Entity models require `modelId` parameter in constructor and all static methods
- Entity models must implement `loadAllForOwner()` and `removeAllEntitiesForOwner()` static methods
- Access pattern: User uses player UserId, Server uses `"SERVER"`, Entity uses composite `ownerId_modelId`
- Default sync: Entity models default to owner-only (like User), can override to "all" with 5th parameter to `new()`

### Step 3b: Entity ID Management Strategies

For Entity-scoped models, choosing an appropriate ID strategy is important. The framework doesn't prescribe a specific approach - select based on your application's needs:

#### Sequential Numeric IDs
**Pattern**: "1", "2", "3", "4", ...

**Advantages:**
- Simple and intuitive
- Natural ordering for display
- Short DataStore keys (reduces storage)
- Easy to debug

**Disadvantages:**
- Requires tracking highest ID per player
- Reusing IDs after deletion can cause confusion
- Not globally unique

**Best for:** Pets, equipment slots, save slots, bases

**Example:**
```lua
-- Store in UserModel
export type InventoryModel = typeof(setmetatable({} :: {
	nextPetId: number, -- Track next available ID
	petIds: {string}, -- List of active pet IDs
}, InventoryModel))

-- In controller when creating new pet
local inventory = InventoryModel.get(ownerId)
local petId = tostring(inventory.nextPetId)
inventory.nextPetId += 1
table.insert(inventory.petIds, petId)
inventory:syncState()

local pet = PetModel.get(ownerId, petId)
```

#### UUID/GUID Strategy
**Pattern**: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"

**Advantages:**
- Guaranteed globally unique
- No collision concerns
- Can be generated client-side or server-side
- No need to track counters

**Disadvantages:**
- Long DataStore keys (36+ characters)
- Not human-readable
- No natural ordering

**Best for:** Player-created items, user-generated content, items that can be traded

**Example:**
```lua
local HttpService = game:GetService("HttpService")

-- In controller when creating new item
local itemId = HttpService:GenerateGUID(false) -- false = no curly braces
local item = ItemModel.get(ownerId, itemId)
```

#### Semantic IDs
**Pattern**: "slot1", "slot2", "main_base", "secondary_base"

**Advantages:**
- Self-documenting
- Easy to understand in logs
- Can encode meaning (e.g., "equipped_helmet")
- Good for fixed-size collections

**Disadvantages:**
- Requires predefined naming scheme
- Can become complex with dynamic content
- Length varies

**Best for:** Fixed equipment slots, preset loadouts, specific roles

**Example:**
```lua
-- Fixed equipment slots
local slots = {"helmet", "chest", "legs", "weapon"}
for _, slotName in slots do
	local equipment = EquipmentModel.get(ownerId, slotName)
end
```

#### Hybrid Approach
**Pattern**: Combine strategies (e.g., "pet_1", "pet_2" or "2024-12-09_1")

**Advantages:**
- Balances readability and uniqueness
- Can include metadata in ID
- Flexible for different use cases

**Example:**
```lua
local timestamp = os.time()
local entityId = string.format("base_%d_%d", timestamp, counter)
```

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
- This retrieves a Bolt RemoteProperty via `Network.registerState()` for state synchronization
- **Prerequisite:** Add an entry to NetworkConfig.States in Network.luau first (NetworkBuilder auto-generates the RemoteProperty)
- State properties are accessed as `Network.State.Your` (model name without "Model" suffix)
- Pass `ownerId` as the second parameter
- Pass the scope (`"User"` or `"Server"`) as the third parameter
- Cast `AbstractModel.new()` to `any` to allow metatable manipulation without type errors

**Type Safety Tip:**
Define your model's state data type in Network.luau for type-safe observers:

```lua
-- In Network.luau NetworkConfig
States = {
    Your = {
        ownerId = "",
        property1 = 0,
        property2 = "",
    },
},

-- Add exported type
export type YourModelData = {
    ownerId: string,
    property1: number,
    property2: string,
}

-- Views can then use:
Network.State.Your:Observe(function(data: Network.YourModelData)
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

### Step 5: Syncing State Changes to Clients

Models automatically sync their state to clients using the `syncState()` method. Every model method that changes state should call `syncState()`:

```lua
function YourModel:updateProperty(newValue): ()
	self.propertyName = newValue
	self:syncState()  -- Sync to clients (scope auto-detected from model type)
end

function YourModel:updateWithoutPersistence(newValue): ()
	self.propertyName = newValue
	self:syncState(true)  -- Skip DataStore persistence (still syncs state)
end
```

#### Automatic Scope Detection

The `syncState()` method **automatically detects the appropriate broadcast scope** based on the model's scope type:

- **User-scoped models**: Automatically sync only to the owning player via `RemoteProperty:SetFor(player, state)`
  - Use for private data: inventory, quest progress, personal stats
  - Most common for player-specific models
  - Triggers DataStore persistence

- **Server-scoped models**: Automatically sync to all connected players via `RemoteProperty:Set(state)`
  - Use for shared data: match scores, server events, shared game state
  - Data visible to all players
  - Does not trigger persistence (Server-scoped models are ephemeral)

**Advantages of automatic scope detection:**
- ✅ No need to specify "owner" or "all" - determined by model type
- ✅ Fewer errors - can't accidentally broadcast private data to all players
- ✅ Cleaner code - single `syncState()` call for all models

#### Example: User vs Server Scoped

```lua
-- User-scoped model: Only the player sees their gold
function InventoryModel:addGold(amount: number): ()
	self.gold += amount
	self:syncState()  -- Automatically sends only to owner + persists to DataStore
end

-- Server-scoped model: Everyone sees the shared shrine donations
function ShrineModel:addDonation(donorName: string, amount: number): ()
	self.totalDonations += amount
	self.lastDonor = donorName
	self:syncState()  -- Automatically broadcasts to all players
end
```

#### How It Works

1. When `syncState()` is called, AbstractModel syncs the **entire model state** to clients via Bolt RemoteProperty
2. Bolt RemoteProperty registered via `Network.registerState()` in AbstractModel.new()
3. Client-side Views use `Network.State.ModelName:Observe()` to receive state updates
4. For User-scoped models, Bolt handles per-player filtering automatically via `SetFor(player, state)`
5. For Server-scoped models, Bolt broadcasts to all players via `Set(state)`
6. User-scoped models also trigger DataStore persistence via PersistenceService

## Examples

### Example 1: InventoryModel (User-Scoped)

The `InventoryModel.lua` file in `src/server/models/user/` demonstrates a User-scoped model with per-owner registry pattern and state broadcasting:

### Features:
- Per-owner registry pattern via `get(ownerId)` method
- Properties: `gold: number`, `treasure: number`, `ownerId: string`
- Custom method: `addGold(amount: number)` - broadcasts with `"owner"` scope
- State broadcasting: Automatically creates `InventoryStateChanged` RemoteEvent
- Inherits `syncState()` from AbstractModel for state synchronization
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
- State changes sync to all clients via `syncState()` (automatically broadcasts to all)
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
owner1:syncState()
owner2:syncState()

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
8. **Always call `syncState()` after state changes** - scope is automatically detected from model type
9. **Think about data visibility** - User-scoped models sync only to owner, Server-scoped sync to all
10. **Use `syncState()` for debugging** during development to inspect model state
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
- **Loads** saved data from DataStore via PersistenceService (User-scoped only; kicks player if load fails)
- **Applies** loaded data to model instances (or uses defaults for new players)
- **Cleans up** User-scoped model instances when players leave (PlayerRemoving event)
- **Server-scoped models**: Persist for server lifetime (no per-player cleanup)

```lua
--!strict

local Players = game:GetService("Players")

-- Initialize PersistenceService before any models are used
local PersistenceService = require(script.Parent.Parent.services.PersistenceService)
PersistenceService.init()

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
			local success, loadedData = PersistenceService:loadModel(modelInfo.name, ownerId)

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
- ✅ Are synced by the model (via `self:syncState()`)

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
       self:syncState()  -- Syncs InventoryData to owner (auto-detected scope)
   end
   ```

3. **Views observe state with type safety:**
   ```lua
   local StateEvents = require(ReplicatedStorage.StateEvents)
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
- Automatically sync to all clients via `syncState()` since scope is "Server"
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

-- Model syncs with syncState() - User-scoped so only owner sees it
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

-- Model syncs with syncState() - Server-scoped so all players see it
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
- Check: Is your model scope correct? (User vs Server in AbstractModel.new())
- Check: Bolt handles filtering automatically - User-scoped sends only to owner
- Check: Server-scoped models send to all players - this is expected behavior

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
