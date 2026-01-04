# iOS App SSE Communication Flow Specification

**Purpose**: Define the correct ("should state") communication flow between the iOS app and OpenCode API. Use this as a reference to identify and fix deviations in the current implementation.

---

## 1. Connection Lifecycle Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONNECTION LIFECYCLE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. INITIALIZE        2. CONNECT SSE         3. READY                       │
│  ┌──────────────┐     ┌──────────────┐      ┌──────────────┐               │
│  │ Start OpenCode│────▶│ Open SSE     │─────▶│ Receive      │               │
│  │ (POST /start) │     │ Connection   │      │ server.      │               │
│  │              │     │ (GET /event) │      │ connected    │               │
│  └──────────────┘     └──────────────┘      └──────────────┘               │
│         │                    │                     │                        │
│         ▼                    ▼                     ▼                        │
│  Get session/create    Connection open      APP IS NOW READY               │
│  Load providers        before any messages  TO SEND MESSAGES               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**CRITICAL RULE**: SSE connection MUST be established and `server.connected` received BEFORE sending any messages.

---

## 2. Initialization Phase

### Step 1: Start OpenCode Instance
```
POST /projects/{name}/start
Authorization: Bearer {API_KEY}

Response: 200 OK
{
  "name": "ProjectName",
  "port": 12345,
  "status": "started" | "already_running"
}
```

### Step 2: Get or Create Session
```
# List existing sessions
GET /projects/{name}/api/session
Authorization: Bearer {API_KEY}

Response: 200 OK
[
  {
    "id": "ses_xxx",
    "title": "Session Title",
    "time": { "created": 1234567890, "updated": 1234567891 },
    ...
  }
]

# OR create new session
POST /projects/{name}/api/session
Authorization: Bearer {API_KEY}
Content-Type: application/json

{ "title": "New Session" }

Response: 200 OK
{ "id": "ses_xxx", "title": "New Session", ... }
```

### Step 3: Load Providers (for model selection)
```
GET /projects/{name}/api/config/providers
Authorization: Bearer {API_KEY}

Response: 200 OK
{
  "providers": [
    {
      "id": "google",
      "name": "Google",
      "models": {
        "gemini-flash-latest": { "name": "Gemini Flash Latest", ... }
      }
    }
  ]
}
```

### Step 4: Establish SSE Connection (BEFORE any messages)
```
GET /projects/{name}/api/event
Authorization: Bearer {API_KEY}
Accept: text/event-stream

Response: 200 OK (streaming)
data: {"type":"server.connected","properties":{}}

```

**State after Step 4**: App is READY to send messages.

---

## 3. Message Send/Receive Flow

### Sending a Message

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MESSAGE FLOW                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  USER ACTION              API CALL                 SSE EVENTS               │
│  ────────────             ────────                 ──────────               │
│                                                                             │
│  User types message                                                         │
│        │                                                                    │
│        ▼                                                                    │
│  [Send Button]                                                              │
│        │                                                                    │
│        ├──────────────────▶ POST /session/{id}/prompt_async                │
│        │                    {                                               │
│        │                      "model": {                                    │
│        │                        "providerID": "google",                     │
│        │                        "modelID": "gemini-flash-latest"            │
│        │                      },                                            │
│        │                      "parts": [{"type":"text","text":"Hello"}]     │
│        │                    }                                               │
│        │                                                                    │
│        │                    Response: 204 No Content                        │
│        │                                                                    │
│        │                                           ┌────────────────────┐   │
│        │                                           │ SSE Events Start   │   │
│        │                                           └────────────────────┘   │
│        │                                                    │               │
│        │                                                    ▼               │
│        │                                           message.updated (user)   │
│        │                                           message.part.updated     │
│        │                                           session.updated          │
│        │                                           session.status (busy)    │
│        │                                           message.updated (asst)   │
│        │                                           message.part.updated *   │
│        │                                           message.part.updated *   │
│        │                                           ... (streaming) ...      │
│        │                                           message.updated (done)   │
│        │                                           session.status (idle)    │
│        │                                           session.idle             │
│        │                                                                    │
│  * = These are the STREAMING events containing response text                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### API Request Format (CRITICAL)

```json
POST /projects/{name}/api/session/{sessionId}/prompt_async
Authorization: Bearer {API_KEY}
Content-Type: application/json

{
  "model": {
    "providerID": "google",
    "modelID": "gemini-flash-latest"
  },
  "parts": [
    { "type": "text", "text": "User's message here" }
  ]
}
```

**WRONG FORMAT** (causes silent failure):
```json
{
  "providerID": "google",
  "modelID": "gemini-flash-latest",
  "parts": [...]
}
```

Response: `204 No Content` (success, events will come via SSE)

---

## 4. SSE Event Sequence (Success Case)

