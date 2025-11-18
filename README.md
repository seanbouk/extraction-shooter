# Roblox Template

An MVC-based starter template for Roblox game development with automatic DataStore synchronization. This template uses Rojo for code management, Claude Code for AI-assisted development, and the Roblox MCP server for direct Studio integration.

## MVC Architecture Overview

This template implements a strict Model-View-Controller pattern with automatic state persistence:

- **Models** (server-side): Authoritative game state that automatically syncs to DataStore
- **Views** (client-side): LocalScripts that provide responsive UI and wait for server confirmation
- **Controllers** (server-side): Listen to intents via RemoteEvents, validate, and update Models

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER INTERACTION                             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │  View (Client) │  ← LocalScript targeting tagged
                    │                │    objects in Workspace/UI
                    └───┬────────┬───┘
                        │        │
          Immediate     │        │ Send intent via
          feedback      │        │ RemoteEvent
          (visual)      │        │
                        │        ▼
                        │  ┌──────────────────┐
                        │  │ Controller       │  ← Listens to RemoteEvents
                        │  │ (Server)         │    Validates request
                        │  └────────┬─────────┘
                        │           │
                        │           ▼
                        │  ┌──────────────────┐
                        │  │ Model (Server)   │  ← Authoritative state
                        │  │                  │
                        │  └────┬─────────┬───┘
                        │       │         │
                        │       │         └─────────► DataStore
                        │       │                     (auto-sync)
                        │       ▼
                        │  ┌──────────────────┐
                        │  │ State Broadcast  │  ← RemoteEvent to clients
                        │  └────────┬─────────┘
                        │           │
                        │           ▼
                        └──────► View Updates  ← Visual state change
                                (Client)         after server confirmation
