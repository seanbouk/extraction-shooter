# View Development Guide

This guide explains how to create Views in this Roblox MVC project.

## What is a View?

Views are LocalScripts that handle client-side visual and audio feedback. They observe game state and provide immediate user feedback while waiting for server confirmation for authoritative state changes.

## Architecture Overview

Views live exclusively on the client and are responsible for:

- **Displaying** visual and audio feedback
- **Listening** to user interactions (ProximityPrompts, buttons, etc.)
- **Sending intents** to Controllers via Bolt ReliableEvents (Network.Intent.*, when server logic is needed)
- **Updating UI** based on state changes from Models via Bolt RemoteProperty (Network.State.* with Observe())

## Creating a New View

### Step 1: Understand View Patterns

Views typically follow one of three patterns:

**Pattern A: Pure Client-Side Feedback**
- No server communication
- Immediate visual/audio response only
- Example: Particle effects, sound effects, animations

**Pattern B: Intent-Based with Server Validation**
- Send intent to Controller via Bolt ReliableEvent (Network.Intent.*)
- Provide immediate feedback
- Wait for server confirmation before showing final state
- Example: Purchasing items, equipping gear, collecting objects

**Pattern C: State Observation and UI Updates**
- Observe Model state changes via Bolt RemoteProperty (Network.State.*.Observe())
- Update UI based on authoritative server state
- Observe() fires immediately with current state and on each update
- Bolt handles per-player filtering automatically for User-scoped models
- Example: Health bars, inventory displays, status indicators

#### Decision Tree: Choosing the Right View Pattern

Use this decision tree to determine which pattern your view needs:

**Question 1: Does this view need to communicate with the server?**
- **No** → **Pattern A** (Pure Client-Side Feedback)
  - Use for: Particle effects, sound effects, hover animations, camera effects
  - Benefits: Instant response, no network latency, simple implementation
- **Yes** → Continue to Question 2

**Question 2: Does this view need to send user actions to the server?**
- **Yes** → Continue to Question 3
- **No** → **Pattern C** (State Observation and UI Updates)
  - Use for: Status bars, health displays, leaderboards, read-only UI
  - Benefits: Always shows authoritative server state

**Question 3: Does this view also need to observe server state changes?**
- **Yes** → **Combination of Pattern B + Pattern C**
  - Use for: Shop UI (sends purchase intents, observes gold updates)
  - Use for: Inventory UI (sends equip intents, observes inventory changes)
  - Pattern B handles user actions, Pattern C updates display
- **No** → **Pattern B** (Intent-Based with Server Validation)
  - Use for: One-shot actions that don't need state updates
  - Use for: Actions where other views show the state (CashMachine + StatusBar)

**Visual Decision Tree:**

```
Does view need server communication?
├─ No → Pattern A (Pure Client)
└─ Yes → Does view send user actions?
    ├─ No → Pattern C (State Observation)
    └─ Yes → Does view also observe state?
        ├─ No → Pattern B (Intent-Based)
        └─ Yes → Pattern B + C (Combination)
```

**Examples by Pattern:**

✅ **Pattern A** (Pure Client-Side):
- Particle effect when hovering over object
- Sound effect on button hover
- Camera shake on explosion
- Tween animation on UI element
- Local visual feedback that doesn't affect game state

✅ **Pattern B** (Intent-Based):
- Cash machine withdraw button (StatusBarView shows gold update separately)
- Donate treasure button (shrine state shown elsewhere)
- Trigger server event (no UI update needed in this view)

✅ **Pattern C** (State Observation):
- Status bar showing gold/treasure (read-only display)
- Health bar showing player HP (no user interaction)
- Leaderboard showing server state (updates automatically)

✅ **Pattern B + C** (Combination):
- Shop UI (buy button sends intent + gold display observes state)
- Inventory UI (equip button sends intent + inventory list observes state)
- Trading UI (offer button sends intent + trade status observes state)

**Common Mistakes:**

❌ Using Pattern A for game state changes
- Don't update UI based on client predictions alone
- Always wait for server confirmation for authoritative state

❌ Using Pattern B without considering state updates
- If your view displays changing data, you likely need Pattern C too
- Separate concerns: Button (B) + Display (C)

