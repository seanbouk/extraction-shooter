---
description: Create a new Roblox model with AbstractModel pattern
allowed-tools: Bash(find, cat, grep), Read, Write, Edit, Glob
model: claude-sonnet-4-5-20250929
---

I'll guide you through creating a new Roblox model that follows this project's AbstractModel architecture.

## Project Model Architecture

- **All models extend AbstractModel**
- **Three scopes**:
  - `User`: Per-player, persistent (saved to DataStore). One instance per player. Example: InventoryModel
  - `Server`: Shared, ephemeral (resets on restart). One instance for all players. Example: ShrineModel
  - `UserEntity`: Per-player, persistent (saved to DataStore). Multiple instances per player. Example: PetModel
- **File locations**:
  - User models → `Source/ServerScriptService/models/user/`
  - Server models → `Source/ServerScriptService/models/server/`
  - UserEntity models → `Source/ServerScriptService/models/userEntities/`
- **Auto-discovery**: ModelRunner automatically discovers and initializes models (no manual registration needed)

## Reference Files

Before generating code, I will read these stable reference files to ensure accuracy:
- `Source/ServerScriptService/models/AbstractModel.luau` - Base class pattern and required methods
- `Source/ReplicatedStorage/Network.luau` - Network state structure and type exports
- `MODEL_GUIDE.md` - Complete model documentation with examples and patterns

These core files contain the exact patterns, type definitions, and conventions to follow.

## Interactive Model Creation Wizard

Let's begin creating your model step by step!

### Step 1: Model Name

What should your model be named?

**Requirements**:
- Must end with "Model" (e.g., InventoryModel, ShrineModel)
- Must use PascalCase (e.g., QuestProgressModel)
- No underscores or special characters

### Step 2: Model Scope

Does this model need to be **User-scoped**, **Server-scoped**, or **UserEntity-scoped**?

- **User scope**: Per-player data that persists - one instance per player (like inventory, quest progress, player stats)
- **Server scope**: Shared data that all players see - one instance for server (like shrines, leaderboards, world state)
- **UserEntity scope**: Per-player data that persists - multiple instances per player (like pets, bases, character slots)

### Step 3: Properties

What properties does this model need?

For each property, I'll ask for:
1. **Property name** (camelCase, e.g., gold, treasureCount)
2. **Property type** (number, string, or boolean)
3. **Default value** (initial value when model is created)

**Reserved names** (cannot use): ownerId, _modelName, _scope, _stateProperty

**Note for UserEntity models**: UserEntity-scoped models automatically include a `modelId` property (managed by AbstractModel). You only need to define your custom properties here.

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
1. ✅ Read reference files to understand the exact pattern
2. ✅ Generate complete model file following the pattern exactly
3. ✅ Read Network.luau to understand state structure
4. ✅ Add Network state definition in alphabetical order
5. ✅ Add type export after existing state types
6. ✅ Provide testing instructions

---

## Implementation Details (Internal)

When generating the model, I will:

1. **Read reference files**:
   - Use Read tool on `Source/ServerScriptService/models/AbstractModel.luau` to understand the base class API
   - Read `MODEL_GUIDE.md` for complete pattern examples and conventions
   - Read `Source/ReplicatedStorage/Network.luau` to understand state structure
   - Understand: inheritance setup, type definitions, .new()/.get()/.remove() pattern
   - Note the syncState() calls in all state-modifying methods

2. **Generate model file** at correct location:
   - User scope: `Source/ServerScriptService/models/user/{ModelName}.luau`
   - Server scope: `Source/ServerScriptService/models/server/{ModelName}.luau`
   - UserEntity scope: `Source/ServerScriptService/models/userEntities/{ModelName}.luau`

3. **For UserEntity models specifically**:
   - Constructor requires `modelId` parameter: `function Model.new(ownerId: string, modelId: string)`
   - get() method requires `modelId`: `function Model.get(ownerId: string, modelId: string)`
   - remove() method requires `modelId`: `function Model.remove(ownerId: string, modelId: string)`
   - Must implement `loadAllForOwner(ownerId)` static method
   - Must implement `removeAllEntitiesForOwner(ownerId)` static method
   - See MODEL_GUIDE.md UserEntity template for complete pattern

4. **Edit Network.luau**:
   - Read current file first
   - Insert state definition in States object (alphabetically)
   - Insert type export in type exports section (alphabetically)
   - Use model name without "Model" suffix for state name (e.g., InventoryModel → Inventory)

4. **Validation during generation**:
   - Ensure all properties initialized in .new()
   - All state-modifying methods call self:syncState()
   - Type definitions include & AbstractModel.AbstractModel
   - Proper --!strict pragma at top

---

## Let's Start!

Please provide the following information to begin:

**1. Model Name** (must end with "Model"):