```

### Data Flow Steps

**On Player Join:**
1. **Player Joins**: PlayerAdded event fires
2. **Auto-Load**: PersistenceManager loads saved data from DataStore (or uses defaults for new players)
3. **Model Initialization**: Models are created and loaded data is applied
4. **Initial Broadcast**: Model broadcasts initial state to the player

**During Gameplay:**
1. **User Interaction**: User clicks a button, interacts with a 3D object, etc.
2. **Immediate Feedback**: View provides instant visual feedback (button animation, hover effect)
3. **Intent Sent**: View fires RemoteEvent expressing user intent (not a command)
4. **Server Validation**: Controller receives intent, validates permissions/rules
5. **Model Update**: Controller updates the appropriate Model(s)
6. **Auto-Persist**: Model change triggers automatic DataStore write (queued with rate limiting)
7. **Broadcast**: Model broadcasts state change to relevant clients
8. **View Update**: Views receive confirmation and update visual state accordingly

## MVC Components

### Models (src/server/)

Models represent authoritative game state and live exclusively on the server:

- Single source of truth for all game data
- Automatically load from DataStore when player joins (via PersistenceManager)
- Automatically persist to DataStore when state changes (via PersistenceManager)
- Broadcast state changes to clients
- Examples: PlayerInventory, GameSettings, WorldState

**[📖 See the Model Development Guide](MODEL_GUIDE.md)** for step-by-step instructions on creating models. The guide includes a complete example using `InventoryModel`.

### Controllers (src/server/)

Controllers handle business logic and orchestrate Model updates:

- Listen to RemoteEvents expressing user intent
- Validate requests (permissions, game rules, anti-cheat)
- Update Models based on validated intents
- Never directly manipulate Views
- Examples: InventoryController, CombatController, ShopController

**[📖 See the Controller Development Guide](CONTROLLER_GUIDE.md)** for step-by-step instructions on creating controllers. The guide includes a complete example using `CashMachineController`.

### Views (src/client/)

Views are LocalScripts that observe state and update visual elements:

- Use CollectionService to target tagged objects in Workspace or UI
- Provide immediate feedback for user interactions
- Wait for server confirmation before showing state changes
- Can target server-created objects (visible to all) or client-only objects
- Examples: InventoryUI, ScoreboardDisplay, InteractableObject

**[📖 See the View Development Guide](VIEW_GUIDE.md)** for step-by-step instructions on creating views. The guide includes a complete example using `CashMachineView`.

## Key Principles

### 1. Intents, Not Commands

RemoteEvents express **what the user wants to do**, not direct commands:
- Good: `RequestPurchaseItem`, `AttemptEquipWeapon`
- Bad: `SetInventory`, `UpdatePlayerGold`

### 2. Optimistic UI with Server Authority

- **Immediate feedback**: Button animations, sound effects, loading states
- **Wait for confirmation**: Inventory updates, score changes, state transitions
- **Visual feedback**: Show loading/pending states while waiting for server

### 3. Tagged Objects for Views

Views use CollectionService tags to find their targets:
- Workspace objects: `game:GetService("CollectionService"):GetTagged("ShopButton")`
- UI elements: Tagged ScreenGuis, TextButtons, Frames, etc.
- Supports both server-created and client-only objects

### 4. Separation of Concerns

- **Models**: Know nothing about Views or user input
- **Views**: Know nothing about business logic or validation
- **Controllers**: Bridge between user intent and state changes

## Project Architecture

This template enforces strict separation between code and Studio-created content:

### Code Management (Rojo)

All code must be managed through Rojo and stored in the repository:

- `src/server/` - Server-side scripts (syncs to ServerScriptService)
- `src/client/` - Client-side scripts (syncs to StarterPlayer > StarterPlayerScripts)
- `src/shared/` - Shared modules (syncs to ReplicatedStorage)

### Studio-Only Content

All UI and Workspace objects must be created directly in Roblox Studio:

- This includes: Workspace parts/models/terrain, StarterGui, UI containers, Lighting, SoundService, other service configurations, any non-code instances
- These instances are NOT synced via Rojo and will NOT be in version control
- The `$ignoreUnknownInstances: true` configuration ensures Rojo won't delete Studio-created content

## Prerequisites

1. [Rojo](https://rojo.space/) - Install the Rojo CLI and Roblox Studio plugin
2. [Claude Code](https://claude.com/claude-code) - AI-powered development assistant
3. [Roblox Studio MCP Server](https://github.com/Roblox/studio-rust-mcp-server/releases) - For Claude integration

## Claude + MCP Integration

The Roblox Studio MCP server gives Claude direct access to your running Studio instance:

- **Direct Studio access**: Execute Luau code in Roblox Studio from Claude
- **Live debugging**: Query game state, read Output, inspect Explorer hierarchy
- **Model insertion**: Add marketplace assets programmatically
- **Permissions configured** in `.claude/settings.local.json` (not tracked in git)

### Setup Steps for This Project

1. **Install the Roblox Studio MCP Server** from https://github.com/Roblox/studio-rust-mcp-server/releases
   - Download `rbx-studio-mcp.exe` to a known location (e.g., `C:\Users\YOUR_USERNAME\Downloads\`)

2. **Add MCP Server to Claude CLI** (local to this project):
   ```bash
   claude mcp add --scope local --transport stdio roblox-studio -- "C:\Users\YOUR_USERNAME\Downloads\rbx-studio-mcp.exe" --stdio
   ```

   This will add the MCP server configuration to your local `.claude.json` file for this project.

3. **Verify connection**:
   ```bash
   claude mcp list
   ```

   You should see:
   ```
   roblox-studio: C:\Users\YOUR_USERNAME\Downloads\rbx-studio-mcp.exe --stdio - ✓ Connected
   ```

4. **IMPORTANT: Restart Claude Code**
   - Exit Claude Code completely
   - Restart Claude Code
   - Resume your conversation or start a new one
   - The MCP tools will only be available after the restart

5. **Test the connection**
   - Ask Claude to run: `print("MCP test successful!")`
   - Check Roblox Studio's Output window for the message
   - If you see the output, MCP is working correctly!

### Startup Order (Critical)

Always start in this order:
1. Open Roblox Studio FIRST
2. Start Rojo (`rojo serve`)
3. Start Claude Code

### MCP Limitations (Edit Mode vs Play Mode)

**Important**: The game is NOT running while editing in Studio. MCP operates in Edit mode by default.

#### What MCP CAN do:
- Query workspace structure
- Find tagged objects
- Insert models from the marketplace
- Execute server-side code
- Read Output window contents
- Read Explorer hierarchy

#### What MCP CANNOT do:
- Test client scripts (LocalScripts don't run in Edit mode)
- Simulate player join events
- Test UI rendering
- Verify runtime initialization
- Test attribute changes/events that require the game to be running

**Solution**: Use Play mode (F5 in Studio) to test client-side behavior, UI, and gameplay.

## Development Workflow

### Building an MVC Feature

1. **Create the Model** (`src/server/models/`)
   - Define the data structure as a ModuleScript (`.lua`)
   - Call `fire()` after state changes to trigger persistence and broadcasting
   - DataStore persistence is automatic via PersistenceManager
   - Example: `PlayerInventory.lua`

2. **Create the Controller** (`src/server/controllers/`)
   - Create a Script (`.server.lua`) that listens to RemoteEvents
   - Validate incoming requests
   - Call Model methods to update state
   - Example: `InventoryController.server.lua`

3. **Create the View** (`src/client/views/`)
   - Create a LocalScript (`.client.lua`) that targets tagged objects
   - Use CollectionService to find UI/Workspace elements
   - Provide immediate feedback for interactions
   - Listen for state broadcasts and update visuals
   - Example: `InventoryView.client.lua`

4. **Create Visual Elements in Studio**
   - Build UI in StarterGui or objects in Workspace
   - Add CollectionService tags to elements the View will target
   - Example: Tag a ScreenGui with "InventoryUI"

5. **Connect with RemoteEvents** (`src/shared/events/`)
   - Define RemoteEvents as intent names
   - Place in ReplicatedStorage via `src/shared/`
   - Example: `RequestPurchaseItem`, `AttemptEquipWeapon`

### General Workflow

1. Write code in your preferred editor in the `src/` directories
2. Rojo will automatically sync your code changes to Studio
3. Create visual elements (UI, workspace objects) directly in Studio
4. Tag elements with CollectionService for Views to find them
5. Test with MCP (structural) and Play mode (behavioral)
6. Commit only code changes to git - Studio-created content stays in place file

### File Naming Conventions

- `.server.lua` - Creates a Script (server-side) - Use for Controllers
- `.client.lua` - Creates a LocalScript (client-side) - Use for Views
- `.lua` - Creates a ModuleScript - Use for Models and shared utilities
- Folders become Folder instances in Roblox

### Directory Structure Recommendation

```
src/
├── server/
│   ├── models/          # Game state (ModuleScripts)
│   ├── controllers/     # Business logic (Scripts)
│   └── services/        # Shared server utilities (e.g., PersistenceManager)
├── client/
│   ├── views/           # UI and visual logic (LocalScripts)
│   └── utilities/       # Client-side helpers
└── shared/
    ├── events/          # RemoteEvents/RemoteFunctions
    └── constants/       # Shared configuration