❌ Not filtering ownerId for "all" scope broadcasts
- Server-scoped models broadcast to all players
- Views must filter to show only relevant data

### Step 2: Create Your View File

Create a new LocalScript in `src/client/views/YourView.client.luau`:

```lua
--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))

local view = AbstractView.new("YourView", "YourTag")

local function setupInstance(instance: Instance)
	-- Wait for required children
	local button = instance:WaitForChild("Button") :: TextButton

	-- Connect to user interaction
	button.Activated:Connect(function()
		-- Provide immediate feedback
		button.Text = "Clicked!"

		-- Optional: Send intent to server via Bolt ReliableEvent
		-- Network.Intent.YourFeature:FireServer(Network.Actions.YourFeature.Action, data)
	end)
end

view:initialize(setupInstance)
```

**Key points:**
- Extend `AbstractView` instead of writing CollectionService boilerplate
- `view:initialize(setupFn)` handles both existing and dynamically added instances
- The setup function receives each tagged instance for configuration

## File Locations

- **Your Views**: `src/client/views/YourView.client.luau`
- **Network Module** (for server communication): `ReplicatedStorage/Network.luau`
- **AbstractView Module**: `ReplicatedFirst/AbstractView.luau`

## Using AbstractView

AbstractView is a base module that standardizes view initialization and provides helpers for view-to-view communication.

### API

- `AbstractView.new(viewName, tag)` - Create a new view instance
- `view:initialize(setupFn)` - Initialize with CollectionService pattern (handles both existing and dynamically added instances)
- `view:createEvent(eventName)` - Create a BindableEvent in PlayerScripts for view-to-view communication
- `view:getEvent(eventName, timeout?)` - Get a BindableEvent from PlayerScripts (with optional timeout, default 5 seconds)

### Basic Usage

```lua
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))

local view = AbstractView.new("MyView", "MyTag")

local function setupInstance(instance: Instance)
    -- Your setup logic here
end

view:initialize(setupInstance)
```

### View-to-View Communication

The event methods (`createEvent`, `getEvent`) enable direct communication between UI views without going through the server. This is useful for coordinating UI behavior like toggling panels.

**Example: FavoursView creates a toggle event**

```lua
local view = AbstractView.new("FavoursView", "Favours")
local toggleEvent = view:createEvent("FavoursToggleEvent")

local function setupFavours(favours: Instance)
    local screenGui = favours :: ScreenGui
    screenGui.Enabled = false

    toggleEvent.Event:Connect(function()
        screenGui.Enabled = not screenGui.Enabled
    end)
end

view:initialize(setupFavours)
```

**Example: StatusBarView gets the event to fire when button is clicked**

```lua
local view = AbstractView.new("StatusBarView", "StatusBar")

local function setupStatusBar(statusBar: Instance)
    local favoursButton = statusBar:FindFirstChild("FavoursButton") :: TextButton?
    if favoursButton then
        favoursButton.Activated:Connect(function()
            local toggleEvent = view:getEvent("FavoursToggleEvent")
            if toggleEvent then
                toggleEvent:Fire()
            end
        end)
    end
end

view:initialize(setupStatusBar)
```

### When to Use Event Methods

Use `createEvent` and `getEvent` when:
- ✅ One UI view needs to trigger behavior in another UI view
- ✅ The communication is purely client-side (no server validation needed)
- ✅ You want to decouple views from each other (no direct references)

Don't use event methods when:
- ❌ You need server validation (use Network.Intent instead)
- ❌ You're updating based on game state (use Network.State:Observe instead)

## Example: CashMachineView

The `CashMachineView.client.luau` file demonstrates **Pattern B: Intent-Based with Server Validation**:

### Features:
- Extends AbstractView for standardized initialization
- Targets all "CashMachine" tagged instances
- Connects to ProximityPrompt.Triggered event
- Provides immediate visual/audio feedback (particles + sound)
- Sends intent to server to withdraw gold
- Server validates and updates player's inventory

