---
description: Create a new Roblox view with automatic pattern detection
allowed-tools: Bash(find, cat, grep, ls), Read, Write, Edit, Glob
model: claude-sonnet-4-5-20250929
---

I'll guide you through creating a new Roblox view that follows this project's View architecture with automatic pattern detection (A, B, C, or B+C).

## Project View Architecture

- **No AbstractView base class**: Views follow consistent patterns, not inheritance
- **Three main patterns**:
  - **Pattern A**: Pure client-side feedback (particles, sounds, animations) - no server communication
  - **Pattern B**: Intent-based with server validation (send actions to controllers via Network.Intent)
  - **Pattern C**: State observation (observe model state changes via Network.State)
  - **Pattern B+C**: Combination (send intents AND observe state)
- **CollectionService pattern**: Tag instances in Roblox Studio, find them in code
- **File location**: `Source/ReplicatedFirst/views/` (LocalScripts)
- **Auto-discovery**: Views run automatically when client loads

## Reference Files

Before generating code, I will read these stable reference files to ensure accuracy:
- `Source/ReplicatedStorage/Network.luau` - Network configuration to validate controllers and states
- `VIEW_GUIDE.md` - Complete view documentation with pattern definitions and decision tree

These core files contain the exact patterns, type definitions, and available network configurations.

## Interactive View Creation Wizard

Let's begin creating your view step by step!

### Step 1: View Name

What should your view be named?

**Requirements**:
- Must end with "View" (e.g., ShopView, StatusBarView, HealthBarView)
- Must use PascalCase (e.g., TreasureChestView)
- No underscores or special characters

**Examples**:
- ✅ ShopView - Manages shop UI interactions
- ✅ HealthBarView - Displays player health
- ✅ TreasureChestView - Handles treasure chest interactions
- ❌ shop_view - Wrong case, has underscore
- ❌ View - Too generic, missing feature name
- ❌ ShopViewer - Must end with "View"

### Step 2: CollectionService Tag

What CollectionService tag will this view target?

**Important**: This tag will be applied to instances in Roblox Studio. Tags are **case-sensitive**!

**Examples**:
- View: ShopView → Tag: "Shop" or "WeaponShop"
- View: HealthBarView → Tag: "HealthBar" or "PlayerHealthUI"
- View: StatusBarView → Tag: "StatusBar"

**Tag name**:

### Step 3: Target Instance Type

What type of instance will be tagged with "{TagName}"?

**Common types**:
- **ScreenGui** - For UI in StarterGui/PlayerGui
- **BillboardGui** - For 3D UI attached to parts
- **Part/Model** - For 3D objects in Workspace
- **Other** - Specify custom type

**Instance type**:

### Step 4: User Actions (Pattern B Detection)

Does this view need to send user actions to the server?

**Examples of views that send actions**:
- ✅ Shop UI with purchase buttons → Sends "BuyItem" to ShopController
- ✅ Equipment menu with equip buttons → Sends "EquipItem" to InventoryController
- ✅ Cash machine with withdraw button → Sends "Withdraw" to CashMachineController

**Examples of views that DON'T send actions**:
- ❌ Health bar display → Only shows state, doesn't send actions
- ❌ Status bar showing gold/treasure → Read-only display

**Send user actions to server?** (Yes/No):

**If Yes**:

Which controller will handle these actions?

I will read Network.luau to validate this controller exists and show you available options.

**Controller name** (without "Controller" suffix):

**Action details**:

For each action this view will send:
1. **Action name** (e.g., "Purchase", "Equip", "Donate")
2. **What triggers it?** (button click, proximity prompt, etc.)
3. **Parameters** (if any - name and type for each)

How many actions will this view send? (1-5):

[For each action, ask: Action name, trigger, parameters]

### Step 5: State Observation (Pattern C Detection)

Does this view need to display or react to server state changes?

**Examples of views that observe state**:
- ✅ Health bar → Observes Health state to update HP display
- ✅ Status bar → Observes Inventory state to show gold/treasure
- ✅ Shop UI → Observes Inventory state to show whether player can afford items

**Examples of views that DON'T observe state**:
- ❌ One-shot particle effect → Just plays particles, no state to track

**Observe server state?** (Yes/No):

**If Yes**:

Which model's state will this view observe?

