# iOS App Handover & Technical Reference

**Last Updated**: January 4, 2026  
**Status**: Ready for Testing  
**Build**: Compiles successfully

---

## 1. Executive Summary

The VibeRemote iOS app provides a ChatGPT-like interface for interacting with OpenCode (AI coding agent) running on a remote Linux server. The architecture is:

```
iOS App → Gateway (FastAPI at vibecode.helmus.me:4000) → OpenCode instances
```

After extensive debugging, the SSE streaming infrastructure is now correctly implemented. The critical issue was that `message.part.updated` events have part data **nested inside a `part` object**, not directly in properties.

---

## 2. Critical Fixes Implemented

### 2.1 SSE Part Event Parsing (ROOT CAUSE FIX)

**Problem**: Streaming text never appeared. `message.part.updated` events were received but `messageID` was always empty.

**Root Cause**: The API sends part data nested inside `properties.part`:
```json
{
  "type": "message.part.updated",
  "properties": {
    "part": {                      // ← Data is NESTED here
      "messageID": "msg_xxx",
      "type": "text",
      "text": "Response content"
    }
  }
}
```

The old code looked for `messageID` directly in `properties` (wrong).

**Fix**: Created `SSEPartWrapper` struct in `OpenCodeClient.swift` that correctly decodes from the nested `part` object:
```swift
private struct SSEPartWrapper: Decodable {
    let messageID: String
    let type: String
    let text: String?
    // ... other fields
}
```

**Files Changed**: `ios-app/VibeRemote/Sources/Services/OpenCodeClient.swift`

### 2.2 Session Error Extraction

**Problem**: `session.error` events showed generic "Session error occurred" instead of the actual error message.

**Root Cause**: Error details are nested in `properties.error.data.message`:
```json
{
  "type": "session.error",
  "properties": {
    "error": {
      "name": "APIError",
      "data": {
        "message": "Actual error message here"
      }
    }
  }
}
```

**Fix**: Created `SSEErrorWrapper` struct to extract the nested error message.

**Files Changed**: `ios-app/VibeRemote/Sources/Services/OpenCodeClient.swift`

### 2.3 Duplicate SSE Connection Prevention

**Problem**: Logs showed two simultaneous SSE connections being created.

**Root Cause**: `connect()` could be called multiple times if the view was recreated while already connected.

**Fix**: Added guard in `ChatViewModel.connect()`:
```swift
guard connectionState == .disconnected || connectionState.isError else { return }
```

**Files Changed**: `ios-app/VibeRemote/Sources/ViewModels/ChatViewModel.swift`

### 2.4 Previous Fixes (Still Relevant)

| Fix | Description | File |
|-----|-------------|------|
| Gateway restart loop | Now reads newest port from logs | `gateway/main.py` |
| SSE stream crash | HTTP client properly scoped in generator | `gateway/main.py` |
| SSE timeout | Increased to 120s request, 24h stream | `OpenCodeClient.swift` |
| Duplicate messages | Optimistic messages replaced by server updates | `ChatViewModel.swift` |
| Timestamp parsing | Server sends ms, app expected seconds | `OpenCodeModels.swift` |

---

## 3. SSE Event Structure Reference

### message.updated
```json
{
  "type": "message.updated",
  "properties": {
    "info": {
      "id": "msg_xxx",
      "sessionID": "ses_xxx",
      "role": "assistant",
      "time": { "created": 1234567890, "completed": 1234567895 }
    }
  }
}
```
- `completed` field is **ABSENT** when still generating, **EXISTS** when done

### message.part.updated
```json
{
  "type": "message.part.updated",
  "properties": {
    "part": {
      "messageID": "msg_xxx",
      "type": "text",
      "text": "Streaming content here"
    }
  }
}
```
- Part data is **NESTED** inside `properties.part`

### session.error
```json
{
  "type": "session.error",
  "properties": {
    "error": {
      "name": "APIError",
      "data": { "message": "Error details" }
    }
  }
}
```

See `IOS_APP_SSE_FLOW_SPEC.md` for complete event documentation.

---

## 4. Architecture Overview

### Key Files

| File | Purpose |
|------|---------|
| `OpenCodeClient.swift` | SSE connection, event parsing, API calls |
| `ChatViewModel.swift` | UI state management, event handling |
| `OpenCodeModels.swift` | Data models for API responses |
| `ChatView.swift` | Main chat UI |
| `MessageBubbleView.swift` | Individual message rendering |

### SSE Parsing Flow

```
SSE Event JSON
    ↓
SSEEventWrapper.init(from:)
    ↓
SSEEventProperties.init(from:)
    ├── info → MessageInfo (for message.updated)
    ├── part → SSEPartWrapper (for message.part.updated)
    └── error → SSEErrorWrapper (for session.error)
    ↓
parseSSEEvent() → ServerEvent enum
    ↓
ChatViewModel.handleEvent()
    ↓
UI Update
```

---

## 5. Server Configuration

| Item | Value |
|------|-------|
| Gateway Location | `/home/linux/viberemote-gateway/` |
| Gateway Service | `viberemote-gateway.service` (user level) |
| Gateway Port | `4000` |
| Gateway URL | `https://vibecode.helmus.me` |

---

## 6. Testing Checklist

### Manual Verification Steps

1. Launch iOS Simulator (iPhone 17 Pro)
2. Open VibeRemote app
3. Create or select a session
4. Select a model (e.g., `gemini-flash-latest`)
5. Send a message: "Hello, what can you do?"
6. **Verify**: Response text streams in real-time (not all at once)
7. **Verify**: Loading indicator stops when complete
8. **Verify**: No duplicate messages appear

### Error Handling Test

1. Select an invalid/unavailable model
2. Send a message
3. **Verify**: Error message is displayed (not generic "Session error")
4. **Verify**: App remains functional for retry

### Thinking Model Test

1. Select a thinking model (e.g., Claude with extended thinking)
2. Send a complex question
3. **Verify**: "Thinking" content appears and streams
4. **Verify**: Final response appears after thinking

---

## 7. Known Remaining Gaps

| Gap | Priority | Description |
|-----|----------|-------------|
| Default model in wizard | P2 | User must edit session after creation to set default model |
| Thinking UI distinction | P2 | Thinking content could be more visually distinct |
| Session ID filtering | P3 | SSE events aren't filtered by session (works but inefficient) |

---

## 8. Build Commands

```bash
# Navigate to project
cd /Users/davidhelmus/Repos/VibeRemote/ios-app/VibeRemote

# Clean build
xcodebuild clean -project VibeRemote.xcodeproj -scheme VibeRemote

# Build for simulator
xcodebuild -project VibeRemote.xcodeproj -scheme VibeRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

---

## 9. Debugging Tips

### Enable Verbose SSE Logging

The code includes diagnostic prints:
- `[SSE PROPS] Decoded part: messageID=..., type=...`
- `[SSE ERROR EVENT] session.error: ...`
- `[SSE PART] message.part.updated for ...`

### Common Issues

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| No streaming text | Part not decoded from nested object | Check `SSEPartWrapper` decoding |
| Empty messageID | Looking at wrong level of JSON | Access via `properties.part.messageID` |
| Generic error messages | Not extracting from nested error | Check `SSEErrorWrapper` decoding |
| Duplicate connections | View recreated while connected | Guard in `connect()` |

---

## 10. Next Development Steps

1. **Verify streaming works** - Manual test with real server
2. **Add default model to wizard** - UX improvement
3. **Improve thinking UI** - Visual distinction for reasoning content
4. **Extract SSE parser** - `ChatViewModel` is getting large