### Pattern Used:
```lua
--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))

local cashMachineIntent = Network.Intent.CashMachine

local WITHDRAW_AMOUNT = 50

local view = AbstractView.new("CashMachineView", "CashMachine")

local function setupCashMachine(cashMachine: Instance)
	local base = cashMachine:WaitForChild("Base")

	local proximityPrompt = base:WaitForChild("ProximityPrompt") :: ProximityPrompt
	local particleEmitter = base:WaitForChild("ParticleEmitter") :: ParticleEmitter
	local sound = base:WaitForChild("Sound") :: Sound

	proximityPrompt.Triggered:Connect(function(player: Player)
		-- Immediate visual/audio feedback
		local particleCount = particleEmitter.Rate
		particleEmitter:Emit(particleCount)
		sound:Play()

		-- Send intent to server via Bolt ReliableEvent
		cashMachineIntent:FireServer(Network.Actions.CashMachine.Withdraw, WITHDRAW_AMOUNT)
	end)
end

view:initialize(setupCashMachine)
```

This demonstrates the key MVC principle: **immediate client feedback** followed by **server authority** through the intent system.

## Example: StatusBarView

The `StatusBarView.client.luau` file demonstrates **Pattern C: State Observation and UI Updates** with **view-to-view communication**:

### Features:
- Extends AbstractView for standardized initialization
- Targets all "StatusBar" tagged ScreenGui instances
- Observes inventory state via Bolt RemoteProperty (Network.State.Inventory)
- Bolt handles per-player filtering automatically for User-scoped models
- Updates UI TextLabels with gold and treasure amounts
- Uses `getEvent()` to communicate with FavoursView for toggle functionality

### Pattern Used:
```lua
--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))
local Network = require(ReplicatedStorage:WaitForChild("Network"))

local inventoryState = Network.State.Inventory

local view = AbstractView.new("StatusBarView", "StatusBar")

local function setupStatusBar(statusBar: Instance)
	local frame = statusBar:WaitForChild("Frame")
	local goldLabel = frame:WaitForChild("GoldLabel") :: TextLabel
	local treasureLabel = frame:WaitForChild("TreasureLabel") :: TextLabel

	-- Setup FavoursButton toggle (view-to-view communication)
	local favoursButton = frame:FindFirstChild("FavoursButton") :: TextButton?
	if favoursButton then
		favoursButton.Activated:Connect(function()
			local toggleEvent = view:getEvent("FavoursToggleEvent")
			if toggleEvent then
				toggleEvent:Fire()
			end
		end)
	end

	local function updateLabels(gold: number, treasure: number)
		goldLabel.Text = `💰 {gold}`
		treasureLabel.Text = `💎 {treasure}`
	end

	-- Observe state changes from server via Bolt RemoteProperty
	-- Observe() fires immediately with current state, then on each update
	inventoryState:Observe(function(data: Network.InventoryState)
		-- No filtering needed - Bolt handles per-player filtering automatically
		updateLabels(data.gold, data.treasure)
	end)
end

view:initialize(setupStatusBar)
```

### Key Concepts:
- **State Observation**: Views observe state via Network.State.*:Observe() callbacks
- **Immediate State**: Observe() fires immediately with current state - no need to request initial state
- **Automatic Filtering**: Bolt handles per-player filtering automatically for User-scoped models
- **Reactive Updates**: Callback fires automatically on each state change from server
- **Type Safety**: Define types for the data structure received from the server
- **UI Updates**: Update TextLabels, progress bars, or other UI elements with new state
- **Separation**: No user input handling - purely displays authoritative server state

### Why Observe() is Better

The Bolt Observe() pattern eliminates common issues with the old RemoteEvent pattern:

**Advantages:**
- ✅ Fires immediately with current state - no need to request initial state
- ✅ No race conditions - always receives state even if late to observe
- ✅ Automatic per-player filtering for User-scoped models
- ✅ Cleaner, more reactive code pattern
- ✅ Single API for both initial state and updates

**Old Pattern (RemoteEvents) had issues:**
- ❌ Required manual initial state request
- ❌ Race condition if listener set up late
- ❌ Had to filter by ownerId manually for "all" scope
- ❌ Two separate APIs (OnClientEvent + FireServer)

## Best Practices

### 1. Use AbstractView

Always extend AbstractView instead of writing CollectionService boilerplate:

