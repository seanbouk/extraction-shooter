# View Development Guide

This guide explains how to create Views in this Roblox MVC project.

## What is a View?

Views are LocalScripts that handle client-side visual and audio feedback. They observe game state and provide immediate user feedback while waiting for server confirmation for authoritative state changes.

## Architecture Overview

Views live exclusively on the client and are responsible for:

- **Displaying** visual and audio feedback
- **Listening** to user interactions (ProximityPrompts, buttons, etc.)
- **Sending intents** to Controllers via RemoteEvents (when server logic is needed)
- **Updating UI** based on state broadcasts from Models

## Creating a New View

### Step 1: Understand View Patterns

Views typically follow one of three patterns:

**Pattern A: Pure Client-Side Feedback**
- No server communication
- Immediate visual/audio response only
- Example: Particle effects, sound effects, animations

**Pattern B: Intent-Based with Server Validation**
- Send intent to Controller via RemoteEvent
- Provide immediate feedback
- Wait for server confirmation before showing final state
- Example: Purchasing items, equipping gear, collecting objects

**Pattern C: State Observation and UI Updates**
- Listen to Model state change RemoteEvents
- Update UI based on authoritative server state
- Filter updates by ownerId or other criteria
- Example: Health bars, inventory displays, status indicators

### Step 2: Create Your View File

Create a new LocalScript in `src/client/views/YourView.client.lua`:

```lua
--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import shared constants
local IntentActions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IntentActions"))

-- Constants
local TAG_NAME = "YourTag"

-- Sets up a single tagged instance
local function setupInstance(instance: Instance)
	-- Wait for required children
	local button = instance:WaitForChild("Button") :: TextButton

	-- Connect to user interaction
	button.Activated:Connect(function()
		-- Provide immediate feedback
		button.Text = "Clicked!"

		-- Optional: Send intent to server
		-- local intent = ReplicatedStorage:WaitForChild("Shared")
		-- 	:WaitForChild("Events")
		-- 	:WaitForChild("YourIntent") :: RemoteEvent
		-- intent:FireServer(IntentActions.YourFeature.Action, data)
	end)

	print(`YourView: Setup complete for {instance.Name}`)
end

-- Initialize all existing tagged instances
for _, instance in ipairs(CollectionService:GetTagged(TAG_NAME)) do
	task.spawn(function()
		setupInstance(instance)
	end)
end

-- Handle dynamically added instances
CollectionService:GetInstanceAddedSignal(TAG_NAME):Connect(function(instance: Instance)
	task.spawn(function()
		setupInstance(instance)
	end)
end)

print("YourView: Initialized")
```

## File Locations

- **Your Views**: `src/client/views/YourView.client.lua`
- **RemoteEvents** (for server communication): `ReplicatedStorage/Shared/Events/`

## Example: CashMachineView

The `CashMachineView.client.lua` file demonstrates **Pattern B: Intent-Based with Server Validation**:

### Features:
- Uses CollectionService to find all "CashMachine" tagged instances
- Connects to ProximityPrompt.Triggered event
- Provides immediate visual/audio feedback (particles + sound)
- Sends intent to server to withdraw gold
- Server validates and updates player's inventory

### Pattern Used:
```lua
-- At the top of the file
local IntentActions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IntentActions"))
local cashMachineIntent = eventsFolder:WaitForChild("CashMachineIntent") :: RemoteEvent
local WITHDRAW_AMOUNT = 50

-- In the setup function
proximityPrompt.Triggered:Connect(function(player: Player)
	-- Immediate visual/audio feedback
	local particleCount = particleEmitter.Rate
	particleEmitter:Emit(particleCount)
	sound:Play()

	-- Send intent to server (using typed constant)
	cashMachineIntent:FireServer(IntentActions.CashMachine.Withdraw, WITHDRAW_AMOUNT)
end)
```

This demonstrates the key MVC principle: **immediate client feedback** followed by **server authority** through the intent system.

## Example: StatusBarView

The `StatusBarView.client.lua` file demonstrates **Pattern C: State Observation and UI Updates**:

### Features:
- Uses CollectionService to find all "StatusBar" tagged ScreenGui instances
- Listens to `InventoryStateChanged` RemoteEvent from the server
- Filters updates to only show the local player's inventory data
- Updates UI TextLabels with gold and treasure amounts
- No user interaction - purely observes and displays model state

