# Bolt API Reference

Bolt is a high-performance networking library for Roblox that provides efficient alternatives to RemoteEvents, RemoteFunctions, and replicated properties. It achieves superior bandwidth efficiency through binary serialization and automatic message batching.

## Table of Contents

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Core API](#core-api)
  - [ReliableEvent](#reliableevent)
  - [RemoteProperty](#remoteproperty)
  - [RemoteFunction](#remotefunction)
- [Serialization](#serialization)
  - [Default Serializer](#default-serializer)
  - [Custom Serializers](#custom-serializers)
- [BufferWriter API](#bufferwriter-api)
- [BufferReader API](#bufferreader-api)
- [Performance Characteristics](#performance-characteristics)
- [Best Practices](#best-practices)
- [Known Issues & Limitations](#known-issues--limitations)
- [Complete Examples](#complete-examples)

## Introduction

### What is Bolt?

Bolt is a networking library that replaces Roblox's built-in RemoteEvents and RemoteFunctions with a more efficient implementation. It uses binary buffer serialization and batches multiple messages into single network packets, significantly reducing bandwidth usage.

### When to Use Bolt

Use Bolt when:
- Your game has high-frequency network updates (shooting, racing, real-time actions)
- Bandwidth is a bottleneck for your game
- You have many small messages being sent frequently
- You need to optimize for large player counts

### When NOT to Use Bolt

Don't use Bolt when:
- You're building a simple game with infrequent network communication
- Your team is unfamiliar with binary serialization concepts
- You need the absolute simplest possible networking setup
- Built-in RemoteEvents already meet your performance needs

For most projects, Roblox's built-in networking is sufficient. Bolt adds complexity and should only be adopted when you have a proven need for optimization.

## Quick Start

### Basic Setup

```lua
-- ReplicatedStorage.BoltEvents (ModuleScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bolt = require(ReplicatedStorage.Bolt)

return {
    PlayerJumped = Bolt.ReliableEvent("PlayerJumped"),
    ChatMessage = Bolt.ReliableEvent("ChatMessage"),
}
```

### Server-Side Usage

```lua
-- ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoltEvents = require(ReplicatedStorage.BoltEvents)

-- Listen for client events
BoltEvents.PlayerJumped.OnServerEvent:Connect(function(player, jumpHeight)
    print(player.Name, "jumped", jumpHeight, "studs")

    -- Validate and broadcast to all clients
    if jumpHeight > 0 and jumpHeight < 100 then
        BoltEvents.PlayerJumped:FireAllClients(player.Name, jumpHeight)
    end
end)

-- Send to specific player
BoltEvents.ChatMessage:FireClient(player, "Welcome to the game!")

-- Send to all players
BoltEvents.ChatMessage:FireAllClients("Server announcement!")
```

### Client-Side Usage

```lua
-- StarterPlayer.StarterPlayerScripts (LocalScript)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BoltEvents = require(ReplicatedStorage.BoltEvents)

-- Listen for server events
BoltEvents.ChatMessage.OnClientEvent:Connect(function(message)
    print("Received message:", message)
end)

-- Send to server
local UserInputService = game:GetService("UserInputService")
UserInputService.JumpRequest:Connect(function()
    local character = game.Players.LocalPlayer.Character
    if character then
        BoltEvents.PlayerJumped:FireServer(50)
    end
end)
```

## Core API

### ReliableEvent

Creates a networked event that can send data between server and clients. Messages are batched and sent every Heartbeat.

#### Creation

```lua
Bolt.ReliableEvent<T...>(
    eventName: string,
    serializer: ((writer: BufferWriter, T...) -> ())?,
    deserializer: ((reader: BufferReader) -> T...)?
): ReliableEvent<T...>
```

**Parameters:**
- `eventName` - Unique identifier for this event
- `serializer` - Optional custom function to serialize data (default uses automatic serialization)
- `deserializer` - Optional custom function to deserialize data (must match serializer)

**Returns:** ReliableEvent object with client/server methods

#### Methods

##### FireServer (Client Only)

```lua
event:FireServer(...)
```

Sends data from client to server. The server receives this via `OnServerEvent`.

**Example:**
```lua
DamageEvent:FireServer(targetPlayer, 25)
```

##### FireClient (Server Only)

```lua
event:FireClient(player: Player, ...)
```

Sends data from server to a specific client.

**Parameters:**
- `player` - Target player to receive the message
- `...` - Data to send (must match type signature)

**Example:**
```lua
RewardEvent:FireClient(player, "Gold", 100)
```

##### FireAllClients (Server Only)

```lua
event:FireAllClients(...)
```

Sends data from server to all connected clients.

**Example:**
```lua
ExplosionEvent:FireAllClients(Vector3.new(0, 10, 0), 50)
```

#### Properties

##### OnClientEvent (Client Side)

```lua
event.OnClientEvent:Connect(function(...)
    -- Handle data from server
end)
```

Fired when the client receives data from the server.

##### OnServerEvent (Server Side)

```lua
event.OnServerEvent:Connect(function(player: Player, ...)
    -- Handle data from client
    -- First parameter is always the player who sent it
end)
```

Fired when the server receives data from a client. The first parameter is always the Player who sent the event.

#### Complete Example

```lua
-- Module
local CombatEvent = Bolt.ReliableEvent("PlayerAttack")

-- Server
CombatEvent.OnServerEvent:Connect(function(player, targetName, damage)
    -- Validate
    if damage > 100 then return end

    local target = game.Players:FindFirstChild(targetName)
    if target then
        -- Process damage
        local humanoid = target.Character and target.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Health -= damage

            -- Notify all clients
            CombatEvent:FireAllClients(player.Name, targetName, damage)
        end
    end
end)

-- Client
CombatEvent.OnClientEvent:Connect(function(attackerName, victimName, damage)
    print(attackerName, "dealt", damage, "damage to", victimName)
end)
```

### RemoteProperty

A replicated value that automatically synchronizes from server to clients. Clients can observe changes, and the server can set global or per-player values.

#### Creation

```lua
Bolt.RemoteProperty<T>(
    propertyName: string,
    defaultValue: T,
    serializer: ((writer: BufferWriter, T) -> ())?,
    deserializer: ((reader: BufferReader) -> T)?
): RemoteProperty<T>
```

**Parameters:**
- `propertyName` - Unique identifier for this property
- `defaultValue` - Initial value for all clients
- `serializer` - Optional custom serialization function
- `deserializer` - Optional custom deserialization function

#### Methods

##### Get (Client & Server)

```lua
property:Get(): T
```

Returns the current value. On client, returns the value received from server. On server, returns the global value.

**Example:**
```lua
local currentRound = RoundNumberProperty:Get()
```

##### Set (Server Only)

```lua
property:Set(newValue: T)
```

Sets the global value and broadcasts to all clients.

**Example:**
```lua
RoundNumberProperty:Set(5)
```

##### GetFor (Server Only)

```lua
property:GetFor(player: Player): T
```

Gets the value for a specific player (either their override or the global value).

**Example:**
```lua
local playerSpeed = SpeedProperty:GetFor(player)
```

##### SetFor (Server Only)

```lua
property:SetFor(player: Player, newValue: T)
```

Sets a player-specific override. This player will receive this value instead of the global value.

**Example:**
```lua
-- Give one player a special speed boost
SpeedProperty:SetFor(player, 32)
```

##### ClearFor (Server Only)

```lua
property:ClearFor(player: Player)
```

Removes a player-specific override, reverting them to the global value.

**Example:**
```lua
SpeedProperty:ClearFor(player)
```

##### Observe (Client & Server)

```lua
property:Observe(callback: (value: T) -> ()): () -> ()
```

Subscribes to value changes. The callback is immediately invoked with the current value, then called again whenever the value changes.

**Returns:** Cleanup function to unsubscribe

**Example:**
```lua
local disconnect = GameStateProperty:Observe(function(newState)
    print("Game state changed to:", newState)
    updateUI(newState)
end)

-- Later, to stop observing:
disconnect()
```

#### Complete Example

```lua
-- Module
local GameSpeed = Bolt.RemoteProperty("GameSpeed", 1.0)

-- Server
local function setGlobalSpeed(speed)
    GameSpeed:Set(speed)
end

local function givePlayerSpeedBoost(player)
    GameSpeed:SetFor(player, 2.0)

    task.wait(10)

    GameSpeed:ClearFor(player) -- Revert to global speed
end

-- Client
GameSpeed:Observe(function(speed)
    -- Update local physics/animations based on speed
    workspace.CurrentCamera.FieldOfView = 70 + (speed * 10)
end)
```

### RemoteFunction

Implements a request-response pattern where the client can invoke server functions and receive a return value.

#### Creation

```lua
Bolt.RemoteFunction<T..., R...>(functionName: string): RemoteFunction<T..., R...>
```

**Parameters:**
- `functionName` - Unique identifier for this function

**Type Parameters:**
- `T...` - Input parameter types
- `R...` - Return value types

#### Methods

##### InvokeServer (Client Only)

```lua
remoteFunction:InvokeServer(...: T...): R...
```

Calls the server function and yields until a response is received.

**Example:**
```lua
local success, itemName = PurchaseFunction:InvokeServer("Sword", 100)
if success then
    print("Purchased:", itemName)
end
```

#### Properties

##### OnServerInvoke (Server Only)

```lua
remoteFunction.OnServerInvoke = function(player: Player, ...: T...): R...
    -- Process request and return result
end
```

Must be set to a function that handles client requests. The first parameter is always the player making the request.

**Example:**
```lua
local PurchaseFunction = Bolt.RemoteFunction("PurchaseItem")

PurchaseFunction.OnServerInvoke = function(player, itemName, cost)
    local playerData = getPlayerData(player)

    if playerData.coins >= cost then
        playerData.coins -= cost
        grantItem(player, itemName)
        return true, itemName
    else
        return false, "Insufficient funds"
    end
end
```

#### Complete Example

```lua
-- Module
local RequestData = Bolt.RemoteFunction("RequestPlayerData")

-- Server
RequestData.OnServerInvoke = function(player, dataKey)
    local data = PlayerDataStore:GetAsync(player.UserId .. "_" .. dataKey)
    return data
end

-- Client
local function loadPlayerStats()
    local stats = RequestData:InvokeServer("stats")
    if stats then
        updateStatsUI(stats)
    end
end
```

## Serialization

### Default Serializer

Bolt includes an automatic serializer that handles most common Roblox types. When you don't provide custom serializer/deserializer functions, this default is used.

#### Supported Types

**Primitives:**
- `boolean` - True/false values
- `number` - All Luau numbers (stored as F64)
- `string` - Text data (up to 255 characters per string)
- `buffer` - Raw buffer data

**Roblox Types:**
- `Instance` - References to game objects
- `Vector2` - 2D vectors (stored as 2x F32)
- `Vector3` - 3D vectors (stored as 3x F32)
- `CFrame` - Position and rotation (position as 3x F32, rotation as 3x I16)
- `Color3` - RGB colors (stored as 3x U8)
- `EnumItem` - Roblox enum values

**Complex Types:**
- `table` - Arrays and dictionaries (recursively serialized)

#### Limitations

- Tables can only contain serializable types as keys and values
- Circular references are not supported
- Metatables are not preserved
- Functions cannot be serialized
- Userdata (other than supported Roblox types) cannot be serialized
- Strings longer than 255 characters need custom serialization

#### Example

```lua
-- These work automatically without custom serializers
local PlayerUpdate = Bolt.ReliableEvent("PlayerUpdate")

-- Server
PlayerUpdate:FireClient(player, {
    position = Vector3.new(0, 10, 0),
    health = 100,
    isJumping = false,
    equipment = {"Sword", "Shield"},
    color = Color3.fromRGB(255, 0, 0)
})
```

### Custom Serializers

Custom serializers give you precise control over how data is encoded, allowing for significant bandwidth savings.

#### When to Use Custom Serializers

Use custom serializers when:
- You know the exact range of your data (e.g., health is always 0-100)
- You have repeated data structures being sent frequently
- You need to serialize data types not supported by default
- You want to minimize bandwidth for high-frequency messages

#### Creating Custom Serializers

Custom serializers are pairs of functions: one for writing (serializer) and one for reading (deserializer).

```lua
local MyEvent = Bolt.ReliableEvent(
    "MyEvent",
    function(writer: BufferWriter, ...) -- Serializer
        -- Write data to buffer
    end,
    function(reader: BufferReader) -- Deserializer
        -- Read data from buffer
        return ... -- Return the deserialized data
    end
)
```

#### Example: Health Update

```lua
-- Instead of sending health as F64 (8 bytes), use U8 (1 byte)
local HealthUpdate = Bolt.ReliableEvent(
    "HealthUpdate",
    function(writer, health, maxHealth)
        writer:WriteU8(health)    -- 0-255
        writer:WriteU8(maxHealth) -- 0-255
    end,
    function(reader)
        local health = reader:ReadU8()
        local maxHealth = reader:ReadU8()
        return health, maxHealth
    end
)

-- Usage is the same as any ReliableEvent
HealthUpdate:FireClient(player, 75, 100)
```

#### Example: Position Update with Reduced Precision

```lua
-- Send position with less precision to save bandwidth
-- Instead of Vector3 (12 bytes), use 3x I16 (6 bytes)
local PositionUpdate = Bolt.ReliableEvent(
    "PositionUpdate",
    function(writer, position)
        -- Convert float position to integers with 0.1 precision
        writer:WriteI16(math.round(position.X * 10))
        writer:WriteI16(math.round(position.Y * 10))
        writer:WriteI16(math.round(position.Z * 10))
    end,
    function(reader)
        -- Convert back to float
        local x = reader:ReadI16() / 10
        local y = reader:ReadI16() / 10
        local z = reader:ReadI16() / 10
        return Vector3.new(x, y, z)
    end
)
```

#### Example: Complex Player State

```lua
local PlayerState = Bolt.ReliableEvent(
    "PlayerState",
    function(writer, state)
        writer:WriteU8(state.health)
        writer:WriteU8(state.stamina)
        writer:WriteB8(state.isRunning, state.isJumping, state.isCrouching)
        writer:WriteVector3(state.position)
        writer:WriteU16(state.score)
    end,
    function(reader)
        local state = {}
        state.health = reader:ReadU8()
        state.stamina = reader:ReadU8()

        local bools = reader:ReadB8()
        state.isRunning = bools[1]
        state.isJumping = bools[2]
        state.isCrouching = bools[3]

        state.position = reader:ReadVector3()
        state.score = reader:ReadU16()

        return state
    end
)
```

## BufferWriter API

BufferWriter is used in custom serializers to write data to a binary buffer. Writers are automatically created and managed by Bolt - you only need to use them in your serializer functions.

### Creation Methods

#### new

```lua
BufferWriter.new(size: number): BufferWriter
```

Creates a new writer with a buffer of the specified size.

**Note:** Bolt manages this for you - you typically don't call this directly.

### Write Methods

#### WriteB8

```lua
writer:WriteB8(...boolean)
```

Writes up to 8 boolean values as a single byte. Efficient for packing multiple flags.

**Example:**
```lua
writer:WriteB8(true, false, true) -- Uses 1 byte for 3 booleans
```

#### WriteU8

```lua
writer:WriteU8(value: number)
```

Writes an unsigned 8-bit integer (0 to 255). Uses 1 byte.

**Example:**
```lua
writer:WriteU8(100) -- Health value
```

#### WriteU16

```lua
writer:WriteU16(value: number)
```

Writes an unsigned 16-bit integer (0 to 65,535). Uses 2 bytes.

**Example:**
```lua
writer:WriteU16(5000) -- Score value
```

#### WriteU24

```lua
writer:WriteU24(value: number)
```

Writes an unsigned 24-bit integer (0 to 16,777,215). Uses 3 bytes.

#### WriteU32

```lua
writer:WriteU32(value: number)
```

Writes an unsigned 32-bit integer (0 to 4,294,967,296). Uses 4 bytes.

#### WriteU40

```lua
writer:WriteU40(value: number)
```

Writes an unsigned 40-bit integer (0 to 1,099,511,627,775). Uses 5 bytes.

#### WriteU56

```lua
writer:WriteU56(value: number)
```

Writes an unsigned 56-bit integer (0 to 18,014,398,509,481,984). Uses 7 bytes.

**Note:** The maximum value is limited by Luau's number precision, not the full 56-bit range.

#### WriteI8

```lua
writer:WriteI8(value: number)
```

Writes a signed 8-bit integer (-128 to 127). Uses 1 byte.

#### WriteI16

```lua
writer:WriteI16(value: number)
```

Writes a signed 16-bit integer (-32,768 to 32,767). Uses 2 bytes.

#### WriteI24

```lua
writer:WriteI24(value: number)
```

Writes a signed 24-bit integer (-8,388,608 to 8,388,607). Uses 3 bytes.

#### WriteF32

```lua
writer:WriteF32(value: number)
```

Writes a 32-bit floating-point number. Uses 4 bytes.

**Warning:** Values with absolute value greater than 16,777,215 may lose precision.

#### WriteF64

```lua
writer:WriteF64(value: number)
```

Writes a 64-bit floating-point number (Luau's native number type). Uses 8 bytes.

#### WriteInstance

```lua
writer:WriteInstance(instance: Instance)
```

Writes a reference to a Roblox Instance. Bolt automatically tracks instances to avoid duplication. Uses 2 bytes per reference.

**Example:**
```lua
writer:WriteInstance(workspace.SpawnPoint)
```

#### WriteString

```lua
writer:WriteString(value: string, count: number?)
```

Writes a string. If `count` is provided, writes exactly that many bytes. Otherwise, writes the string length as U8 followed by the string content (max 255 characters).

**Example:**
```lua
writer:WriteString("Hello") -- 1 byte for length + 5 bytes for text
```

#### WriteVector2

```lua
writer:WriteVector2(value: Vector2)
```

Writes a Vector2 as two F32 values. Uses 8 bytes.

#### WriteVector3

```lua
writer:WriteVector3(value: Vector3)
```

Writes a Vector3 as three F32 values. Uses 12 bytes.

#### WriteCFrame

```lua
writer:WriteCFrame(value: CFrame)
```

Writes a CFrame as position (3x F32) and rotation (3x I16 Euler angles). Uses 18 bytes.

**Note:** Rotation is stored with 0.001 precision to save space.

#### WriteColor3

```lua
writer:WriteColor3(value: Color3)
```

Writes a Color3 as RGB bytes. Uses 3 bytes.

### Utility Methods

#### Fit

```lua
writer:Fit()
```

Resizes the buffer to exactly match the amount of data written, freeing unused space.

## BufferReader API

BufferReader is used in custom deserializers to read data from a binary buffer. Readers are automatically created and managed by Bolt.

### Creation Methods

#### fromBuffer

```lua
BufferReader.fromBuffer(buffer: buffer): BufferReader
```

Creates a reader from a buffer.

#### fromString

```lua
BufferReader.fromString(string: string): BufferReader
```

Creates a reader from a string.

### Read Methods

All read methods advance the internal cursor automatically. Methods must be called in the same order as the corresponding Write methods were called during serialization.

#### ReadB8

```lua
reader:ReadB8(): {boolean}
```

Reads 8 boolean values from a single byte, returning them as an array.

**Example:**
```lua
local bools = reader:ReadB8()
local isRunning = bools[1]
local isJumping = bools[2]
```

#### ReadU8

```lua
reader:ReadU8(): number
```

Reads an unsigned 8-bit integer (0 to 255).

#### ReadU16

```lua
reader:ReadU16(): number
```

Reads an unsigned 16-bit integer (0 to 65,535).

#### ReadU24

```lua
reader:ReadU24(): number
```

Reads an unsigned 24-bit integer (0 to 16,777,215).

#### ReadU32

```lua
reader:ReadU32(): number
```

Reads an unsigned 32-bit integer (0 to 4,294,967,296).

#### ReadU40

```lua
reader:ReadU40(): number
```

Reads an unsigned 40-bit integer.

#### ReadU56

```lua
reader:ReadU56(): number
```

Reads an unsigned 56-bit integer.

#### ReadI8

```lua
reader:ReadI8(): number
```

Reads a signed 8-bit integer (-128 to 127).

#### ReadI16

```lua
reader:ReadI16(): number
```

Reads a signed 16-bit integer (-32,768 to 32,767).

#### ReadI24

```lua
reader:ReadI24(): number
```

Reads a signed 24-bit integer (-8,388,608 to 8,388,607).

#### ReadF32

```lua
reader:ReadF32(): number
```

Reads a 32-bit floating-point number.

#### ReadF64

```lua
reader:ReadF64(): number
```

Reads a 64-bit floating-point number.

#### ReadInstance

```lua
reader:ReadInstance(): Instance
```

Reads an Instance reference.

#### ReadString

```lua
reader:ReadString(count: number?): string
```

Reads a string. If `count` is provided, reads exactly that many bytes. Otherwise, reads the length byte followed by the string content.

#### ReadVector2

```lua
reader:ReadVector2(): Vector2
```

Reads a Vector2.

#### ReadVector3

```lua
reader:ReadVector3(): Vector3
```

Reads a Vector3.

#### ReadCFrame

```lua
reader:ReadCFrame(): CFrame
```

Reads a CFrame.

#### ReadColor3

```lua
reader:ReadColor3(): Color3
```

Reads a Color3.

## Performance Characteristics

Understanding Bolt's performance model helps you use it effectively.

### Message Batching

Bolt automatically batches multiple messages into single network packets:

- Messages are queued when you call Fire methods
- Every Heartbeat (~60 times per second), queued messages are batched and sent
- Multiple events can be combined into a single RemoteEvent call
- This dramatically reduces network overhead compared to individual RemoteEvent fires

### Size Limits

- Maximum message size: 100,000 bytes (100 KB) per batch
- If messages exceed this limit, they're split across multiple batches
- Individual payloads should be kept reasonable - very large messages may delay other queued messages

### Buffer Reuse

Bolt reuses buffers internally to minimize memory allocations:

- Buffers are pooled and cleared after use
- This reduces garbage collection pressure
- No action needed from developers - this is automatic

### Instance References

When sending Instances:

- First reference to an Instance includes the full reference (2 bytes)
- Additional references to the same Instance in the same message reuse the index
- Instance references are only valid within a single message batch

### Network Timing

Messages are sent on Heartbeat:
- Client-to-server: Queued until next Heartbeat, then sent
- Server-to-client: Queued until next Heartbeat, then sent
- Expect ~16ms (one frame) latency minimum from queueing to transmission
- Add network ping on top of this

## Best Practices

### Event Naming

Use clear, descriptive names that indicate direction and purpose:

```lua
-- Good
Bolt.ReliableEvent("PlayerRequestPurchase")
Bolt.ReliableEvent("ServerBroadcastExplosion")

-- Avoid
Bolt.ReliableEvent("Event1")
Bolt.ReliableEvent("Data")
```

### Serialization Optimization

Choose the smallest data type that fits your range:

```lua
-- Bad: Wastes 7 bytes per health value
function(writer, health)
    writer:WriteF64(health) -- 8 bytes for 0-100 range
end

-- Good: Uses 1 byte
function(writer, health)
    writer:WriteU8(health) -- 1 byte for 0-255 range
end
```

Pack boolean flags together:

```lua
-- Bad: 3 bytes
writer:WriteU8(isRunning and 1 or 0)
writer:WriteU8(isJumping and 1 or 0)
writer:WriteU8(isCrouching and 1 or 0)

-- Good: 1 byte
writer:WriteB8(isRunning, isJumping, isCrouching)
```

### Validation and Security

Always validate on the server:

```lua
-- Bad: Trust client data
event.OnServerEvent:Connect(function(player, damage)
    applyDamage(player, damage)
end)

-- Good: Validate before processing
event.OnServerEvent:Connect(function(player, damage)
    if type(damage) ~= "number" then return end
    if damage < 0 or damage > 100 then return end
    if not canPlayerDealDamage(player) then return end

    applyDamage(player, damage)
end)
```

### Error Handling

Wrap event handlers in pcall for resilience:

```lua
event.OnClientEvent:Connect(function(...)
    local success, err = pcall(function()
        -- Your handler code
        updateUI(...)
    end)

    if not success then
        warn("Error handling event:", err)
    end
end)
```

### Migration from RemoteEvents

Bolt events work similarly to RemoteEvents with minor differences:

```lua
-- Before (RemoteEvent)
local remote = Instance.new("RemoteEvent")
remote.Name = "MyEvent"
remote.Parent = ReplicatedStorage

remote.OnServerEvent:Connect(function(player, data)
    -- Handle
end)

remote:FireClient(player, data)

-- After (Bolt)
local event = Bolt.ReliableEvent("MyEvent")

event.OnServerEvent:Connect(function(player, data)
    -- Handle (same code)
end)

event:FireClient(player, data) -- Same syntax
```

Key differences:
- No Instance creation - events are created via function call
- Automatic batching - no need to manually batch messages
- Optional custom serialization for optimization

### Organizing Events

Create a single module to organize all your events:

```lua
-- ReplicatedStorage.BoltEvents
local Bolt = require(script.Parent.Bolt)

return {
    -- Combat
    PlayerAttack = Bolt.ReliableEvent("PlayerAttack"),
    PlayerDamaged = Bolt.ReliableEvent("PlayerDamaged"),

    -- Movement
    PlayerJumped = Bolt.ReliableEvent("PlayerJumped"),
    PlayerTeleported = Bolt.ReliableEvent("PlayerTeleported"),

    -- Properties
    GameSpeed = Bolt.RemoteProperty("GameSpeed", 1.0),
    RoundNumber = Bolt.RemoteProperty("RoundNumber", 0),

    -- Functions
    RequestInventory = Bolt.RemoteFunction("RequestInventory"),
}
```

## Known Issues & Limitations

### Integer Method Limitation

The `WriteI32` method has a potential implementation issue and should be avoided. For signed 32-bit integers, use alternative approaches:

- For values in range [-8,388,608 to 8,388,607]: Use `WriteI24`
- For larger values: Use `WriteF32` or `WriteF64`
- For values that fit in smaller ranges: Use `WriteI8` or `WriteI16`

### Number Precision Limits

Luau numbers are 64-bit floats, which limits integer precision:

- `WriteU56`: Maximum value is 18,014,398,509,481,984 (not full 56-bit range)
- `WriteF32`: Values with absolute value > 16,777,215 may lose precision
- This is a Luau limitation, not specific to Bolt

### Queue Blocking

If a client doesn't know about an event ID, all subsequent messages in the queue are blocked until the client receives the event definition. This is an internal synchronization mechanism.

In practice, this rarely causes issues because event definitions are sent immediately when players join.

### Network Reliability

Bolt uses RemoteEvent under the hood, which means:

- Messages are reliable (guaranteed delivery)
- Messages are ordered (arrive in the order sent)
- No built-in retry logic beyond Roblox's networking layer
- Subject to same network limits as regular RemoteEvents

### String Length Limit

The default string serialization (`WriteString` without count parameter) is limited to 255 characters. For longer strings, use custom serialization:

```lua
function(writer, longString)
    writer:WriteU16(#longString) -- Support up to 65,535 characters
    writer:WriteString(longString, #longString)
end
```

## Complete Examples

### Example 1: Chat System with Custom Serialization

```lua
-- Module
local ChatEvent = Bolt.ReliableEvent(
    "ChatMessage",
    function(writer, username, message, timestamp)
        writer:WriteString(username)
        writer:WriteString(message)
        writer:WriteU32(timestamp)
    end,
    function(reader)
        local username = reader:ReadString()
        local message = reader:ReadString()
        local timestamp = reader:ReadU32()
        return username, message, timestamp
    end
)

-- Server
local function broadcastMessage(player, message)
    local timestamp = os.time()
    ChatEvent:FireAllClients(player.Name, message, timestamp)
end

ChatEvent.OnServerEvent:Connect(function(player, message)
    -- Filter profanity, check rate limits, etc.
    if #message > 200 then return end
    if not checkRateLimit(player) then return end

    broadcastMessage(player, message)
end)

-- Client
ChatEvent.OnClientEvent:Connect(function(username, message, timestamp)
    addChatMessage(username, message, timestamp)
end)
```

### Example 2: Player State Synchronization

```lua
-- Module
local PlayerStateProperty = Bolt.RemoteProperty(
    "PlayerState",
    { position = Vector3.new(0, 5, 0), health = 100, team = "None" }
)

-- Server
local function updatePlayerState(player)
    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")

    if humanoid and hrp then
        PlayerStateProperty:SetFor(player, {
            position = hrp.Position,
            health = humanoid.Health,
            team = player.Team and player.Team.Name or "None"
        })
    end
end

game:GetService("RunService").Heartbeat:Connect(function()
    for _, player in game.Players:GetPlayers() do
        updatePlayerState(player)
    end
end)

-- Client
PlayerStateProperty:Observe(function(state)
    updatePlayerUI(state)
end)
```

### Example 3: Inventory RPC

```lua
-- Module
local GetInventory = Bolt.RemoteFunction("GetInventory")
local PurchaseItem = Bolt.RemoteFunction("PurchaseItem")

-- Server
GetInventory.OnServerInvoke = function(player)
    local data = loadPlayerData(player)
    return data.inventory
end

PurchaseItem.OnServerInvoke = function(player, itemId, cost)
    local data = loadPlayerData(player)

    if data.coins >= cost then
        data.coins -= cost
        table.insert(data.inventory, itemId)
        savePlayerData(player, data)
        return true, "Purchase successful"
    else
        return false, "Insufficient coins"
    end
end

-- Client
local function loadInventory()
    local inventory = GetInventory:InvokeServer()
    displayInventory(inventory)
end

local function buyItem(itemId, cost)
    local success, message = PurchaseItem:InvokeServer(itemId, cost)
    if success then
        showNotification("Item purchased!")
        loadInventory()
    else
        showError(message)
    end
end
```

### Example 4: Migration from RemoteEvent

```lua
-- BEFORE: Using RemoteEvent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JumpEvent = ReplicatedStorage:WaitForChild("JumpEvent")

-- Server
JumpEvent.OnServerEvent:Connect(function(player, power)
    if power > 100 then return end

    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.JumpPower = power
        end
    end

    -- Broadcast to others
    for _, otherPlayer in game.Players:GetPlayers() do
        if otherPlayer ~= player then
            JumpEvent:FireClient(otherPlayer, player.Name, power)
        end
    end
end)

-- Client
JumpEvent.OnClientEvent:Connect(function(playerName, power)
    print(playerName, "jumped with power", power)
end)

JumpEvent:FireServer(50)
```

```lua
-- AFTER: Using Bolt
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bolt = require(ReplicatedStorage.Bolt)
local JumpEvent = Bolt.ReliableEvent("PlayerJump")

-- Server (nearly identical code)
JumpEvent.OnServerEvent:Connect(function(player, power)
    if power > 100 then return end

    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.JumpPower = power
        end
    end

    -- Broadcast to others (now automatically batched!)
    for _, otherPlayer in game.Players:GetPlayers() do
        if otherPlayer ~= player then
            JumpEvent:FireClient(otherPlayer, player.Name, power)
        end
    end
end)

-- Client (identical code)
JumpEvent.OnClientEvent:Connect(function(playerName, power)
    print(playerName, "jumped with power", power)
end)

JumpEvent:FireServer(50)
```

**Benefits of migration:**
- Same API, minimal code changes
- Automatic message batching
- Reduced bandwidth usage
- Option to add custom serialization later for further optimization

---

**Bolt Version:** 1.1.0

For issues or questions, refer to the main project documentation.