```lua
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local AbstractView = require(ReplicatedFirst:WaitForChild("AbstractView"))

local view = AbstractView.new("YourView", "YourTag")

local function setupInstance(instance: Instance)
	-- Your setup logic
end

view:initialize(setupInstance)
```

AbstractView handles:
- Finding all existing tagged instances
- Setting up listeners for dynamically added instances
- Spawning setup functions in separate threads to avoid blocking
- Automatically filtering out StarterGui instances (only initializes PlayerGui clones)

### 2. Use WaitForChild

Always wait for children to exist, as they may not be ready immediately:

```lua
local button = instance:WaitForChild("Button")
local sound = button:WaitForChild("ClickSound")
```

### 3. Type Safety

Always use `--!strict` and type your variables:

```lua
local proximityPrompt = base:WaitForChild("ProximityPrompt") :: ProximityPrompt
local sound = base:WaitForChild("Sound") :: Sound
```

### 5. Immediate Feedback

Provide instant visual feedback before server confirmation:

```lua
button.Activated:Connect(function()
	-- Immediate feedback
	button.BackgroundColor3 = Color3.new(0, 1, 0)

	-- Send to server (using typed constant)
	intent:FireServer(IntentActions.Shop.Purchase, itemId)

	-- Wait for confirmation (in a separate listener)
	-- confirmEvent.OnClientEvent:Connect(function(success)
	--     if success then
	--         button.Text = "Purchased!"
	--     else
	--         button.BackgroundColor3 = Color3.new(1, 0, 0)
	--     end
	-- end)
end)
```

## Common Patterns

### Proximity Prompt Interaction

```lua
local proximityPrompt = instance:WaitForChild("ProximityPrompt") :: ProximityPrompt

proximityPrompt.Triggered:Connect(function(player: Player)
	-- Handle interaction
	print(player.Name .. " interacted with " .. instance.Name)
end)
```

### Button Click Handler

```lua
local button = screenGui:WaitForChild("Button") :: TextButton

button.Activated:Connect(function()
	-- Handle click
	print("Button clicked!")
end)
```

### State Observation (Listening to Model Changes)

```lua
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Define type for the data structure
type ModelData = {
	ownerId: string,
	property1: number,
	property2: string,
}

-- Listen for state changes from server model
local modelStateChanged = ReplicatedStorage:WaitForChild("Events")
	:WaitForChild("YourModelStateChanged") :: RemoteEvent

modelStateChanged.OnClientEvent:Connect(function(modelData: ModelData)
	-- For "owner" scope broadcasts: No filtering needed - server already sent to correct player
	-- For "all" scope broadcasts: Filter by checking ownerId if needed

	-- Example for "owner" scope (like inventory):
	updateDisplay(modelData)

	-- Example for "all" scope where you need to filter (like visible health bars):
	-- if modelData.ownerId == tostring(localPlayer.UserId) then
	--     updateDisplay(modelData)
	-- end
end)

-- Request initial state after listener is set up
modelStateChanged:FireServer()
```

**Key Points:**
- Models broadcast state via `[ModelName]StateChanged` RemoteEvents
- Views only need to filter by `ownerId` for "all" scope broadcasts (where all players receive the event). For "owner" scope broadcasts, the server already ensures only the owner receives it via `FireClient()`.
- Define types matching the server-side model structure
- **Always request initial state** after setting up the listener (prevents race condition)
- Use this pattern for any UI that displays model state (health, inventory, etc.)

## Relationship to Models and Controllers

### Views → Controllers
- Views **send intents** to controllers via RemoteEvents
- Views **never directly** modify Models
- Communication is always through RemoteEvents
- Views use **IntentActions** constants instead of magic strings for type safety

### Views ← Models
- Views **observe** state changes broadcast by Models
- Views **update** visual elements based on authoritative server state

### Complete Flow Example

```
1. User clicks button (View provides immediate feedback)
2. View fires intent: PurchaseIntent:FireServer(IntentActions.Shop.BuySword, "FireSword")
3. Controller validates and updates Model
4. Model broadcasts state change to all clients
5. View receives broadcast and updates UI with final state
```

### Shared Constants and Types

#### IntentActions (View → Controller)

All intent action strings are centralized in `src/shared/IntentActions.luau`:

```lua
local IntentActions = require(ReplicatedStorage:WaitForChild("IntentActions"))

-- Use typed constants instead of magic strings
cashMachineIntent:FireServer(IntentActions.CashMachine.Withdraw, amount)
bazaarIntent:FireServer(IntentActions.Bazaar.BuyTreasure)
shrineIntent:FireServer(IntentActions.Shrine.Donate)
```

#### StateEvents (Model → View)

All state event names and data types are centralized in `src/shared/StateEvents.luau`:

```lua
local StateEvents = require(ReplicatedStorage:WaitForChild("StateEvents"))

-- Use event name constants instead of magic strings
local inventoryStateChanged = eventsFolder:WaitForChild(StateEvents.Inventory.EventName)

-- Use exported types for type-safe handling
inventoryStateChanged.OnClientEvent:Connect(function(data: StateEvents.InventoryData)
    updateUI(data.gold, data.treasure)
end)
```

**Benefits:**
- Type safety - prevents typos in event names and data structures
- Autocomplete support for both event names and data fields
- Single source of truth for all state event names and types
- Easy refactoring - change in one place, type errors guide you everywhere
- No duplicate type definitions across views

## Working with StateEvents (View Perspective)

When creating views that observe model state, you use StateEvents to get type-safe access to state change events and their data structures.

### What are StateEvents?

StateEvents is a centralized module (`src/shared/StateEvents.luau`) that provides:
- **Event name constants** - Single source of truth for RemoteEvent names
- **Exported data types** - Type-safe state data structures
- **Complete MVC type safety** - From model through view

### When to Use StateEvents in Views

Use StateEvents when:
- ✅ Your view needs to display model state (Pattern C)
- ✅ Your view needs to update UI when server state changes
- ✅ You want type-safe access to state data properties

### Step-by-Step: Using StateEvents in Views

**1. Import StateEvents module**

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateEvents = require(ReplicatedStorage:WaitForChild("StateEvents"))
```

**2. Get the RemoteEvent using event name constant**

```lua
local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local stateChangedEvent = eventsFolder:WaitForChild(StateEvents.YourModel.EventName)
```

**3. Set up typed listener**

```lua
stateChangedEvent.OnClientEvent:Connect(function(data: StateEvents.YourModelData)
    -- Luau knows the structure of data!
    -- data.property1, data.property2, etc. are all typed
    updateUI(data)
end)
```

**4. Request initial state (for Pattern C views)**

```lua
-- IMPORTANT: Set up listener FIRST, then request initial state
stateChangedEvent:FireServer()  -- Requests current state from server
```

### Complete Example: StatusBarView

This view observes inventory state and updates a UI display:

```lua
--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import StateEvents for type-safe state observation
local StateEvents = require(ReplicatedStorage:WaitForChild("StateEvents"))

local TAG = "StatusBar"
local localPlayer = Players.LocalPlayer

-- Get state change event using constant
local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local inventoryStateChanged = eventsFolder:WaitForChild(StateEvents.Inventory.EventName)

-- Listen for inventory state changes with typed data
inventoryStateChanged.OnClientEvent:Connect(function(data: StateEvents.InventoryData)
    -- Type-safe access to properties!
    print("Gold:", data.gold)
    print("Treasure:", data.treasure)

    -- Update all status bars
    for _, screenGui in CollectionService:GetTagged(TAG) do
        local goldLabel = screenGui:FindFirstChild("GoldLabel", true) :: TextLabel
        local treasureLabel = screenGui:FindFirstChild("TreasureLabel", true) :: TextLabel

        if goldLabel then
            goldLabel.Text = "Gold: " .. tostring(data.gold)
        end
        if treasureLabel then
            treasureLabel.Text = "Treasure: " .. tostring(data.treasure)
        end
    end
end)