I will read Network.luau to validate this state exists and show you available options.

**State name** (without "State" suffix):

**Which properties from this state will you use?**

I will show you the available properties from Network.luau.

**Properties** (comma-separated):

**What will this view do with these properties?**
(e.g., "Update labels", "Change UI color", "Show/hide elements")

### Step 6: Immediate Feedback (Pattern A Detection)

Does this view need immediate visual or audio feedback (particles, sounds, animations)?

**Examples**:
- ✅ Particle burst when clicking a button
- ✅ Sound effect on proximity prompt trigger
- ✅ UI tween animation when hovering

**Immediate feedback?** (Yes/No):

**If Yes**:
- **Feedback types**: particles, sound, tween, other (comma-separated)
- **When triggered**: (e.g., "on button click", "on proximity prompt", "when state changes")

### Step 7: Expected Children

What child instances does this view expect to find under the tagged instance?

**Important**:
- The ROOT instance gets the CollectionService tag
- Children are accessed by name using WaitForChild()
- Names must match EXACTLY (case-sensitive)
- WaitForChild will error if hierarchy is incorrect - this is intentional!

For each child:
1. **Child name** (exact name as it will appear in Studio)
2. **Child type** (TextButton, TextLabel, Sound, ParticleEmitter, etc.)

**How many children?** (0-10):

[For each child, ask: name and type]

### Step 8: Review & Confirm

I'll display a comprehensive summary showing:
- View name and file location
- CollectionService tag and instance type
- **Detected Pattern**: A, B, C, or B+C with explanation
- Actions to send (if Pattern B)
- States to observe (if Pattern C)
- Immediate feedback (if Pattern A)
- Expected hierarchy with children
- Studio setup requirements

**Proceed with generation?** (Yes/No/Edit)

### Step 9: Generation

I will:
1. ✅ Read VIEW_GUIDE.md to understand pattern examples
2. ✅ Read Network.luau to validate controllers and states
3. ✅ Detect pattern based on your responses (A, B, C, or B+C)
4. ✅ Generate complete view file with appropriate pattern sections
5. ✅ Provide detailed Studio setup instructions

---

## Implementation Details (Internal)

When generating the view, I will:

### 1. Read Reference Files

Use Read tool on:
- **Network.luau** to:
  - Validate controller exists in NetworkConfig.Controllers
  - Validate state exists in NetworkConfig.States
  - Extract available actions for the controller
  - Extract available properties for the state
  - Generate type-safe Network.Actions and Network.State references
- **VIEW_GUIDE.md** to:
  - Understand pattern definitions and decision tree
  - Extract code examples for each pattern
  - Understand best practices

### 2. Pattern Detection

Determine pattern based on user responses:

```lua
if (sendsActions AND observesState):
    pattern = "B+C" -- Combination
    description = "Sends intents to controller AND observes model state"
elif (sendsActions):
    pattern = "B" -- Intent-Based
    description = "Sends intents to controller for server validation"
elif (observesState):
    pattern = "C" -- State Observation
    description = "Observes model state changes and updates UI"
else:
    pattern = "A" -- Pure Client-Side
    description = "Pure client-side feedback with no server communication"
```

### 3. Generate View File

**Location**: `Source/ReplicatedFirst/views/{ViewName}.client.luauu`

**Structure**:

```lua
--!strict

--[[
	{ViewName}

	Pattern: {DetectedPattern}
	Purpose: {HighLevelDescription}

	{If Pattern B:}
	Sends Intents:
	  - Network.Intent.{Controller}:FireServer(Network.Actions.{Controller}.{Action}, params...)
	  {List all actions}

	{If Pattern C:}
	Observes State:
	  - Network.State.{Model}:Observe() - Updates when {properties} change
	  {List all states}

	{If Pattern A:}
	Client-Side Feedback:
	  - {List feedback types and triggers}

	Expected Hierarchy:
	{RootInstanceType} [{RootInstanceName}] (Tagged: "{TagName}")
	{For each child:}
	├─ {ChildName} ({ChildType})
	{End for}

	Studio Setup:
	1. Create {RootInstanceType} in {Studio location}
	2. Add children: {ChildNames}
	3. Apply CollectionService tag "{TagName}" to ROOT instance only
	4. Names must match exactly (case-sensitive)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
{If B or C:}local Players = game:GetService("Players")

{If B or C:}
local Network = require(ReplicatedStorage:WaitForChild("Network"))
{If B or C:}local localPlayer = Players.LocalPlayer

{If B:}local {controller}Intent = Network.Intent.{Controller}
{If C:}local {model}State = Network.State.{Model}

local TAG_NAME = "{TagValue}"
{If A with constants:}local {CONSTANT_NAME} = {value}

{If C and observation is module-level:}
-- ============================================================================
-- STATE OBSERVATION (Pattern C)
-- ============================================================================

-- Observe {model} state changes
{model}State:Observe(function(data: Network.{Model}State)
	-- Update all tagged instances
	for _, instance in CollectionService:GetTagged(TAG_NAME) do
		-- Find UI elements
		local {child} = instance:FindFirstChild("{ChildName}", true)
		if {child} then
			-- Update UI with state
			{child}.Text = `{property}: {data.{property}}`
		end
	end
end)

-- ============================================================================
-- INSTANCE SETUP
-- ============================================================================

local function setupInstance(instance: Instance)
	{For each child:}
	local {childName} = instance:WaitForChild("{ChildName}") :: {ChildType}

	{If B - connect interactions:}
	{trigger}.{Event}:Connect(function({eventParams})
		{If localPlayer check needed:}
		if {param} ~= localPlayer then
			return
		end

		{If A - immediate feedback:}
		-- Immediate visual/audio feedback
		{feedbackCode}

		{If B - send intent:}
		-- Send intent to server
		{controller}Intent:FireServer(
			Network.Actions.{Controller}.{Action}{If parameters:},
			{param1}, {param2}
		)
	end)

	{If C and observation is instance-level:}
	-- Observe state changes for this instance
	{model}State:Observe(function(data: Network.{Model}State)
		-- Update this instance
		{updateCode}
	end)

	print(`{ViewName}: Setup complete for {instance.Name}`)
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

print("{ViewName}: Initialized")
```

### 4. Pattern-Specific Code Generation

**Pattern A - Pure Client Feedback:**
```lua
-- Example: Particle effect on proximity
proximityPrompt.Triggered:Connect(function(player: Player)
	if player ~= localPlayer then
		return
	end

	particleEmitter:Emit(20)
	sound:Play()
end)
```

**Pattern B - Intent-Based:**
```lua
-- Example: Button sends purchase intent
button.Activated:Connect(function()
	shopIntent:FireServer(
		Network.Actions.Shop.BuyItem,
		itemId,
		quantity
	)
end)
```

**Pattern C - State Observation (Module-Level):**
```lua
-- Before setupInstance function
inventoryState:Observe(function(data: Network.InventoryState)
	-- Update all status bars
	for _, instance in CollectionService:GetTagged(TAG_NAME) do
		local goldLabel = instance:FindFirstChild("GoldLabel", true)
		if goldLabel then
			goldLabel.Text = `Gold: {data.gold}`
		end
	end
end)
```

**Pattern C - State Observation (Instance-Level):**
```lua
-- Inside setupInstance function
healthState:Observe(function(data: Network.HealthState)
	-- Update this specific health bar
	healthBar.Size = UDim2.new(data.currentHealth / data.maxHealth, 0, 1, 0)
	healthLabel.Text = `{data.currentHealth}/{data.maxHealth}`
end)
```

**Pattern B+C - Combination:**
```lua
-- Module-level state observation
inventoryState:Observe(function(data: Network.InventoryState)
	currentGold = data.gold
	-- Update affordability UI
end)

-- In setupInstance - button sends intent
buyButton.Activated:Connect(function()
	shopIntent:FireServer(Network.Actions.Shop.BuyItem, itemId)
end)
```

### 5. Validation During Generation

Before finalizing:
- ✅ CollectionService tag is used correctly
- ✅ All children accessed via WaitForChild with type annotations
- ✅ Network.Intent used correctly for Pattern B (if applicable)
- ✅ Network.State.Observe used correctly for Pattern C (if applicable)
- ✅ Network.Actions constants used for type-safe action dispatch
- ✅ Type annotations include Network exported types
- ✅ --!strict pragma at top of file
- ✅ Pattern matches user's stated needs
- ✅ Controllers and states validated against Network.luau

### 6. Testing Instructions

After generation, provide:

