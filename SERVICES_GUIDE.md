# Services Guide

Services are server-side modules that run automatically to handle background tasks, scheduled operations, and system-wide functionality. Unlike controllers (which respond to user intents), services operate independently to maintain game state.

## What Are Services?

Services are "controllers that run automatically" - they don't wait for user input but instead:
- Run background loops to check/update state periodically
- Listen to system events (player join/leave, game lifecycle)
- Provide shared utilities for other server components

## Services vs Controllers

| Aspect | Services | Controllers |
|--------|----------|-------------|
| **Trigger** | Automatic (loops, events) | User intent (Bolt ReliableEvent) |
| **Purpose** | Background tasks, system operations | Handle user actions |
| **Initialization** | Auto-discovered by ServiceRunner (game/) or explicit (framework/) | Auto-discovered by ControllerRunner |
| **Player-specific** | Usually system-wide | Usually per-player |
| **Examples** | PersistenceService, CandleService | InventoryController, ShrineController |

## Service Categories

Services are organized into two folders based on initialization requirements:

### Framework Services (`services/framework/`)
Services that require explicit ordering or are dependencies for other systems:
- **PersistenceService** - Must initialize before any model is used
- **SlashCommandService** - Must initialize after models are discovered

Framework services are initialized explicitly by ServiceRunner in a specific order.

### Game Services (`services/game/`)
Services that just need to run after models are ready:
- **CandleService** - Removes expired candles
- *Your new services go here!*

Game services are **auto-discovered** - just drop a `.luau` file with an `init()` function and it runs automatically.

## Service Patterns

### Pattern 1: Loop-Based Services

Loop-based services run periodic tasks using `task.spawn()` with a `while true do` loop.

**When to use:**
- Periodic cleanup (expired items, stale data)
- Scheduled updates (leaderboards, timers)
- Resource management (token regeneration)

**Examples:** PersistenceService (queue processing), CandleService (candle expiry)

**Template:**
```lua
--!strict

local MyService = {}

local CHECK_INTERVAL_SECONDS = 1
local isRunning = false

local function doPeriodicWork(): ()
    -- Your periodic logic here
end

local function startLoop()
    if isRunning then return end
    isRunning = true

    task.spawn(function()
        while true do
            doPeriodicWork()
            task.wait(CHECK_INTERVAL_SECONDS)
        end
    end)
end

function MyService.init()
    print("[MyService] Initializing...")
    startLoop()
end

return MyService
```

### Pattern 2: Event-Driven Services

Event-driven services respond to system events without continuous polling.

**When to use:**
- Player lifecycle handling (join/leave)
- Game state transitions (round start/end)
- One-time setup or registration

**Examples:** SlashCommandService (chat commands)

**Template:**
```lua
--!strict

local Players = game:GetService("Players")

local MyService = {}

local function onPlayerAdded(player: Player)
    -- Handle player join
end

local function onPlayerRemoving(player: Player)
    -- Handle player leave
end

function MyService.init()
    print("[MyService] Initializing...")

    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    -- Handle players already in game
    for _, player in Players:GetPlayers() do
        onPlayerAdded(player)
    end
end

return MyService
```

## Decision Tree: Choosing a Pattern

```
Do you need to run code periodically on a timer?
├── YES → Use Loop-Based Pattern
│         Examples: cleanup tasks, scheduled updates, resource regeneration
│
└── NO → Do you respond to specific events?
         ├── YES → Use Event-Driven Pattern
         │         Examples: player join/leave, chat commands, game lifecycle
         │
         └── NO → Consider if you need a service at all
                  (Maybe a utility module or model method is better)
```

## Example: CandleService (Loop-Based)

CandleService removes candles that have exceeded their lifetime:

```lua
--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CandlesModel = require(ServerScriptService.models.serverEntities.CandlesModel)
local CandlesConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("CandlesConfig"))

local CandleService = {}

local CHECK_INTERVAL_SECONDS = 1

local isRunning = false

local function removeExpiredCandles(): ()
    local currentTime = os.time()
    local allCandles = CandlesModel.getAll()
    local candlesToRemove: { string } = {}

    for entityId, candle in allCandles do
        if currentTime - candle.createdTime >= CandlesConfig.lifetimeSeconds then
            table.insert(candlesToRemove, entityId)
        end
    end

    for _, entityId in candlesToRemove do
        CandlesModel.remove(entityId)
    end

    if #candlesToRemove > 0 then
        CandlesModel.syncAll()  -- Broadcast updated state to clients
    end
end

local function startCandleChecker()
    if isRunning then return end
    isRunning = true

    task.spawn(function()
        while true do
            removeExpiredCandles()
            task.wait(CHECK_INTERVAL_SECONDS)
        end
    end)
end

function CandleService.init()
    print("[CandleService] Initializing...")
    startCandleChecker()
end

return CandleService
```

**Key design decisions:**
- **1-second interval**: Frequent enough for responsive removal, not so frequent as to waste cycles
- **Config-driven lifetime**: Uses `CandlesConfig.lifetimeSeconds` - tunable without code changes
- **Batch removal**: Collects all expired candles first, removes them, then syncs once
- **syncAll()**: Uses CandlesModel.syncAll() to handle both populated and empty states

## Step-by-Step: Creating a New Service

### Step 1: Choose Your Pattern

Ask yourself:
- Need periodic checks? → Loop-based
- Respond to events? → Event-driven
- Both? → Combine patterns in one service

### Step 2: Create the Service File

Create your service in `Source/ServerScriptService/services/game/`:

```lua
--!strict

local MyService = {}

function MyService.init()
    print("[MyService] Initializing...")
    -- Your initialization logic
end

return MyService
```

**That's it!** ServiceRunner auto-discovers and initializes any ModuleScript in `services/game/` that has an `init()` function.

### Step 3: Test

1. Start Play mode in Studio
2. Check Output window for `[MyService] Initializing...`
3. Verify your service behavior

## Best Practices

### DO:
- Use descriptive print statements for debugging (prefix with `[ServiceName]`)
- Initialize services after models they depend on
- Use `task.spawn()` for loops to avoid blocking
- Batch operations when possible (sync once after multiple changes)
- Use module-level `isRunning` flag to prevent duplicate loops

### DON'T:
- Block the main thread with infinite loops (always use `task.spawn()`)
- Start multiple instances of the same loop
- Call `syncState()` for every individual change in a batch operation
- Forget to handle edge cases (empty collections, missing data)

## Service File Locations

```
Source/ServerScriptService/
├── services/
│   ├── ServiceRunner.luau         -- Orchestrates service initialization
│   ├── framework/                 -- Explicit initialization order
│   │   ├── PersistenceService.luau    -- DataStore write queue (loop-based)
│   │   └── SlashCommandService.luau   -- Chat commands (event-driven)
│   └── game/                      -- Auto-discovered services
│       └── CandleService.luau         -- Candle expiry (loop-based)
├── models/
│   └── ModelRunner.server.luau    -- Calls ServiceRunner for service init
└── controllers/
    └── ...
```

### Adding a New Game Service

Simply create a new `.luau` file in `services/game/` with an `init()` function:

```lua
-- services/game/MyNewService.luau
local MyNewService = {}

function MyNewService.init()
    print("[MyNewService] Initializing...")
end

return MyNewService
```

ServiceRunner will automatically discover and initialize it. You'll see in the Output:
```
[ServiceRunner] Initialized: MyNewService
```

## Existing Services Reference

| Service | Location | Pattern | Purpose |
|---------|----------|---------|---------|
| PersistenceService | framework/ | Loop-based | Processes DataStore write queue with rate limiting |
| SlashCommandService | framework/ | Event-driven | Registers and handles chat slash commands |
| CandleService | game/ | Loop-based | Removes expired candles every second |

### When to Use Framework vs Game

| Put in `framework/` if... | Put in `game/` if... |
|---------------------------|----------------------|
| Other services depend on it | It just needs models to be ready |
| Initialization order matters | Order doesn't matter |
| It's a core system service | It's game-specific logic |
| Example: PersistenceService | Example: CandleService |