-- Request initial state
task.wait(1)  -- Wait for RemoteEvent to replicate
inventoryStateChanged:FireServer()
```

### ownerId Filtering: When Do You Need It?

**Important:** Understanding when to filter by ownerId depends on the model's broadcast scope.

#### User-Scoped Models (Automatic Filtering)

Models with User scope automatically filter on the server via Bolt:

```lua
-- NO FILTERING NEEDED - server already sent only to this player
inventoryStateChanged.OnClientEvent:Connect(function(data: StateEvents.InventoryData)
    -- This data is already for the local player
    updateUI(data.gold, data.treasure)
end)
```

**Why no filtering?**
- Bolt uses `SetFor(player, data)` for User-scoped models
- Only the owning player receives the state update
- No other players see this data

#### Server-Scoped Models (Broadcast to All)

Models with Server scope sync to all players via Bolt:

```lua
-- FILTERING NEEDED - all players receive this
shrineStateChanged.OnClientEvent:Connect(function(data: StateEvents.ShrineData)
    -- All players get this, filter if you only want certain data
    print("Last donor:", data.buyerName)
    print("Total treasure:", data.treasure)

    -- ownerId is "SERVER" for server-scoped models
    -- Usually you want to show this to everyone (that's why it's "all" scope)
end)
```

**When to filter server-scoped data:**
- When showing player-specific views of shared data
- Example: Leaderboard showing local player highlighted
- Use `localPlayer.UserId` or `localPlayer.Name` to filter display logic

### Common Patterns

#### Pattern 1: Display-Only View (Status Bar)

```lua
-- Setup listener
stateChanged.OnClientEvent:Connect(function(data: StateEvents.ModelData)
    updateLabels(data.property1, data.property2)
end)

-- Request initial state
stateChanged:FireServer()
```

#### Pattern 2: View with User Interaction + State Display

```lua
-- Part 1: Send intents (Pattern B)
button.Activated:Connect(function()
    remoteEvent:FireServer(IntentActions.Feature.Action, parameter)
end)

-- Part 2: Observe state (Pattern C)
stateChanged.OnClientEvent:Connect(function(data: StateEvents.ModelData)
    updateDisplay(data)
end)

-- Request initial state
stateChanged:FireServer()
```

#### Pattern 3: Multiple Models

```lua
-- Listen to multiple state events
inventoryStateChanged.OnClientEvent:Connect(function(data: StateEvents.InventoryData)
    updateInventoryUI(data)
end)

questStateChanged.OnClientEvent:Connect(function(data: StateEvents.QuestData)
    updateQuestUI(data)
end)

-- Request initial state for both
inventoryStateChanged:FireServer()
questStateChanged:FireServer()
```

### Type Safety Benefits

**Autocomplete:**
```lua
-- Type StateEvents. and see all available models:
-- - StateEvents.Inventory.EventName
-- - StateEvents.Shrine.EventName
-- - StateEvents.Quest.EventName
```

**Property access:**
```lua
stateChanged.OnClientEvent:Connect(function(data: StateEvents.InventoryData)
    -- Autocomplete shows: gold, treasure, ownerId
    local gold = data.gold  -- ✓ Known to be number
    local invalid = data.silver  -- ✗ Compile-time error!
end)
```

**Refactoring:**
```lua
-- If InventoryData type changes in StateEvents:
export type InventoryData = {
    ownerId: string,
    gold: number,
    treasure: number,
    gems: number,  -- New property added
}

-- Views show type errors at usage sites, guiding updates
```

### Initial State Request Pattern

**The correct order:**

```lua
-- 1. Set up listener FIRST
stateChanged.OnClientEvent:Connect(function(data)
    updateUI(data)
end)

-- 2. Wait for RemoteEvent to replicate
task.wait(1)

-- 3. Request initial state LAST
stateChanged:FireServer()
```

**Why this order matters:**
- If you request state before setting up the listener, you'll miss the response
- The server responds immediately when you call FireServer()
- The wait ensures the RemoteEvent has replicated to the client

**Alternative: Check for existing state**

```lua
local hasReceivedState = false

stateChanged.OnClientEvent:Connect(function(data)
    hasReceivedState = true
    updateUI(data)
end)

-- Wait for RemoteEvent, then request
task.wait(1)
if not hasReceivedState then
    stateChanged:FireServer()