```
Timeline ──────────────────────────────────────────────────────────────────▶

1. server.connected        (on initial connection)
   │
   ▼
2. message.updated         (user message created)
   {
     "type": "message.updated",
     "properties": {
       "info": {
         "id": "msg_user_xxx",
         "sessionID": "ses_xxx",
         "role": "user",
         "time": { "created": 1234567890 }
       }
     }
   }
   │
   ▼
3. message.part.updated    (user message text part)
   {
     "type": "message.part.updated",
     "properties": {
       "part": {                        ◀── NOTE: Nested inside "part" object
         "id": "prt_xxx",
         "sessionID": "ses_xxx",
         "messageID": "msg_user_xxx",   ◀── CRITICAL: Links part to message
         "type": "text",
         "text": "User's message"
       }
     }
   }
   │
   ▼
4. session.updated         (session metadata updated)
   { "type": "session.updated", "properties": { "info": { ... } } }
   │
   ▼
5. session.status          (processing started)
   { "type": "session.status", "properties": { "sessionID": "ses_xxx", "status": { "type": "busy" } } }
   │
   ▼
6. message.updated         (assistant message created, NOT completed)
   {
     "type": "message.updated",
     "properties": {
       "info": {
         "id": "msg_asst_xxx",
         "sessionID": "ses_xxx",
         "role": "assistant",
         "time": { "created": 1234567891 }   ◀── "completed" field ABSENT = still generating
       }
     }
   }
   │
   ▼
7. message.part.updated    (STREAMING - first chunk)
   {
     "type": "message.part.updated",
     "properties": {
       "part": {                        ◀── NOTE: Nested inside "part" object
         "id": "prt_yyy",
         "sessionID": "ses_xxx",
         "messageID": "msg_asst_xxx",   ◀── Links to assistant message
         "type": "text",
         "text": "Hello! I'm"           ◀── Partial response
       }
     }
   }
   │
   ▼
8. message.part.updated    (STREAMING - more chunks)
   {
     "type": "message.part.updated",
     "properties": {
       "part": {
         "messageID": "msg_asst_xxx",
         "type": "text",
         "text": "Hello! I'm happy to help you today."  ◀── Accumulated text
       }
     }
   }
   │
   ▼
   ... more message.part.updated events as response streams ...
   │
   ▼
9. message.updated         (assistant message COMPLETED)
   {
     "type": "message.updated",
     "properties": {
       "info": {
         "id": "msg_asst_xxx",
         "role": "assistant",
         "time": { 
           "created": 1234567891, 
           "completed": 1234567895    ◀── Field EXISTS = generation complete
         },
         "tokens": { "input": 100, "output": 50 }
       }
     }
   }
   │
   ▼
10. session.updated        (session metadata with summary)
    { "type": "session.updated", "properties": { "info": { "summary": { ... } } } }
   │
   ▼
11. session.diff           (file changes, often empty)
    { "type": "session.diff", "properties": { "sessionID": "ses_xxx", "diff": [] } }
   │
   ▼
12. session.status         (processing finished)
    { "type": "session.status", "properties": { "sessionID": "ses_xxx", "status": { "type": "idle" } } }
   │
   ▼
13. session.idle           (final confirmation)
    { "type": "session.idle", "properties": { "sessionID": "ses_xxx" } }
```

---

## 5. SSE Event Sequence (Error Case)

```
Timeline ──────────────────────────────────────────────────────────────────▶

1-5. Same as success case...
   │
   ▼
6. session.error           (error occurred)
   {
     "type": "session.error",
     "properties": {
       "sessionID": "ses_xxx",
       "error": {
         "name": "APIError",
         "data": {
           "message": "Error description here",
           "statusCode": 401,
           "isRetryable": false
         }
       }
     }
   }
   │
   ▼
7. message.updated         (assistant message with error)
   {
     "type": "message.updated",
     "properties": {
       "info": {
         "id": "msg_asst_xxx",
         "role": "assistant",
         "time": { "created": ..., "completed": ... },
         "error": {
           "name": "APIError",
           "data": { "message": "Error description" }
         }
       }
     }
   }
   │
   ▼
8. session.status (idle)
9. session.idle
```

---

## 6. SSE Event Properties Structure

### message.updated
```json
{
  "type": "message.updated",
  "properties": {
    "info": {
      "id": "msg_xxx",
      "sessionID": "ses_xxx",
      "role": "user" | "assistant",
      "time": {
        "created": 1234567890,
        "completed": 1234567891    // ABSENT when not complete, EXISTS when complete
      },
      "parentID": "msg_parent",           // For assistant messages, links to user message
      "modelID": "gemini-flash-latest",
      "providerID": "google",
      "agent": "Sisyphus",
      "mode": "Sisyphus",
      "path": { "cwd": "/path/to/project", "root": "/" },
      "tokens": { "input": 0, "output": 0, "reasoning": 0, "cache": { "read": 0, "write": 0 } },
      "cost": 0.0,
      "summary": { "diffs": [] },          // Present on completion
      "error": { "name": "...", "data": { "message": "..." } }  // Only present on error
    }
  }
}
```