### Pattern Used:
```lua
-- At the top of the file
local inventoryStateChanged = eventsFolder:WaitForChild("InventoryStateChanged") :: RemoteEvent
local localPlayer = Players.LocalPlayer

-- Type for the data received from server
type InventoryData = {
	ownerId: string,
	gold: number,
	treasure: number,
}

-- In the setup function
local function updateLabels(gold: number, treasure: number)
	goldLabel.Text = `💰 {gold}`
	treasureLabel.Text = `💎 {treasure}`
end

-- Initialize with zero values
updateLabels(0, 0)

-- Listen for state changes from server
inventoryStateChanged.OnClientEvent:Connect(function(inventoryData: InventoryData)
	-- Only update if this is the local player's inventory
	local localPlayerId = tostring(localPlayer.UserId)
	if inventoryData.ownerId == localPlayerId then
		updateLabels(inventoryData.gold, inventoryData.treasure)
	end
end)

-- Request initial state from server (IMPORTANT!)
inventoryStateChanged:FireServer()
```

### Key Concepts:
- **State Observation**: Views listen to `[ModelName]StateChanged` RemoteEvents
- **Filtering**: Views filter updates by `ownerId` to show only relevant data
- **Initial State Request**: After setting up the listener, fire the event to server to request current state
- **Type Safety**: Define types for the data structure received from the server
- **UI Updates**: Update TextLabels, progress bars, or other UI elements with new state
- **Separation**: No user input handling - purely displays authoritative server state

### Why Request Initial State?

When a view needs to display model state immediately (like showing player's gold on join), it must request the initial state after setting up its listener:

```lua
-- 1. Set up listener first
stateChangedEvent.OnClientEvent:Connect(function(data)
	updateUI(data)
end)

-- 2. Then request initial state
stateChangedEvent:FireServer()
```

**Why this pattern?**
- Prevents race condition where server fires state before client is listening
- Guarantees the view receives initial state once it's ready
- Required for any view that displays state immediately on player join

**When to use it:**
- ✅ Views that show model state on join (inventory, health, stats)
- ❌ Views that only respond to user actions (buttons, prompts)

## Best Practices

### 1. Use CollectionService

Tag instances in the Workspace or UI and use CollectionService to find them:

```lua
local CollectionService = game:GetService("CollectionService")

for _, instance in ipairs(CollectionService:GetTagged("YourTag")) do
	setupInstance(instance)
end
```

### 2. Use WaitForChild

Always wait for children to exist, as they may not be ready immediately:

```lua
local button = instance:WaitForChild("Button")
local sound = button:WaitForChild("ClickSound")
```

### 3. Spawn Setup Functions

Use `task.spawn` to avoid blocking when setting up multiple instances:

```lua
for _, instance in ipairs(CollectionService:GetTagged(TAG_NAME)) do
	task.spawn(function()
		setupInstance(instance)
	end)
end
```

### 4. Type Safety

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
local modelStateChanged = ReplicatedStorage:WaitForChild("Shared")
	:WaitForChild("Events")
	:WaitForChild("YourModelStateChanged") :: RemoteEvent

modelStateChanged.OnClientEvent:Connect(function(modelData: ModelData)
	-- Filter: Only process updates for the local player
	if modelData.ownerId == tostring(localPlayer.UserId) then
		-- Update UI based on new authoritative state
		updateDisplay(modelData)
	end
end)

-- Request initial state after listener is set up
modelStateChanged:FireServer()
```

**Key Points:**
- Models broadcast state via `[ModelName]StateChanged` RemoteEvents
- Views filter updates by `ownerId` to show only relevant data
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

### Shared Constants (IntentActions)

All intent action strings are centralized in `src/shared/IntentActions.lua`:

```lua
local IntentActions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IntentActions"))

-- Use typed constants instead of magic strings
cashMachineIntent:FireServer(IntentActions.CashMachine.Withdraw, amount)
bazaarIntent:FireServer(IntentActions.Bazaar.BuyTreasure)
shrineIntent:FireServer(IntentActions.Shrine.Donate)
```

**Benefits:**
- Type safety - prevents typos
- Autocomplete support in your IDE
- Single source of truth for all action strings
- Easy refactoring - change in one place

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
local IntentActions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IntentActions"))

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
