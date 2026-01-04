# iOS App Objective & Definition of Done

**Last Updated**: January 4, 2026  
**Status**: ✅ WORKING - All Core Features Verified  
**Build**: Compiles successfully

---

## 1. Objective

Build a native iOS app that provides a **ChatGPT-like experience** for interacting with AI coding agents (OpenCode) running on a remote server. The app should feel like a polished SaaS product while being fully self-hosted ("bring your own infrastructure").

---

## 2. Vision

> "I want to use my own ChatGPT on my iPhone, where the magic happens on my server."

The user should be able to:
- Pick up their iPhone
- Open VibeRemote
- Start a conversation with an AI coding agent
- See responses stream in real-time
- Feel like they're using a premium chat application

---

## 3. Definition of Done

### Core Functionality Checklist

| # | Requirement | Status | Notes |
|---|-------------|--------|-------|
| 1 | **Create Session** | ✅ Done | NewSessionWizard creates session on server |
| 2 | **Define Folder** | ✅ Done | FolderPickerView via SSH |
| 3 | **Select Default LLM** | ✅ Done | EditSessionView (post-creation) |
| 4 | **Change LLM in Chat** | ✅ Done | ModelPickerSheet in ChatView |
| 5 | **Send Prompt** | ✅ Done | Correct nested model format |
| 6 | **See Thinking Streaming** | ✅ VERIFIED | ReasoningPart streams correctly (tested Jan 4, 2026) |
| 7 | **See Response Streaming** | ✅ VERIFIED | SSE parsing works, responses stream fast |
| 8 | **ChatGPT-like Experience** | ✅ VERIFIED | Full chat experience working |

### Quality Criteria

| Aspect | Status | Notes |
|--------|--------|-------|
| **Responsiveness** | ✅ Implemented | Async/await, no blocking |
| **Feedback** | ✅ Implemented | Loading states, connection status |
| **Error Handling** | ✅ Fixed | `session.error` now extracts actual message |
| **Reliability** | ✅ Fixed | Duplicate connection prevention added |
| **Performance** | ⏳ Needs Testing | Should be smooth |

---

## 4. User Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         HAPPY PATH                               │
└─────────────────────────────────────────────────────────────────┘

1. LAUNCH APP
   └─→ See list of sessions (or empty state if first time)

2. CREATE SESSION (tap "+")
   ├─→ Enter session name
   ├─→ Browse and select project folder
   ├─→ (Optional) Select default LLM
   └─→ Tap "Launch Session"

3. ENTER CHAT
   ├─→ Connection established (green indicator)
   ├─→ See "What can I help with?" empty state
   └─→ Model selector shows current model in header

4. SEND MESSAGE
   ├─→ Type in input bar
   ├─→ Tap send button
   ├─→ Message appears immediately (optimistic)
   └─→ Loading indicator shows

5. SEE RESPONSE
   ├─→ (If thinking model) See "Thinking..." with streaming content
   ├─→ See response text stream in real-time
   ├─→ Tool calls appear as cards (Read, Write, Bash, etc.)
   └─→ Loading indicator stops when complete

6. CONTINUE CONVERSATION
   └─→ Repeat steps 4-5
```

---

## 5. Technical Requirements

### API Integration
- Gateway URL: `https://vibecode.helmus.me`
- Authentication: Bearer token (API key)
- Session creation: `POST /projects/{name}/api/session`
- Message sending: `POST /projects/{name}/api/session/{id}/prompt_async`
- Streaming: `GET /projects/{name}/api/event` (SSE)

### Request Format (Critical)
```json
{
  "model": {
    "providerID": "google-vertex-anthropic",
    "modelID": "claude-sonnet-4@20250514"
  },
  "parts": [
    {"type": "text", "text": "User message here"}
  ]
}
```

### SSE Events to Handle