**CRITICAL**: The `completed` field is **ABSENT** when the message is still generating.
Check for its existence, not for null:
```swift
// CORRECT
if info.time.completed != nil { /* complete */ }

// WRONG
if info.time.completed != null { /* doesn't work - field is absent, not null */ }
```

### message.part.updated
```json
{
  "type": "message.part.updated",
  "properties": {
    "part": {                      // ◀── IMPORTANT: Data is nested inside "part" object
      "id": "prt_xxx",
      "sessionID": "ses_xxx",
      "messageID": "msg_xxx",      // REQUIRED for linking to parent message
      "type": "text" | "tool" | "step-start" | "step-finish",
      
      // For type="text":
      "text": "The response text content"
    }
  }
}
```

**CRITICAL**: The part data is nested inside `properties.part`, NOT directly in `properties`.
```swift
// CORRECT
let messageID = event.properties.part.messageID
let text = event.properties.part.text

// WRONG
let messageID = event.properties.messageID  // ❌ Field doesn't exist here
```

### session.updated
```json
{
  "type": "session.updated",
  "properties": {
    "info": {
      "id": "ses_xxx",
      "version": "1.0.223",
      "projectID": "global",
      "directory": "/path/to/project",
      "title": "Session Title",
      "time": { "created": 1234567890, "updated": 1234567891 },
      "summary": { "additions": 0, "deletions": 0, "files": 0 }
    }
  }
}
```

### session.status
```json
{
  "type": "session.status",
  "properties": {
    "sessionID": "ses_xxx",
    "status": { "type": "busy" | "idle" }
  }
}
```

### session.diff
```json
{
  "type": "session.diff",
  "properties": {
    "sessionID": "ses_xxx",
    "diff": []    // Array of file diffs, often empty
  }
}
```

### tui.toast.show (can be ignored)
```json
{
  "type": "tui.toast.show",
  "properties": {
    "title": "Notification Title",
    "message": "Notification message",
    "variant": "info",
    "duration": 150
  }
}
```
This event is for OpenCode's TUI and can be safely ignored by the iOS app.

### session.error
```json
{
  "type": "session.error",
  "properties": {
    "sessionID": "ses_xxx",
    "error": {
      "name": "APIError",
      "data": {
        "message": "Detailed error message",
        "statusCode": 401,
        "isRetryable": false
      }
    }
  }
}
```

---

## 7. iOS App State Machine

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         APP STATE MACHINE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐                                                           │
│  │ DISCONNECTED │                                                           │
│  └──────┬───────┘                                                           │
│         │ connect()                                                         │
│         ▼                                                                   │
│  ┌──────────────┐                                                           │
│  │ CONNECTING   │ ─── Start OpenCode, get session, load providers           │
│  └──────┬───────┘                                                           │
│         │ SSE connected + server.connected received                         │
│         ▼                                                                   │
│  ┌──────────────┐                                                           │
│  │    READY     │ ◀─────────────────────────────────────────────┐           │
│  └──────┬───────┘                                               │           │
│         │ sendMessage()                                         │           │
│         ▼                                                       │           │
│  ┌──────────────┐                                               │           │
│  │   LOADING    │ ─── Show typing indicator                     │           │
│  │  (waiting)   │                                               │           │
│  └──────┬───────┘                                               │           │
│         │                                                       │           │
│         ├─── message.part.updated ───▶ Update UI with streaming │           │
│         │                              text (REAL-TIME)         │           │
│         │                                                       │           │
│         ├─── message.updated ────────▶ Update message metadata  │           │
│         │    (completed != null)       Stop loading indicator ──┘           │
│         │                                                                   │
│         └─── session.error ──────────▶ Show error, stop loading ────────────┘
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Critical Implementation Requirements

### 8.1 SSE Connection Timing
```swift
// CORRECT ORDER:
1. await startOpenCode()
2. await getOrCreateSession()
3. await loadProviders()
4. subscribeToSSE()           // Start SSE connection
5. await receiveServerConnected()  // Wait for confirmation
// NOW ready to send messages

// WRONG ORDER:
1. await startOpenCode()
2. await getOrCreateSession()
3. sendMessage()              // ❌ SSE not connected yet!
4. subscribeToSSE()           // ❌ Too late, events missed
```

