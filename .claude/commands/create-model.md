---
description: Create a new Roblox model with AbstractModel pattern
allowed-tools: Bash(find, cat, grep), Read, Write, Edit, Glob
model: claude-sonnet-4-5-20250929
---

I'll guide you through creating a new Roblox model that follows this project's AbstractModel architecture.

## Project Model Architecture

- **All models extend AbstractModel**
- **Two scopes**:
  - `User`: Per-player, persistent (saved to DataStore). Each player has their own instance. Example: InventoryModel
  - `Server`: Shared, ephemeral (resets on restart). One instance for all players. Example: ShrineModel
- **File locations**:
  - User models → `Source/ServerScriptService/models/user/`
  - Server models → `Source/ServerScriptService/models/server/`
- **Auto-discovery**: ModelRunner automatically discovers and initializes models (no manual registration needed)

## Interactive Model Creation Wizard

Let's begin creating your model step by step!

### Step 1: Model Name

What should your model be named?

**Requirements**:
- Must end with "Model" (e.g., InventoryModel, ShrineModel)
- Must use PascalCase (e.g., QuestProgressModel)
- No underscores or special characters

### Step 2: Model Scope

Does this model need to be **User-scoped** or **Server-scoped**?

- **User scope**: Per-player data that persists (like inventory, quest progress, player stats)
- **Server scope**: Shared data that all players see (like shrines, leaderboards, world state)

### Step 3: Properties

What properties does this model need?

For each property, I'll ask for:
1. **Property name** (camelCase, e.g., gold, treasureCount)
2. **Property type** (number, string, or boolean)
3. **Default value** (initial value when model is created)

**Reserved names** (cannot use): ownerId, _modelName, _scope, _stateProperty

### Step 4: Method Design

Based on the properties you've defined, I'll:
1. Suggest common methods for each property type:
   - **number**: add, spend, set operations
   - **string**: set, update operations
   - **boolean**: set, toggle operations
2. Ask if any operations need to modify multiple properties together
3. Discuss invariant validation (constraints that should always be true)

**Important**: Only model-level invariants belong here (e.g., "gold >= 0"). Business logic validation (e.g., "can player afford this purchase") belongs in controllers.

### Step 5: Generation

I will:
1. ✅ Generate complete model file with all methods
2. ✅ Add Network state definition to Network.luau
3. ✅ Provide testing instructions

---

## Let's Start!

Please provide the following information to begin:

**1. Model Name** (must end with "Model"):