```
✓ View Generation Complete!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created Files:
  📁 Source/ReplicatedFirst/views/{ViewName}.client.luau

Pattern Detected: {Pattern} ({PatternDescription})

{If Pattern B:}
Network Integration (Already Configured):
  ✓ Network.Intent.{Controller} - Bolt ReliableEvent for sending intents
  ✓ Network.Actions.{Controller}.{Action} - Type-safe action constants

  Actions this view sends:
    {For each action:}
    - {ActionName}({parameters})

{If Pattern C:}
Network Integration (Already Configured):
  ✓ Network.State.{Model} - Bolt RemoteProperty for state observation
  ✓ Network.{Model}State - Type definition for state data

  Properties observed: {propertyList}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Studio Setup Requirements:

⚠️  IMPORTANT: Follow these steps EXACTLY in Roblox Studio

1. **Create the root instance**
   - Type: {RootInstanceType}
   - Location: {Where to create it - StarterGui for UI, Workspace for 3D}
   - Name: {SuggestedName} (or any name you prefer)

2. **Add required children**

   Expected hierarchy:
   ```
   {RootInstanceType} [{ExampleName}]
   {For each child:}
   ├─ {ChildName} ({ChildType})
   {End for}
   ```

   ⚠️  Child names must match EXACTLY (case-sensitive!)

3. **Apply CollectionService tag**
   - Open Tags window: View → Tags (or press Alt+T)
   - Select the ROOT instance only ({RootInstanceType})
   - Add tag: "{TagName}"
   - ⚠️  Tag is case-sensitive! Must be exactly "{TagName}"
   - DO NOT tag the children, only the root instance

4. **Save and test**
   - Save the place
   - Start Play mode (F5)
   - Check Output window for:
     ✓ "{ViewName}: Initialized"
     ✓ "{ViewName}: Setup complete for {instance name}"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Next Steps:

1. **Verify auto-discovery**
   - View should initialize automatically when client loads
   - Check Output for initialization messages
   - If you don't see messages, check tag spelling

2. **Test functionality**
   {If Pattern B:}
   - Trigger the action (click button, use proximity prompt, etc.)
   - Check server Output for controller processing
   - Verify model state updates

   {If Pattern C:}
   - Change the model state from server
   - Verify UI updates automatically
   - Check that state displays correctly

   {If Pattern A:}
   - Trigger the feedback (click, hover, proximity, etc.)
   - Verify particles, sounds, or animations play
   - Ensure feedback is immediate

3. **Common issues**

   ❌ "View not initializing"
   - Check: Is the tag spelled exactly "{TagName}"? (case-sensitive)
   - Check: Is the tag on the ROOT instance, not children?
   - Check: Did you save the place after adding the tag?

   ❌ "WaitForChild timeout error"
   - This is INTENTIONAL - it means hierarchy is incorrect
   - Check: Do child names match exactly? (case-sensitive)
   - Check: Are children actually present under the tagged instance?
   - Fix: Correct the hierarchy in Studio to match expected structure

   {If Pattern B:}
   ❌ "Intent not working"
   - Check: Is the controller initialized? (check server Output)
   - Check: Are you using Network.Actions.{Controller}.{Action} constant?
   - Check: Does {Controller}Controller exist and handle this action?

   {If Pattern C:}
   ❌ "State not updating"
   - Check: Is the model initialized? (check server Output)
   - Check: Is the model calling syncState() after changes?
   - Check: Is Network.State.{Model} available? (check client Output)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Documentation:
  - VIEW_GUIDE.md - Complete guide to view patterns and best practices
  - Network.luau - Your network configuration (intents, states, actions)

⚠️  Important Reminders:
  - Views run on CLIENT - display and feedback only
  - NEVER trust client data - server always validates
  - Tag is case-sensitive and goes on ROOT instance only
  - Child names must match exactly (case-sensitive)
  - WaitForChild errors are INTENTIONAL - they indicate incorrect setup
  {If Pattern B:}
  - Use Network.Actions constants, not magic strings
  - Immediate feedback before server confirmation is good UX
  {If Pattern C:}
  - Observe() fires immediately with current state - no need to request
  - Bolt handles per-player filtering for User-scoped models automatically
```

---

## Let's Start!

Please provide the following information to begin:

**1. View Name** (must end with "View"):
