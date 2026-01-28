---
description: Create a new Roblox controller with AbstractController pattern
allowed-tools: Bash(find, cat, grep, ls), Read, Write, Edit, Glob
model: claude-sonnet-4-5-20250929
---

I'll guide you through creating a new Roblox controller that follows this project's AbstractController architecture.

## Project Controller Architecture

- **All controllers extend AbstractController**
- **Auto-discovery**: ControllerRunner automatically discovers and initializes controllers (no manual registration needed)
- **Networking**: Controllers use Bolt ReliableEvents (Network.Intent.*) for client-server communication
- **Type-safe actions**: Network.Actions.* constants prevent typos and enable IDE autocomplete
- **Pattern**: ACTIONS lookup table maps action constants to handler functions (consistent across all controllers)
- **Purpose**: Validate user intents from clients and update Models accordingly

### Data Flow
```
Client (View) → Bolt ReliableEvent (Network.Intent.*) → Controller (Validation) → Model (State Update) → Sync to Clients
```

## Reference Files

Before generating code, I will read these stable reference files to ensure accuracy:
- `Source/ServerScriptService/controllers/AbstractController.luau` - Base class pattern and required methods
- `CONTROLLER_GUIDE.md` - Complete controller documentation with examples and patterns
- `Source/ReplicatedStorage/Network.luau` - Network configuration structure and action constants
- `Source/ServerScriptService/controllers/CashMachineController.luau` - Example of ACTIONS pattern
- `Source/ServerScriptService/controllers/ShrineController.luau` - Example of multiple model interactions

These core files contain the exact patterns, type definitions, and conventions to follow.

## Interactive Controller Creation Wizard

Let's begin creating your controller step by step!

### Step 1: Controller Name

What should your controller be named?

**Requirements**:
- Must end with "Controller" (e.g., ShopController, QuestController, InventoryController)
- Must use PascalCase (e.g., PlayerTradeController)
- No underscores or special characters
- Should describe the feature/system it manages

**Examples**:
- ✅ ShopController - Manages shop purchases and sales
- ✅ InventoryController - Handles inventory actions (equip, drop, use)
- ✅ QuestController - Manages quest progression
- ❌ shop_controller - Wrong case, has underscore
- ❌ Controller - Too generic, missing feature name
- ❌ ShopControl - Must end with "Controller"

### Step 2: Actions Definition

What actions will this controller handle?

**Action Naming Philosophy**:
- ✅ **Describe user INTENT**, not system commands
- ✅ Use verb-based PascalCase names
- ✅ Examples: PurchaseWeapon, EquipItem, Donate, AcceptQuest, SellItem
- ❌ Bad examples: SetInventory, Update, Process, Handle, Execute

**How many actions will this controller handle?** (1-10)

For each action, I'll ask for:

**Action {N} of {Total}**:

1. **Action Name** (PascalCase, verb-based)
   - What is the action name?

2. **Action Purpose** (what does the player intend to do?)
   - What does this action do?

3. **Parameters** (what data comes from the client?)
   - Note: `player: Player` is always automatic
   - For each parameter:
     - Parameter name (camelCase)
     - Parameter type (string, number, boolean, or Vector3)
     - Parameter description

   After each parameter, I'll ask: **Add another parameter? (Yes/No)**

### Step 3: Models to Interact With

Which models will this controller interact with?

**Guidance**:
- Controllers bridge user intents to model state changes
- **User-scoped models**: Per-player data that persists (like InventoryModel, QuestModel) - use `player.UserId`
- **Server-scoped models**: Shared data all players see (like ShrineModel, LeaderboardModel) - use `"SERVER"`
- **UserEntity-scoped models**: Multiple instances per player (like FavoursModel, PetsModel) - use `player.UserId` + `entityId`

**Primary model to update**:
- Model name (must end with "Model")
- Model scope (User, Server, or UserEntity)

**Does this controller interact with additional models?** (Yes/No)

If yes, for each additional model:
- Model name (must end with "Model")
- Model scope (User, Server, or UserEntity)
- Purpose (e.g., "Query item prices", "Check quest requirements")
- For UserEntity: What parameter provides the entityId?

**Model Existence Validation**:

After collecting all models, I will verify each model file exists at:
- User-scoped: `Source/ServerScriptService/models/user/{ModelName}.luau`
- Server-scoped: `Source/ServerScriptService/models/server/{ModelName}.luau`
- UserEntity-scoped: `Source/ServerScriptService/models/userEntities/{ModelName}.luau`

