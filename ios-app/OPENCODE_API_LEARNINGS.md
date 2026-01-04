# OpenCode API Learnings

## Message Structure (from API)

The actual message structure returned by `/api/session/{id}/message`:

```json
{
  "info": {
    "id": "msg_xxx",
    "sessionID": "ses_xxx",
    "role": "user" | "assistant",
    "time": {
      "created": 1767488733288,
      "completed": 1767488734241  // optional, only on completed messages
    },
    "summary": {
      "title": "Summarizing text: Test",
      "diffs": []
    },
    "agent": "Sisyphus",
    "model": {
      "providerID": "genaipilot-anthropic",
      "modelID": "claude-opus-4-5@20251101"
    },
    "error": {  // optional, only on failed messages
      "name": "UnknownError",
      "data": {
        "message": "Error: Could not load the default credentials..."
      }
    },
    "parentID": "msg_xxx",  // optional, links to parent message
    "modelID": "claude-opus-4-5@20251101",  // can be at top level OR in model object
    "providerID": "genaipilot-anthropic",   // can be at top level OR in model object
    "mode": "Sisyphus",
    "path": {
      "cwd": "/home/linux/Test",
      "root": "/"
    },
    "cost": 0,
    "tokens": {
      "input": 0,
      "output": 0,
      "reasoning": 0,
      "cache": {
        "read": 0,
        "write": 0
      }
    }
  },
  "parts": [
    {
      "id": "prt_xxx",
      "sessionID": "ses_xxx",
      "messageID": "msg_xxx",
      "type": "text",
      "text": "Test"
    }
  ]
}
```

## SSE Event Structure

SSE events from `/api/event`:

```
data: {"type":"server.connected","properties":{}}
data: {"type":"session.status","properties":{"sessionID":"ses_xxx","status":"running"}}
data: {"type":"session.idle","properties":{"sessionID":"ses_xxx"}}
data: {"type":"message.updated","properties":{"info":{...}}}
data: {"type":"message.part.updated","properties":{"part":{...}}}
data: {"type":"session.updated","properties":{"info":{...}}}
```

### Key SSE Parsing Issues

1. **Empty properties object**: `server.connected` sends `"properties":{}` - an empty object, not null
2. **Properties can be null or empty**: The decoder must handle both cases gracefully
3. **Use `try?` for lenient decoding**: When properties might be empty or have unexpected structure

### Swift Decoder Fix

```swift
private struct SSEEventWrapper: Decodable {
    let type: String
    let properties: SSEEventProperties?
    
    enum CodingKeys: String, CodingKey {
        case type, properties
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        // Use try? to handle empty objects gracefully
        properties = try? container.decodeIfPresent(SSEEventProperties.self, forKey: .properties)
    }
}
```

## MessageInfo Required Fields

All fields in `MessageInfo` that the API sends (make optional in Swift):

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| id | String | Yes | |
| sessionID | String | Yes | |
| role | MessageRole | Yes | "user" or "assistant" |
| time | MessageTime | Yes | |
| model | MessageModel? | No | Contains providerID, modelID |
| cost | Double? | No | |
| tokens | TokenUsage? | No | |
| agent | String? | No | e.g., "Sisyphus" |
| parentID | String? | No | Links to parent message |
| modelID | String? | No | Can be here OR in model object |
| providerID | String? | No | Can be here OR in model object |
| mode | String? | No | e.g., "Sisyphus" |
| path | MessagePath? | No | Contains cwd, root |
| error | MessageError? | No | Contains name, data.message |
| summary | MessageSummary? | No | Contains title, diffs |

## Session Structure

```json
{
  "id": "ses_xxx",
  "version": "1.0.223",
  "projectID": "global",
  "directory": "/home/linux/Test",
  "title": "ReponseCheck",
  "time": {
    "created": 1767488599680,
    "updated": 1767488734222
  },
  "summary": {
    "additions": 0,
    "deletions": 0,
    "files": 0
  }
}
```

## API Endpoints

Base URL: `https://vibecode.helmus.me/projects/{projectName}/api`

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/session` | GET | List all sessions |
| `/session/{id}` | GET | Get session details |
| `/session/{id}/message` | GET | Get all messages in session |
| `/session/{id}/prompt_async` | POST | Send message (async, no response body) |
| `/event` | GET | SSE event stream |
| `/config/providers` | GET | List available providers/models |

## Common Mistakes to Avoid

1. **Don't assume properties is always present**: SSE events like `server.connected` have empty properties
2. **Don't use strict Codable decoding**: Use `try?` and optional fields liberally
3. **Model info can be in two places**: Check both `model.modelID` and top-level `modelID`
4. **SSE keepalive**: The server sends events every ~30 seconds even when idle
5. **Error responses still have message structure**: Failed messages have `error` field but still valid structure

## Reference: opencode-vibe Approach

The opencode-vibe project uses loose types with `[key: string]: unknown` to allow extra fields:

```typescript
export type Message = {
  id: string
  sessionID: string
  role: string
  parentID?: string
  time?: { created: number; completed?: number }
  // ... other known fields
  [key: string]: unknown  // Allow any extra fields
}
```

This is the recommended approach - be lenient in what you accept.

## Reasoning/Thinking Parts

For models with reasoning capability (e.g., Kimi K2 Thinking, Claude with extended thinking), OpenCode sends reasoning content as a separate part type.

### Part Type
```json
{
  "type": "reasoning",
  "text": "The reasoning/thinking content...",
  // OR (depending on model/provider):
  "reasoning": "The reasoning content...",
  // OR:
  "reasoning_content": "The reasoning content..."
}
```

### Model Capabilities
Models with reasoning capability have this in their capabilities:
```json
{
  "capabilities": {
    "reasoning": true,
    "interleaved": {
      "field": "reasoning_content"
    }
  }
}
```

The `interleaved.field` indicates which field name the model uses for reasoning content.

### Token Usage
When reasoning is used, the `tokens` object includes a `reasoning` count:
```json
{
  "tokens": {
    "input": 100,
    "output": 200,
    "reasoning": 500,  // Reasoning tokens used
    "cache": { "read": 0, "write": 0 }
  }
}
```

### Swift Implementation
The `ReasoningPart` struct handles multiple field names:
```swift
struct ReasoningPart: Codable {
    let type: String
    let text: String?
    let reasoning: String?
    let reasoningContent: String?
    
    var content: String {
        text ?? reasoning ?? reasoningContent ?? ""
    }
}
```