end
```

### Troubleshooting

**Problem:** View not receiving state updates
- Check: Is the RemoteEvent name correct? Use StateEvents.Model.EventName
- Check: Did you set up listener before requesting initial state?
- Check: Is the model firing? Check server Output for fire() debug messages
- Fix: Verify event name matches model name exactly

**Problem:** Type errors when accessing data properties
- Check: Are you using the correct exported type? (StateEvents.ModelData)
- Check: Does the type definition match the model's actual properties?
- Fix: Update StateEvents.luau to match model's getState() return value

**Problem:** Receiving wrong player's data
- Check: Is this a user-scoped model using fire("owner")?
- Answer: No filtering needed - server already filtered
- Check: Is this a server-scoped model using fire("all")?
- Answer: This is correct - all players should see it

**Problem:** UI not showing initial state
- Check: Did you call stateChanged:FireServer() to request initial state?
- Check: Did you wait for RemoteEvent replication before requesting?
- Fix: Add task.wait(1) before FireServer() call

### Benefits Summary

✅ **Type Safety** - Catch typos and mismatches at compile-time
✅ **Single Source of Truth** - Event names defined once
✅ **IDE Autocomplete** - See all models and their properties
✅ **Refactoring Safety** - Changes guide you to all usage sites
✅ **Self-Documenting** - Types show what data to expect
✅ **No Duplicate Types** - Import once, use everywhere

### Understanding What Views Actually Send

It's important to understand what actually happens when a view sends an intent to a controller.

#### What Gets Sent Over the Network

When you call:
```lua
cashMachineIntent:FireServer(IntentActions.CashMachine.Withdraw, amount)
```

**What actually transmits:**
```
[PlayerInstance] "Withdraw" 50
```

- `IntentActions.CashMachine.Withdraw` evaluates to the string `"Withdraw"` at runtime
- No type information is sent - just the plain string value
- The network doesn't know or care about types

#### Type Safety in Views

Views in this codebase don't currently have type-enforced action parameters. This means:

```lua
-- This works, but no compile-time validation forces you to use IntentActions
cashMachineIntent:FireServer("Withdraw", 50)

-- This also works at compile-time, but will fail at runtime
cashMachineIntent:FireServer("InvalidAction", 50)
```

**Why this is okay:**
- The controller's ACTIONS table provides runtime validation
- Invalid actions are rejected on the server
- Type safety is primarily enforced on the server side where it matters for security

#### Optional: Adding Type Safety to View Helper Functions

If you want compile-time type safety in your views, you can create typed helper functions:

```lua
local IntentActions = require(ReplicatedStorage:WaitForChild("IntentActions"))

-- Define a typed helper function
local function sendCashMachineIntent(action: IntentActions.CashMachineAction, amount: number)
    cashMachineIntent:FireServer(action, amount)
end

-- Now this would be a compile-time error:
sendCashMachineIntent("InvalidAction", 50)  -- Type error!

-- This is correct:
sendCashMachineIntent(IntentActions.CashMachine.Withdraw, 50)  -- ✓
```

**Benefits of typed helpers:**
- Compile-time validation that you're using valid actions
- IDE autocomplete for action parameters
- Catches typos during development
- Documents which actions are valid for this intent

**When to use typed helpers:**
- Complex views with many intent calls
- When you want extra safety during refactoring
- Team projects where catching errors early helps collaboration

**When you don't need them:**
- Simple views with one or two intents
- When you always use IntentActions constants (already safe from typos)
- Views that only observe state and don't send intents

#### The View's Role in Type Safety

**What views DO:**
- Use centralized constants from IntentActions (prevents typos)
- Send plain string values over RemoteEvents
- Provide immediate visual feedback to users

**What views DON'T do:**
- Enforce type safety at the network boundary (impossible - clients can be modified)
- Validate actions (that's the controller's job)
- Provide security guarantees (server-side validation does this)

#### Key Takeaway

**Views use constants for consistency. Controllers enforce types for development safety and validate at runtime for security.**

The IntentActions pattern gives you:
- Constants that prevent typos in views
- Type annotations that guide controller development
- Runtime validation that provides actual security

All three layers work together to create a robust, maintainable system.

## Next Steps

After creating your view:

1. **Create a Controller** (`src/server/controllers/`) if server validation is needed
2. **Create a Model** (`src/server/models/`) to store authoritative state
3. **Test the flow** end-to-end with user interactions

See the main [README.md](README.md) for the complete MVC architecture overview.