```

## Testing and Development Workflow

### Quick Reference: When to Use MCP vs Play Mode

| Task | MCP (Edit Mode) | Play Mode (F5) |
|------|----------------|----------------|
| **Structural Setup** |
| Create workspace objects | ✓ | |
| Set attributes on objects | ✓ | |
| Insert marketplace models | ✓ | |
| Verify object hierarchy | ✓ | |
| **Code & Script Testing** |
| Test server scripts | ✓ | ✓ |
| Test client scripts (LocalScripts) | ✗ | ✓ |
| Test module initialization | ✗ | ✓ |
| Debug print statements | ✓ (server only) | ✓ (all) |
| **UI & Interaction** |
| Create UI elements | ✓ | |
| Test UI rendering | ✗ | ✓ |
| Test button clicks | ✗ | ✓ |
| Test UI animations | ✗ | ✓ |
| **Gameplay & Events** |
| Test player join logic | ✗ | ✓ |
| Test player movement | ✗ | ✓ |
| Test collision events | ✗ | ✓ |
| Test RemoteEvents/Functions | ✗ | ✓ |

### Development Iteration Patterns

#### Pattern 1: Structural Setup (Use MCP)
```
1. Ask Claude to create workspace objects via MCP
2. Ask Claude to set attributes via MCP
3. Ask Claude to verify structure via MCP
4. Move to Pattern 2 or 3 for testing
```

#### Pattern 2: Client Behavior Testing (Use Play Mode)
```
1. Write client code in src/client/
2. Press F5 in Studio to enter Play mode
3. Check Output window for print statements
4. Verify UI rendering and interactions
5. Exit Play mode, adjust code, repeat
```

#### Pattern 3: Hybrid Workflow (Use Both)
```
1. Use MCP to verify objects exist and have correct attributes
2. Use Play mode to test actual behavior
3. Use MCP to check Output window for errors
4. Iterate
```

### Common Pitfalls and Solutions

**Pitfall**: Trying to test client scripts with MCP
- **Solution**: Always use Play mode (F5) to test LocalScripts

**Pitfall**: Forgetting to check attribute values before Play testing
- **Solution**: Ask Claude to verify attributes via MCP first

**Pitfall**: Not checking Output window during Play mode
- **Solution**: Keep Output window visible during all tests

### Best Practices

1. **Start with MCP for setup verification**: Check that objects exist and attributes are set correctly
2. **Use Play mode for actual testing**: Test all client behavior, UI, and gameplay with F5
3. **Add print statements liberally**: Use print() to debug initialization and event handling
4. **Keep Output window visible**: Watch for errors and print statements during Play mode
5. **Test incrementally**: After each change, verify it works before moving on
6. **Use MCP for quick sanity checks**: Between Play mode tests, verify structure with MCP

## Development Rules

### DO:
- Write all code in `src/` directories and sync via Rojo
- Create all UI and Workspace objects in Studio
- Commit code changes to git regularly

### DON'T:
- Try to sync Workspace or UI through Rojo
- Write code directly in Studio - always use your editor + Rojo
- Commit place files (`.rbxl`/`.rbxlx`) to git

## Error Handling Philosophy

**NEVER use fallbacks to hide configuration errors.**

### DO:
- Use `WaitForChild()` to wait for required objects to load
- Check for existing objects first before waiting for signals
- Throw clear errors when requirements aren't met
- Let the game break loudly if something is misconfigured

### DON'T:
- Add fallback values that hide missing or broken configurations
- Silently continue when required objects don't exist
- Use `warn()` and continue - use `error()` to stop execution

**Why?** Configuration errors indicate broken dependencies. Hiding these with fallbacks makes bugs harder to find. Better to fail fast and fix the root cause.

## Why This Approach?

### Benefits:
- **Version Control**: All code is tracked in git with full history
- **Editor Freedom**: Use your preferred editor with all its features
- **Studio Strengths**: Build UI and world content with Studio's visual tools
- **Clean Separation**: Clear boundary between code (git) and content (Studio)
- **Collaboration**: Team members can work on code without conflicts over place files
- **AI Integration**: Claude can access and modify code through MCP without touching place files