If any model is not found, I will:
1. Warn you about the missing model
2. Show the expected file path
3. Offer options:
   - Use `/create-model` to create it first (RECOMMENDED)
   - Continue anyway (you'll need to create it manually)
   - Choose a different model name
   - Cancel controller generation

### Step 4: Validation Strategy

For each action, what validation is needed?

**Common validation checks**:
1. **Parameter validation** - Type and range checks (e.g., amount > 0, itemId non-empty)
2. **Resource check** - Player has enough gold/items/etc.
3. **Existence check** - Item/target exists in the game
4. **Ownership check** - Player owns the item
5. **Distance check** - Player is near the interaction point
6. **Rate limiting** - Cooldown between actions
7. **Permission check** - Player has required level/access
8. **Custom validation** - Specific to your game logic

For **Action: {ActionName}({parameters})**, which validation checks are needed?

I'll generate appropriate validation code for your selections.

### Step 4.5: Parameter Alignment (Important!)

**CRITICAL**: All action handlers in a controller must accept the SAME parameters in the SAME order, even if some actions don't use all parameters.

**Why**: The `dispatchAction` method passes the same arguments to all action handlers. If handlers have different signatures, parameters will be misaligned.

**Example:**
If Action A needs `(inventory, player)` and Action B needs `(inventory, shrine, player)`:
- ❌ WRONG: Different signatures cause misalignment
- ✅ CORRECT: Both must accept `(inventory, shrine, player)` even if Action A doesn't use `shrine`

**Pattern:**
```lua
-- Both actions accept ALL parameters
local function actionA(inventory: any, shrine: any, player: Player)
    -- shrine is unused here, but MUST be in signature
    inventory:doSomething()
end

local function actionB(inventory: any, shrine: any, player: Player)
    -- Uses all parameters
    shrine:doSomething()
    inventory:doSomethingElse()
end

-- dispatchAction passes same args to both
self:dispatchAction(ACTIONS, action, player, inventory, shrine, player)
```

I will ensure all action handlers accept the union of ALL parameters needed by ANY action in the controller.

### Step 5: Review and Confirm

I'll display a comprehensive summary showing:
- Controller name and pattern (ACTIONS lookup table)
- All actions with parameters, purpose, and validation
- Models to interact with (scope and usage)
- Files to create and modify
- Network.luau changes (Controllers config and type export)

**Proceed with generation?** (Yes/No/Edit)

### Step 6: Generation

I will:
1. ✅ Read all reference files to understand the exact patterns
2. ✅ Generate complete controller file at correct location
3. ✅ Update Network.luau with controller configuration (alphabetically)
4. ✅ Update Network.luau with action type export (alphabetically)
5. ✅ Verify all model files exist (with validation step)
6. ✅ Provide comprehensive testing instructions

---

## Implementation Details (Internal)

When generating the controller, I will:

### 1. Read Reference Files

Use Read tool on:
- **AbstractController.luau** to understand base class API (intentEvent, dispatchAction)
- **CONTROLLER_GUIDE.md** for complete pattern examples and conventions
- **Network.luau** to understand current configuration and alphabetical ordering
- **Example controllers** to see patterns in practice (CashMachineController, ShrineController)

Key patterns to extract:
- Inheritance setup via setmetatable
- Type definitions with AbstractController intersection
- .new() constructor pattern
- executeAction() method signature
- ACTIONS lookup table structure
- OnServerEvent listener setup

### 2. Generate Controller File

**Location**: `Source/ServerScriptService/controllers/{ControllerName}.luau`

**Structure**:
```lua
--!strict

--[[
	{ControllerName}

	Purpose: {High-level description of controller's role}

	Actions:
	  - {ActionName}({params}): {ActionDescription}
	  [Repeat for each action]

	Models:
	  - {ModelName} ({Scope}): {Usage description}
	  [Repeat for each model]

	Usage from Client:
	  Network.Intent.{Feature}:FireServer(Network.Actions.{Feature}.{ActionName}, params...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbstractController = require(script.Parent.AbstractController)
-- Import all required models
local {ModelName} = require(script.Parent.Parent.models.{scope}.{ModelName})
[Repeat for each model]
local Network = require(ReplicatedStorage.Network)

local {ControllerName} = {}
{ControllerName}.__index = {ControllerName}
setmetatable({ControllerName}, AbstractController)

export type {ControllerName} = typeof(setmetatable({}, {ControllerName})) & AbstractController.AbstractController

-- ============================================================================
-- ACTION HANDLERS
-- ============================================================================

--[[
	{actionName} - {Action purpose}

	Parameters:
	  - {modelName}: {ModelType} - {Model description}
	  - {param1}: {type} - {Parameter description}
	  [Repeat for each parameter]
	  - player: Player - The player performing the action (always last)

	Validation:
	  - {List of validation checks being performed}
]]
local function {actionName}({modelInstances}, {actionParameters}, player: Player)
	-- Action-specific validation
	{validationCode}

	-- Business logic - update models
	{modelUpdateCalls}

	-- Debug logging
	print(player.Name .. " {action performed}: " .. {details})
end

[Repeat action handler function for each action]

-- ============================================================================
-- ACTIONS LOOKUP TABLE
-- ============================================================================

local ACTIONS = {
	[Network.Actions.{Feature}.{ActionName}] = {actionName},
	[Repeat for each action]
}

-- ============================================================================
-- CONTROLLER IMPLEMENTATION
-- ============================================================================

function {ControllerName}:executeAction(
	player: Player,
	action: Network.{Feature}Action,
	{allActionParameters}
)
	-- Shared validation (runs before action dispatch)
	{sharedValidationCode}

	-- Get required model instances
	{modelAcquisitionCode}

	-- Dispatch to action handler
	self:dispatchAction(ACTIONS, action, player, {modelInstancesAndParameters}, player)
end

function {ControllerName}.new(): {ControllerName}
	local self = AbstractController.new("{ControllerName}") :: any
	setmetatable(self, {ControllerName})

	-- Connect to Bolt ReliableEvent
	self.intentEvent.OnServerEvent:Connect(function(
		player: Player,
		action: Network.{Feature}Action,
		{parameters}
	)
		self:executeAction(player, action, {arguments})
	end)

	return self :: {ControllerName}
end

return {ControllerName}
```

### 3. Model Acquisition Code

**User-Scoped Model**:
```lua
local {modelName} = {ModelName}.get(tostring(player.UserId))
```

**Server-Scoped Model**:
```lua
local {modelName} = {ModelName}.get("SERVER")
```

**UserEntity-Scoped Model**:
```lua
-- IMPORTANT: Always use .get(), never .new()
-- .get() ensures registry registration for proper state sync
local {modelName} = {ModelName}.get(tostring(player.UserId), {entityId})
```

⚠️ **Critical for UserEntity models**: Using `.new()` instead of `.get()` creates an orphan instance that won't be tracked by AbstractModel's registry. This causes `syncState()` to fail silently - the new entity won't sync to clients until server restart.

### 4. Validation Code Templates

**Parameter Validation (number)**:
```lua
if type({param}) ~= "number" or {param} <= 0 then
	warn("Invalid {param} received from " .. player.Name .. ": " .. tostring({param}))
	return
end
```

**Parameter Validation (string)**:
```lua
if type({param}) ~= "string" or {param} == "" then
	warn("Invalid {param} received from " .. player.Name)
	return
end
```

**Parameter Validation (boolean)**:
```lua
if type({param}) ~= "boolean" then
	warn("Invalid {param} received from " .. player.Name .. ": " .. tostring({param}))
	return
end
```

**Resource Check**:
```lua
if not {model}:spend{Resource}({amount}) then
	warn(player.Name .. " attempted {action} but didn't have enough {resource}. Current: " .. {model}.{resource} .. ", Required: " .. {amount})
	return
end
```

**Existence Check**:
```lua
if not {model}:has{Item}({itemId}) then
	warn(player.Name .. " attempted to use non-existent {item}: " .. {itemId})
	return
end
```

**Ownership Check**:
```lua
if not {model}:owns{Item}({itemId}) then
	warn(player.Name .. " attempted to use {item} they don't own: " .. {itemId})
	return
end
```

**Distance Check** (requires Vector3 parameter for position):
```lua
local character = player.Character
if not character then
	warn(player.Name .. " has no character")
	return
end

local MAX_INTERACTION_DISTANCE = 20 -- studs

local distance = (character.HumanoidRootPart.Position - {targetPosition}).Magnitude
if distance > MAX_INTERACTION_DISTANCE then
	warn(player.Name .. " too far from target. Distance: " .. distance .. " studs")
	return
end
```

**Rate Limiting** (module-level):
```lua
-- Add at top of file (module level)
local COOLDOWN_TIME = 2 -- seconds
local lastActionTime: { [number]: number } = {}

-- In validation section
local lastAction = lastActionTime[player.UserId] or 0
local timeSinceLastAction = tick() - lastAction
if timeSinceLastAction < COOLDOWN_TIME then
	warn(player.Name .. " on cooldown. Wait: " .. (COOLDOWN_TIME - timeSinceLastAction) .. " seconds")
	return
end
lastActionTime[player.UserId] = tick()
```

**Permission Check** (example using player level):
```lua
local REQUIRED_LEVEL = 10

-- Assuming player has a level attribute or model has getLevel method
local playerLevel = player:GetAttribute("Level") or 1
if playerLevel < REQUIRED_LEVEL then
	warn(player.Name .. " doesn't meet level requirement. Has: " .. playerLevel .. ", Needs: " .. REQUIRED_LEVEL)
	return
end
```

### 5. Update Network.luau

**Read Current State**:
1. Read entire `Source/ReplicatedStorage/Network.luau` file
2. Parse `NetworkConfig.Controllers` table to find insertion point
3. Parse type exports section to find insertion point
4. Note existing formatting (tabs vs spaces, style)

**Insert into NetworkConfig.Controllers (alphabetically)**:
```lua
local NetworkConfig = {
	Controllers = {
		-- ... existing controllers in alphabetical order
		{Feature} = { "{Action1}", "{Action2}", "{Action3}" },
		-- ... more controllers
	},
	-- ... rest of config
}
```

**Insert Type Export (alphabetically)**:
```lua
-- Action Type Exports
-- ... existing type exports
export type {Feature}Action = "{Action1}" | "{Action2}" | "{Action3}"
-- ... more type exports
```

**Formatting Rules**:
- Maintain strict alphabetical order (by feature name for Controllers, by type name for exports)
- Use same indentation as existing entries (typically tabs)
- Trailing comma for Controllers entries
- No trailing comma for type exports
- One type per line with union operator (|) for multiple actions

### 6. Validation During Generation

Before finalizing:
- ✅ All action handler functions defined
- ✅ All actions mapped in ACTIONS table
- ✅ executeAction calls dispatchAction with correct arguments
- ✅ Model imports match model names collected
- ✅ Model acquisition uses correct scope (User vs Server)
- ✅ Type definition includes AbstractController intersection
- ✅ --!strict pragma at top of file
- ✅ Network.luau updates maintain alphabetical order
- ✅ All parameters have type annotations

### 7. Testing Instructions

After generation, provide:

```
✓ Controller Generation Complete!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created Files:
  📁 Source/ServerScriptService/controllers/{ControllerName}.luau

Modified Files:
  📝 Source/ReplicatedStorage/Network.luau
      - Added {Feature} to NetworkConfig.Controllers with {N} actions
      - Added {Feature}Action type export

Network Integration (Auto-Generated by NetworkBuilder):
  ✓ Network.Intent.{Feature} - Bolt ReliableEvent for client-server communication
  ✓ Network.Actions.{Feature} - Action constants:
      {for each action}
      - {ActionName} = "{ActionName}"

Auto-Discovery:
  ✓ ControllerRunner will automatically discover and initialize {ControllerName} on server start
  ✓ Check server console for: "ControllerRunner: Initialized controller - {ControllerName}"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Next Steps:

1. **Review Generated Controller**
   - Check validation logic matches your requirements
   - Verify model interactions are correct
   - Customize validation or business logic as needed
   - Location: Source/ServerScriptService/controllers/{ControllerName}.luau

2. **Verify Auto-Discovery**
   - Start or restart your Roblox server
   - Check Output window for initialization message
   - Verify Network.Intent.{Feature} is available

3. **Test from Client (Create a View)**

   Create a test LocalScript in StarterPlayer.StarterPlayerScripts:

   ```lua
   --!strict

   local ReplicatedStorage = game:GetService("ReplicatedStorage")
   local Network = require(ReplicatedStorage:WaitForChild("Network"))

   -- Wait for Network to initialize
   task.wait(2)

   -- Test firing an action
   print("Testing {ControllerName}...")
   Network.Intent.{Feature}:FireServer(
       Network.Actions.{Feature}.{ActionName},
       {exampleParameters}
   )

   print("Action sent! Check server Output for validation and execution logs.")
   ```

4. **Create Production View** (Optional)
   - Use CollectionService to target UI elements or 3D objects
   - Connect button clicks to Network.Intent.{Feature}:FireServer()
   - Use Network.State to observe model changes
   - See VIEW_GUIDE.md for complete patterns

5. **Test Edge Cases**
   - Invalid parameters (wrong type, out of range)
   - Missing resources (not enough gold, items, etc.)
   - Rapid-fire actions (test rate limiting if implemented)
   - Permission violations (if permission checks implemented)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Documentation:
  - CONTROLLER_GUIDE.md - Complete controller patterns and best practices
  - Network.luau - All action constants and networking infrastructure
  - AbstractController.luau - Base class reference
  - VIEW_GUIDE.md - Creating views to interact with this controller

⚠️  Important Reminders:
  - NEVER trust client data - always validate on server
  - Use Network.Actions constants, not magic strings
  - All state changes must go through Models
  - Controllers validate intents, Models enforce invariants
  - User-scoped models: player.UserId / Server-scoped: "SERVER"
  - Validation happens in controller, business logic in models
```

---

## Let's Start!

Please provide the following information to begin:

**1. Controller Name** (must end with "Controller"):
