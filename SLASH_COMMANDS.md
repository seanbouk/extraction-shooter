# Slash Commands Guide

This guide explains the slash command system for admin/debug functionality in-game.

## What are Slash Commands?

Slash commands provide a quick way for high-rank users (developers, moderators, admins) to execute model methods and controller actions directly from the chat window for testing and debugging purposes.

**Key Features:**
- **Convention-based**: Any model method or controller action automatically becomes a slash command - zero configuration needed
- **Permission-based**: Only users with rank 200+ in the owning group can use commands
- **Auto-discovered**: Commands are automatically registered when the server starts
- **Type-safe**: Arguments are automatically parsed to numbers, booleans, or strings

## Architecture Overview

The slash command system consists of two components:

- **SlashCommandService** (server): Discovers models and controllers, validates permissions, executes commands
- **SlashCommandClient** (client): Listens to TextChatService and sends commands to server

```
┌─────────────────────────────────────────────────────────────────────┐
│                     USER TYPES SLASH COMMAND                         │
│             /inventorymodel addGold 100  OR  /bazaarcontroller BuyTreasure │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
                   ┌──────────────────────┐
                   │ SlashCommandClient   │  ← Client-side utility
                   │ (Client)             │    Intercepts chat commands
                   └──────────┬───────────┘
                              │
                              │ RemoteEvent:FireServer()
                              │
                              ▼
                   ┌──────────────────────┐
                   │ SlashCommandService  │  ← Server-side service
                   │ (Server)             │    Validates & executes
                   └──────────┬───────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
       ┌────────────────┐         ┌────────────────┐
       │ Model Method   │         │ Controller     │
       │ Execution      │         │ RemoteEvent    │
       └────────┬───────┘         └────────┬───────┘
                │                          │
                │                          │ Fires existing RemoteEvent
                │                          │
                ▼                          ▼
       ┌────────────────┐         ┌────────────────┐
       │ State Broadcast│         │ Controller     │
       │                │         │ OnServerEvent  │ ← Uses existing logic
       └────────────────┘         └────────┬───────┘
                                           │
                                           ▼
                                  ┌────────────────┐
                                  │ Model Update & │
                                  │ State Broadcast│
                                  └────────────────┘
```

## Using Slash Commands

### Command Format

**Model Commands:**
```
/modelname methodname arg1 arg2 ...
```

**Controller Commands:**
```
/controllername actionname arg1 arg2 ...
```

**Model Examples:**
```
/inventorymodel addGold 100
/inventorymodel addTreasure 5
/inventorymodel spendGold 50
/shrinemodel donate 123456789 10
```

**Controller Examples:**
```
/bazaarcontroller BuyTreasure
/cashmachinecontroller Withdraw 100
/cashmachinecontroller Deposit 50
/shrinecontroller Donate
```

### Permission Requirements

Commands are only available to users who meet these criteria:

- **Group-owned games**: User must have rank 200+ in the group that owns the game
- **User-owned games**: All users can use commands (for testing in Studio)

The group ID is **automatically detected** when the server starts - no configuration needed!

## Available Commands

Commands are automatically generated for all models and controllers. The available commands depend on what you've created:

### User-Scoped Models

User-scoped models (in `src/server/models/user/`) operate on the player's own data.

**Example - InventoryModel:**
- `/inventorymodel addGold 100` - Add 100 gold to your inventory
- `/inventorymodel addTreasure 5` - Add 5 treasure to your inventory
- `/inventorymodel spendGold 50` - Remove 50 gold from your inventory
- `/inventorymodel spendTreasure 2` - Remove 2 treasure from your inventory

### Server-Scoped Models

Server-scoped models (in `src/server/models/server/`) operate on shared server state.

**Example - ShrineModel:**
- `/shrinemodel donate 123456789 100` - Donate 100 treasure to shrine with player ID

### Controller Actions

Controller commands (in `src/server/controllers/`) trigger controller actions with full validation.

**Example - BazaarController:**
- `/bazaarcontroller BuyTreasure` - Purchase treasure (costs 200 gold, adds 1 treasure)

**Example - CashMachineController:**
- `/cashmachinecontroller Withdraw 100` - Withdraw 100 gold (adds to inventory)
- `/cashmachinecontroller Deposit 50` - Deposit 50 gold (removes from inventory)

**Example - ShrineController:**
- `/shrinecontroller Donate` - Donate 1 treasure to the shrine

## How It Works

### Automatic Discovery

When the server starts:

1. **ModelRunner** discovers all models in `src/server/models/user/` and `src/server/models/server/`
2. **ControllerRunner** discovers all controllers in `src/server/controllers/`
3. **SlashCommandService** registers each discovered model and controller
4. **TextChatCommands** are created for autocomplete in chat

When the client starts:

1. **SlashCommandClient** waits for TextChatCommands to be created
2. Listens for command triggers from TextChatService
3. Sends commands to server via RemoteEvent

### Command Execution Flow

**For Model Commands:**

1. **Client**: TextChatService detects the command
2. **Client**: SlashCommandClient sends command string to server
3. **Server**: SlashCommandService validates your rank/permissions
4. **Server**: Parses command into model name, method name, and arguments
5. **Server**: Gets the appropriate model instance (your user model or server model)
6. **Server**: Calls the method with parsed arguments
7. **Model**: Method executes, updates state, calls `fire()` to broadcast
8. **Client**: Your views update automatically via normal MVC state flow