### 8.2 Part Event Handling
```swift
// message.part.updated handler MUST:
1. Extract part data from properties.part (it's NESTED inside "part" object)
2. Get messageID from the part object
3. Find the message in the messages array by messageID
4. Update or append the part to that message
5. Trigger UI refresh to show streaming text

// Properties structure (CORRECT):
{
  "part": {                    // ◀── Data is inside "part" object
    "id": "prt_xxx",
    "messageID": "msg_xxx",    // Access as: properties.part.messageID
    "type": "text",
    "text": "Response content"
  }
}

// Swift example:
func handlePartUpdated(_ event: SSEEvent) {
    guard let part = event.properties.part else { return }
    guard let messageID = part.messageID else { return }
    guard part.type == "text", let text = part.text else { return }
    
    // Find and update the message
    if let index = messages.firstIndex(where: { $0.id == messageID }) {
        messages[index].appendText(text)
    }
}
```

### 8.3 Completion Detection
```swift
// CORRECT: Check if time.completed EXISTS (it's ABSENT when not complete)
if message.info.time.completed != nil {
    // Message is complete, stop loading indicator
    isLoading = false
}

// The "completed" field is a TIMESTAMP (Int64), not a boolean.
// It is ABSENT from the JSON when the message is still generating.
// It is PRESENT (with a Unix timestamp in milliseconds) when complete.

// WRONG approaches:
if message.info.completed == true { ... }     // ❌ No such field
if message.info.time.completed != null { ... } // ❌ Field is absent, not null

// Swift model should use Optional:
struct MessageTime: Decodable {
    let created: Int64
    let completed: Int64?  // Optional - absent when not complete
}
```

### 8.4 Error Handling
```swift
// Handle BOTH error sources:

// 1. session.error event
case .error(let error):
    showError(error.localizedDescription)
    isLoading = false

// 2. message.updated with error field
case .messageUpdated(let message):
    if let error = message.info.error {
        showError(error.data?.message ?? "Unknown error")
        isLoading = false
    }
```

---

## 9. Debugging Checklist

When streaming doesn't work, check in order:

| # | Check | Expected | How to Verify |
|---|-------|----------|---------------|
| 1 | SSE connected before send? | `server.connected` logged before `sendMessage` | Check log timestamps |
| 2 | Request format correct? | Nested `model` object | Log request body |
| 3 | 204 response received? | No error from prompt_async | Check network logs |
| 4 | `message.part.updated` received? | Events in SSE stream | Log all SSE events |
| 5 | Part data extracted from `properties.part`? | Part object exists | Log `properties.part` |
| 6 | `messageID` extracted from part? | Non-empty string | Log `properties.part.messageID` |
| 7 | Part decoded correctly? | `text` field populated | Log decoded part |
| 8 | Message found in array? | Index found | Log message lookup |
| 9 | UI updated? | Text visible | Visual check |

---

## 10. Test Scenarios

### Scenario 1: Basic Message Flow
```
Given: App is connected with SSE established
When: User sends "Hello"
Then:
  - User message appears immediately (optimistic)
  - Loading indicator shows
  - Assistant message appears
  - Response text streams in real-time
  - Loading indicator stops when complete
```

### Scenario 2: Provider Error
```
Given: App is connected with invalid provider
When: User sends message
Then:
  - session.error event received
  - Error message displayed to user
  - Loading indicator stops
  - App remains functional for retry
```

### Scenario 3: Reconnection
```
Given: SSE connection drops
When: App detects disconnection
Then:
  - Reconnect SSE automatically
  - Wait for server.connected
  - Resume normal operation
```

---

## Appendix: Quick Reference

### Endpoints Used
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/projects/{name}/start` | Start OpenCode |
| GET | `/projects/{name}/api/session` | List sessions |
| POST | `/projects/{name}/api/session` | Create session |
| GET | `/projects/{name}/api/config/providers` | Get providers |
| GET | `/projects/{name}/api/event` | SSE stream |
| POST | `/projects/{name}/api/session/{id}/prompt_async` | Send message |
| POST | `/projects/{name}/api/session/{id}/abort` | Cancel generation |

### SSE Event Types
| Event | When | Action |
|-------|------|--------|
| `server.connected` | SSE established | Mark ready |
| `server.heartbeat` | Every ~10s | Ignore (keep-alive) |
| `message.updated` | Message created/changed | Add/update message |
| `message.part.updated` | Streaming content | Update message parts (data in `properties.part`) |
| `session.updated` | Session metadata changed | Update session info |
| `session.status` | Busy/idle change | Update loading state |
| `session.diff` | File changes available | Handle diffs (often empty) |
| `session.error` | Error occurred | Show error |
| `session.idle` | Processing done | Confirm complete |
| `tui.toast.show` | OpenCode UI notification | Ignore |

### Key Structural Notes

1. **`message.part.updated`**: Part data is nested inside `properties.part`, not directly in `properties`
2. **`time.completed`**: Field is ABSENT when not complete, EXISTS (as timestamp) when complete
3. **`error`**: Field is only present when an error occurred, not null otherwise