| Event | Action | Status |
|-------|--------|--------|
| `server.connected` | Update connection state | ✅ Implemented |
| `message.updated` | Add/update message in UI | ✅ Implemented |
| `message.part.updated` | Update streaming content | ✅ Fixed (nested part) |
| `session.error` | Display error to user | ✅ Fixed (extracts message) |
| `session.idle` | Clear loading state | ✅ Implemented |

---

## 6. Resolved Issues

### Issue 1: No Streaming Text (FIXED)
**Problem**: `message.part.updated` events received but `messageID` was empty.  
**Root Cause**: Part data is nested inside `properties.part`, not directly in `properties`.  
**Solution**: Created `SSEPartWrapper` to decode from nested structure.

### Issue 2: Generic Error Messages (FIXED)
**Problem**: `session.error` showed "Session error occurred" instead of actual error.  
**Root Cause**: Error message is nested in `properties.error.data.message`.  
**Solution**: Created `SSEErrorWrapper` to extract nested error.

### Issue 3: Duplicate SSE Connections (FIXED)
**Problem**: Two SSE connections created simultaneously.  
**Root Cause**: `connect()` called multiple times when view recreated.  
**Solution**: Added guard to prevent connection when already connected/connecting.

### Issue 4: "Unregistered Callers" API Error (FIXED - Jan 4, 2026)
**Problem**: Google provider models failed with "Method doesn't allow unregistered callers" error, even though the same model worked when running OpenCode directly in terminal.  
**Root Cause**: When OpenCode runs as a systemd service (via gateway), it does NOT inherit shell environment variables like `GOOGLE_API_KEY`. The terminal session has these variables, but the systemd service doesn't.  
**Solution**: 
1. Created environment file: `~/.config/opencode/env` with `GOOGLE_API_KEY=xxx`
2. Updated `opencode@.service` to load it: `EnvironmentFile=-/home/linux/.config/opencode/env`
3. Restarted the service: `systemctl --user restart opencode@ProjectName`

**Key Insight**: This is a server configuration issue, not an iOS app bug. See `OPENCODE_API_REFERENCE.md` "Mistake 7" for full documentation.

---

## 7. Remaining Gaps

| Gap | Priority | Description |
|-----|----------|-------------|
| Default model in wizard | P2 | User must edit session after creation to set default model |
| Thinking UI distinction | P2 | Thinking content could be more visually distinct (collapsible) |
| Session ID filtering | P3 | SSE events aren't filtered by session (works but inefficient) |

---

## 8. Success Metrics

The app is **done** when a user can:

| Metric | Status |
|--------|--------|
| Open the app and create a new session in under 30 seconds | ✅ Verified |
| Select any available LLM model | ✅ Verified |
| Send a message and see the response stream in real-time | ✅ VERIFIED (Jan 4, 2026) |
| See thinking/reasoning content when using thinking models | ✅ VERIFIED (Gemini 3 Flash Preview) |
| Switch models mid-conversation without issues | ✅ Verified |
| Recover from connection errors without losing context | ✅ Verified |
| Feel like they're using a premium chat application | ✅ VERIFIED - Fast responses! |

---

## 9. Out of Scope (For Now)

- Multiple server support
- File attachments from iOS
- Voice input
- Offline mode
- Push notifications
- iPad-specific layouts (basic support exists)
- macOS Catalyst support

---

## 10. Next Steps

1. ~~**Manual Testing**: Verify streaming behavior with real OpenCode server~~ ✅ DONE
2. ~~**Verify Thinking**: Confirm reasoning content streams correctly~~ ✅ DONE
3. **Polish**: Improve thinking UI (currently shows duplicate thinking blocks), add default model to wizard
4. **Code Cleanup**: Extract SSE parsing from ChatViewModel
5. **Tool Call UI**: Improve tool call cards (Bash, Read, Write) - currently working but could be prettier

---

## 11. Reference Documents

- `IOS_APP_SSE_FLOW_SPEC.md` - Complete SSE event structure specification
- `IOS_APP_HANDOVER.md` - Technical details and debugging guide
- `OPENCODE_API_REFERENCE.md` - Full API documentation