**For Controller Commands:**

1. **Client**: TextChatService detects the command
2. **Client**: SlashCommandClient sends command string to server
3. **Server**: SlashCommandService validates your rank/permissions
4. **Server**: Parses command into controller name, action name, and arguments
5. **Server**: Fires the controller's RemoteEvent: `remoteEvent:Fire(player, action, args...)`
6. **Controller**: OnServerEvent handler receives the event (same as if client sent it)
7. **Controller**: Validates request, gets models, executes action handler
8. **Model**: Updates state, calls `fire()` to broadcast
9. **Client**: Your views update automatically via normal MVC state flow

**Key Difference:** Controller commands reuse the controller's existing RemoteEvent and validation logic, ensuring the same behavior as normal gameplay actions.

### Argument Parsing

Arguments are automatically converted to appropriate types:

| Input | Parsed As | Example |
|-------|-----------|---------|
| `100` | `number` | `/inventorymodel addGold 100` |
| `true` or `false` | `boolean` | `/somemodel setFlag true` |
| `"text"` | `string` | `/shrinemodel donate 123456789 10` |

## Creating Slash-Command-Friendly Models

No special code is needed! Just create models following the normal MVC pattern:

```lua
-- src/server/models/user/InventoryModel.lua

function InventoryModel:addGold(amount: number): ()
    self.gold += amount
    self:fire("owner")  -- This broadcasts to client as normal
end
```

That's it! The `/inventorymodel addGold 100` command is now automatically available.

### Best Practices

**✅ DO:**
- Create descriptive method names (they become command names)
- Use type annotations for parameters (helps with debugging)
- Follow normal model patterns with `fire()` for state updates
- Use commands for testing and debugging during development

**❌ DON'T:**
- Don't use slash commands for normal gameplay (use Views + Controllers instead)
- Don't create commands that bypass important validation logic
- Don't expose dangerous methods that could break game state

## Customizing Slash Commands

### Changing Rank Requirement

Edit `SlashCommandService.lua` line 26:

```lua
local MIN_RANK = 200  -- Change to your desired rank
```

### Disabling for Specific Models

Slash commands work for ALL models by default. To prevent a model from being accessible via slash commands, you would need to add filtering logic to SlashCommandService or mark the model as private (currently not supported - all models are accessible).

### Group ID Detection

The group ID is automatically detected in `SlashCommandService:init()`:

```lua
if game.CreatorType == Enum.CreatorType.Group then
    groupId = game.CreatorId  -- Automatically uses the owning group
else
    -- Game owned by user - allow all players (useful for Studio testing)
end
```

This works automatically across all your games - no hardcoding needed!

## Debugging

### Console Logging

The slash command system includes comprehensive logging:

**Client Console:**
```
[SlashCommandClient] Found TextChatCommands with 2 commands
[SlashCommandClient] Registering listener for command: /inventorymodel
[SlashCommandClient] Command triggered: /inventorymodel with text: "/inventorymodel addGold 100"
[SlashCommandClient] Sending to server: "inventorymodel addGold 100"
```

**Server Console:**
```
[SlashCommandService] Game owned by group 12345678. Rank 200+ required.
[SlashCommand] Received command from PlayerName: "inventorymodel addGold 100"
[SlashCommand] Permission check passed for PlayerName
[SlashCommand] Parsed 3 parts from command
[SlashCommand] Target: inventorymodel, Method: addGold, Args: 1
[SlashCommand] SUCCESS - PlayerName: Executed InventoryModel:addGold
```

### Common Issues

**"Unknown slash command"**
- The TextChatCommand wasn't created - check that SlashCommandService initialized
- Check server console for `[SlashCommandService] Total models registered: X`

**"Nothing happens when I type command"**
- Check client console for SlashCommandClient initialization
- Verify you're typing the command correctly: `/modelname methodname args`

**"Permission denied"**
- Check your rank in the group: must be 200+
- Server console will show your current rank when denied
- In Studio (user-owned place), all commands should work

**"Method not found"**
- Verify the method exists on the model class
- Check spelling - command is case-sensitive
- Method must be a public function on the model instance

## File Structure

```
src/
├── server/
│   ├── models/
│   │   ├── user/           ← User-scoped models (commands operate on player data)
│   │   │   └── InventoryModel.lua
│   │   ├── server/         ← Server-scoped models (commands operate on server data)
│   │   │   └── ShrineModel.lua
│   │   └── ModelRunner.server.lua  ← Registers models with SlashCommandService
│   └── services/
│       └── SlashCommandService.lua  ← Server-side command handler
└── client/
    └── SlashCommandClient.client.lua  ← Client-side command listener
```

## Summary

Slash commands provide a **zero-configuration admin tool system**:

1. ✅ **No setup required** - Just create models and controllers normally
2. ✅ **Automatic discovery** - Commands appear when models/controllers are registered
3. ✅ **Permission-controlled** - Only high-rank users can execute
4. ✅ **Type-safe** - Arguments auto-parsed to correct types
5. ✅ **MVC-compliant** - Uses normal state broadcast flow
6. ✅ **Controller support** - Reuses existing validation and RemoteEvents

Use them for testing, debugging, and admin actions - but remember that normal gameplay should use the full MVC pattern (Views → Controllers → Models) for proper validation and security!
