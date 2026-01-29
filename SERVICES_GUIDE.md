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
| **Initialization** | Called from ModelRunner after models | Auto-discovered by ControllerRunner |
| **Player-specific** | Usually system-wide | Usually per-player |
| **Examples** | PersistenceService, CandleService | InventoryController, ShrineController |

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

local CandlesModel = require(script.Parent.Parent.models.serverEntities.CandlesModel)

local CandleService = {}

local CANDLE_LIFETIME_SECONDS = 5
local CHECK_INTERVAL_SECONDS = 1

local isRunning = false

local function removeExpiredCandles(): ()
    local currentTime = os.time()
    local allCandles = CandlesModel.getAll()
    local candlesToRemove: { string } = {}

    for entityId, candle in allCandles do
        if currentTime - candle.createdTime >= CANDLE_LIFETIME_SECONDS then
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
- **5-second lifetime**: Candles disappear after 5 seconds (adjust as needed)
- **Batch removal**: Collects all expired candles first, removes them, then syncs once
- **syncAll()**: Uses CandlesModel.syncAll() to handle both populated and empty states

## Step-by-Step: Creating a New Service

### Step 1: Choose Your Pattern

Ask yourself:
- Need periodic checks? → Loop-based
- Respond to events? → Event-driven
- Both? → Combine patterns in one service

### Step 2: Create the Service File

Create your service in `Source/ServerScriptService/services/`:

```lua
--!strict

local MyService = {}

function MyService.init()
    print("[MyService] Initializing...")
    -- Your initialization logic
end

return MyService
```

### Step 3: Add to ModelRunner

Add initialization in `ModelRunner.server.luau` after model initialization:

```lua
-- Initialize game services that depend on models
local MyService = require(script.Parent.Parent.services.MyService)
MyService.init()
```

### Step 4: Test

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
│   ├── PersistenceService.luau    -- DataStore write queue (loop-based)
│   ├── SlashCommandService.luau   -- Chat commands (event-driven)
│   └── CandleService.luau         -- Candle expiry (loop-based)
├── models/
│   └── ModelRunner.server.luau    -- Initializes services after models
└── controllers/
    └── ...
```

## Existing Services Reference

| Service | Pattern | Purpose |
|---------|---------|---------|
| PersistenceService | Loop-based | Processes DataStore write queue with rate limiting |
| SlashCommandService | Event-driven | Registers and handles chat slash commands |
| CandleService | Loop-based | Removes expired candles every second |
