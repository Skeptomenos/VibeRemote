# OpenCode API Findings

Investigation findings from debugging the VibeRemote iOS app's integration with OpenCode.

## API Structure

### Messages and Parts are Separate Resources

The OpenCode API returns messages and parts as **separate endpoints**:

- `GET /session/{id}/message` → Array of `Message` objects (flat structure, NO embedded parts)
- `GET /session/{id}/part` → Array of `Part` objects (each with `messageID` to link to parent)

**Important**: Messages do NOT contain parts. Parts must be fetched separately and joined client-side by `messageID`.

Reference implementation: [opencode-vibe](https://github.com/joelhooks/opencode-vibe) fetches both in parallel and joins them using `MessageService.listWithParts()`.

### Message Structure (Flat, NOT Nested)

The API returns messages with a **flat structure**:

```json
{
  "id": "msg_xxx",
  "sessionID": "ses_xxx",
  "role": "assistant",
  "time": { "created": 1234567890, "completed": 1234567891 },
  "parentID": "msg_parent",
  "modelID": "claude-sonnet-4",
  "providerID": "anthropic",
  "mode": "agent",
  "path": { "cwd": "/path", "root": "/root" },
  "cost": 0.01,
  "tokens": { "input": 100, "output": 200, "reasoning": 0, "cache": { "read": 0, "write": 0 } }
}
```

**NOT** wrapped in an `info` field. The iOS app was incorrectly expecting `{ "info": { ... }, "parts": [...] }`.

### Part Structure

Parts are returned from `/session/{id}/part`:

```json
{
  "id": "prt_xxx",
  "sessionID": "ses_xxx",
  "messageID": "msg_xxx",
  "type": "text",
  "text": "Hello world"
}
```

Part types include: `text`, `tool`, `reasoning`, `file`, `step-start`, `step-finish`

### SSE Events

SSE events use this structure:

```json
{
  "type": "message.part.updated",
  "properties": {
    "part": {
      "id": "prt_xxx",
      "sessionID": "ses_xxx", 
      "messageID": "msg_xxx",
      "type": "text",
      "text": "streaming content..."
    }
  }
}
```

Key event types:
- `message.updated` - Message metadata changed
- `message.part.updated` - Part content updated (streaming)
- `session.updated` - Session metadata changed
- `session.status` - Session status (busy/idle)
- `session.error` - Error occurred

## Provider/Model API

### Providers Response Structure

The `/provider` endpoint returns providers with models as a **dictionary** (not array):

```json
{
  "providers": [
    {
      "id": "opencode",
      "name": "OpenCode Zen",
      "models": {
        "big-pickle": { "name": "Big Pickle", "limit": { "context": 128000, "output": 8192 } },
        "claude-sonnet-4": { "name": "Claude Sonnet 4", "limit": { "context": 200000, "output": 8192 } }
      }
    }
  ],
  "default": {
    "provider": "opencode",
    "model": "big-pickle"
  }
}
```

**Critical**: The model ID is the **dictionary key**, not a field inside the model object.

### Sending Messages with Model Selection

To send a message with a specific model:

```
POST /session/{id}/prompt_async
{
  "parts": [{ "type": "text", "text": "Hello" }],
  "providerID": "opencode",
  "modelID": "big-pickle"
}
```

## OpenCode Zen Models

From https://opencode.ai/docs/zen/

### Free Models (as of Jan 2025)
- `big-pickle` - Stealth model, free during beta
- `grok-code` - Grok Code Fast 1, free for limited time
- `minimax-m2.1-free` - MiniMax M2.1, free during beta
- `glm-4.7-free` - GLM 4.7, free during beta
- `gpt-5-nano` - GPT 5 Nano, free

### Model ID Format
In OpenCode config: `opencode/<model-id>` (e.g., `opencode/big-pickle`)

When sending via API: just the model ID (e.g., `big-pickle`)

## Issues Found & Solutions (Jan 2025)

### 1. Model ID Not Parsed from Dictionary Key ✅ FIXED

**Problem**: The iOS app's `Provider` decoder didn't extract the model ID from the dictionary key.

**Solution**: Use `AIModelRaw` struct and extract ID from dictionary key:

```swift
private struct AIModelRaw: Codable {
    let name: String
    let limit: ModelLimit?
}

// In Provider.init(from decoder:)
let modelsDict = try container.decode([String: AIModelRaw].self, forKey: .models)
models = modelsDict.map { key, raw in
    AIModel(id: key, name: raw.name, limit: raw.limit)
}.sorted { $0.name < $1.name }
```

### 2. Message Response Format - Nested NOT Flat ✅ FIXED

**Problem**: Initially thought API returned flat messages, but it actually returns nested `{info, parts}` format.

**Solution**: The `/session/{id}/message` endpoint returns:
```json
[
  {
    "info": { "id": "msg_xxx", "role": "assistant", ... },
    "parts": [{ "type": "text", "text": "Hello" }, ...]
  }
]
```

Use `MessageResponse` struct:
```swift
struct MessageResponse: Codable {
    let info: MessageInfo
    let parts: [MessagePart]?
    
    func toOpenCodeMessage() -> OpenCodeMessage {
        OpenCodeMessage(info: info, parts: parts)
    }
}
```

**Note**: Parts ARE embedded in the message response. No need to fetch `/session/{id}/part` separately for initial load.

### 3. SSE Part Updates - messageID is INSIDE the part object ✅ FIXED

**Problem**: SSE `message.part.updated` events have `messageID` inside the `part` object, not at the top level of `properties`. The app was looking for `properties.messageID` which was always empty.

**SSE Event Structure**:
```json
{
  "type": "message.part.updated",
  "properties": {
    "part": {
      "id": "prt_xxx",
      "sessionID": "ses_xxx",
      "messageID": "msg_xxx",    // ← messageID is HERE, inside part
      "type": "text",
      "text": "streaming..."
    }
  }
}
```

**Solution**: Decode the `part` as `PartResponse` (which includes `messageID`) instead of `MessagePart`:

```swift
private struct SSEEventProperties: Decodable {
    let partResponse: PartResponse?  // PartResponse has messageID
    
    var part: MessagePart? {
        partResponse?.part
    }
    
    var partMessageID: String? {
        partResponse?.messageID  // Extract messageID from inside part
    }
    
    init(from decoder: Decoder) throws {
        // ...
        partResponse = try container.decodeIfPresent(PartResponse.self, forKey: .part)
    }
}

// When parsing SSE events:
case "message.part.updated":
    let messageID = wrapper.properties?.partMessageID ?? wrapper.properties?.messageID ?? ""
    let part = wrapper.properties?.part ?? .unknown
    return .partUpdated(messageID, part)
```

### 4. Model Selection Not Sent to API ✅ FIXED

**Problem**: `selectedProvider` and `selectedModel` were nil when sending messages.

**Solution**: Ensure `loadProviders()` correctly sets defaults from API response:
```swift
if let defaults = response.default {
    self.selectedProvider = defaults["provider"]
    self.selectedModel = defaults["model"]
}
```

### 5. Performance - Redundant Full Message Reloads ✅ FIXED

**Problem**: Every SSE event triggered a full reload of ALL messages from the server, causing slowness.

**Solution**: Update messages incrementally:
- `message.updated`: Update specific message in-place or append if new
- `part.updated`: Update specific part in the message's parts array
- Only reload all messages as fallback when message not found

### 6. Server Gateway Crash on Chat Stream ✅ FIXED

**Problem**: The Gateway service crashed with `RuntimeError: client has been closed` during streaming because the `httpx.AsyncClient` was closed before the stream finished.

**Solution**: Refactored `stream_sse` in `gateway/main.py` to instantiate the client **inside** the generator, keeping it alive for the full duration of the stream.

### 7. Gateway Restart Loop ✅ FIXED

**Problem**: After a restart, the Gateway kept finding the *old* port in the logs, leading to connection timeouts.

**Solution**: Updated `gateway/main.py` to use `re.findall(...)[-1]` to always pick the **last** (newest) port from the logs.

## Reference Implementations

- **opencode-vibe** (actively maintained): https://github.com/joelhooks/opencode-vibe
- **@opencode-ai/sdk** (official SDK): npm package with TypeScript types

## Key Takeaways

1. **Model IDs are dictionary keys** - When API returns `{ "models": { "big-pickle": {...} } }`, the model ID is `"big-pickle"` (the key), not a field inside the object.

2. **Messages include parts** - The `/session/{id}/message` endpoint returns `{info, parts}` objects. Parts are embedded, not separate.

3. **SSE part.messageID is nested** - In `message.part.updated` events, the `messageID` is inside `properties.part.messageID`, not `properties.messageID`.

4. **Incremental updates are essential** - Don't reload all messages on every SSE event. Update specific messages/parts in-place for performance.

5. **Server-Side Resilience is Key** - Gateway logic for port detection and stream handling must be robust against restarts and slow clients.
