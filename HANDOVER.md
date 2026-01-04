# VibeRemote Gateway Testing Handover

**Date**: January 4, 2026  
**Purpose**: Complete context for another AI session to test and debug the Gateway/OpenCode API

---

## TL;DR - What Needs To Be Done

1. **Create `gateway/test_all_endpoints.py`** - Comprehensive test script
2. **Run tests** against `https://vibecode.helmus.me`
3. **Debug SSE streaming** - iOS app receives heartbeats but no message events
4. **Update `GATEWAY_TEST_PLAN.md`** with results

---

## Project Overview

**VibeRemote** is a native iOS app for remotely controlling OpenCode AI coding agent sessions. The architecture:

```
iOS App (Swift)
    ↓ HTTPS
VibeRemote Gateway (FastAPI, Python)
    ↓ HTTP (localhost)
OpenCode Server (systemd user service)
```

The iOS app development is **blocked** because SSE streaming doesn't work properly - the app receives heartbeats but never receives message events after sending a prompt.

---

## Connection Details

| Item | Value |
|------|-------|
| Gateway URL | `https://vibecode.helmus.me` |
| API Key | `fb9b4ae8e769f297ee785f191d599c579552a12bd87f77bba12da3df2d249b0f` |
| Test Project | `Test` |
| Auth Header | `Authorization: Bearer {API_KEY}` |

---

## Repository Structure

```
/Users/davidhelmus/Repos/VibeRemote/
├── gateway/                    # FastAPI gateway server
│   ├── main.py                 # Gateway implementation (429 lines)
│   ├── verify_gateway.py       # Basic infrastructure test
│   ├── test_chat_flow.py       # SSE streaming test
│   └── test_all_endpoints.py   # TO BE CREATED
├── ios-app/VibeRemote/         # iOS app (Swift)
│   └── Sources/
│       ├── Services/
│       │   ├── GatewayClient.swift
│       │   └── OpenCodeClient.swift
│       └── ViewModels/
│           └── ChatViewModel.swift
├── GATEWAY_TEST_PLAN.md        # Comprehensive test plan (UPDATED)
└── HANDOVER.md                 # This file
```

---

## Current State

### What Works ✅
- Gateway health check
- List/start/stop projects
- Proxy to OpenCode API
- SSE connection opens
- SSE heartbeats received
- Model selection (providers list)

### What's Broken ❌
- **SSE message events not received** after sending a prompt
- iOS app shows typing indicator forever
- Only `server.heartbeat` events come through, no `message.updated` or `message.part.updated`

---

## The Critical Bug

### Symptoms
1. iOS app sends message via `POST .../prompt_async` → returns 204 ✅
2. SSE connection is open, heartbeats received ✅
3. **No `message.updated` or `message.part.updated` events received** ❌
4. App shows typing indicator forever

### Observed Logs (iOS)
```
[sendMessage] Sending with provider='google-vertex-anthropic', model='claude-opus-4-5@20251101'
SSE: Parsed wrapper with type: server.heartbeat
SSE: Unknown event type: server.heartbeat
(repeats indefinitely - no message events)
```

### Possible Causes
1. **Gateway SSE proxy issue** - `main.py` `stream_sse()` might buffer/drop events
2. **OpenCode not emitting events** for certain models
3. **Thinking models** have different event structure
4. **Session mismatch** - SSE connected to wrong session

---

## Gateway SSE Proxy Code

The suspect code in `gateway/main.py` (lines 346-369):

```python
async def stream_sse():
    async with httpx.AsyncClient() as client:
        try:
            async with client.stream(
                request.method,
                target_url,
                headers=headers,
                content=body,
                timeout=None,
            ) as response:
                async for chunk in response.aiter_bytes():
                    yield chunk
        except Exception as e:
            print(f"SSE Stream Error: {e}")

return StreamingResponse(
    stream_sse(),
    media_type="text/event-stream",
    headers={
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
    },
)
```

**Potential issues**:
- `aiter_bytes()` might buffer events instead of streaming line-by-line
- No explicit flush after each event
- Exception handling might swallow errors silently

---

## Test Script Requirements

Create `gateway/test_all_endpoints.py` that:

### 1. Tests All Endpoint Categories
```python
async def test_infrastructure(): ...      # Health, projects, start/stop
async def test_session_management(): ...  # CRUD sessions
async def test_message_operations(): ...  # Send, get, delete messages
async def test_model_selection(): ...     # Providers, model-specific tests
async def test_sse_streaming(): ...       # THE CRITICAL TEST
async def test_status_endpoints(): ...    # Todos, diffs, MCP, LSP
```

### 2. Tests Multiple Models
```python
MODELS_TO_TEST = [
    ("opencode", "big-pickle"),           # Fast, non-thinking
    ("opencode", "claude-sonnet-4"),      # Medium, non-thinking
    ("google-vertex-anthropic", "claude-opus-4-5@20251101"),  # Thinking
    ("google", "gemini-2.5-flash"),       # Google model
]
```

### 3. SSE Testing Pattern
```python
async def test_sse_with_model(provider: str, model: str) -> bool:
    # 1. Get or create session
    # 2. Connect to SSE stream
    # 3. Send prompt in parallel task
    # 4. Listen for events with timeout
    # 5. Verify event sequence:
    #    - message.updated (user)
    #    - message.updated (assistant, completed=false)
    #    - message.part.updated (type=text, streaming)
    #    - message.updated (assistant, completed=true)
    # 6. Return True if all events received
```

### 4. Output Format
```
=== Gateway Test Results ===

Infrastructure: 5/5 ✅
Session Management: 4/4 ✅
Message Operations: 4/4 ✅
Model Selection:
  opencode/big-pickle: ✅
  opencode/claude-sonnet-4: ✅
  google-vertex-anthropic/claude-opus-4-5@20251101: ❌ (no events)
  google/gemini-2.5-flash: ✅
SSE Streaming: 2/8 ❌
Status Endpoints: 5/5 ✅

=== Summary ===
Passed: 20/26
Critical: SSE not working with thinking models
```

---

## Debugging Steps

### Step 1: Test with Fast Model First
Use `big-pickle` (fast, non-thinking) to verify basic SSE works:
```python
await test_sse_with_model("opencode", "big-pickle")
```

### Step 2: Compare Direct vs Gateway SSE
If gateway SSE fails, test direct OpenCode SSE:
```bash
# Get OpenCode port
curl -H "Authorization: Bearer $API_KEY" \
  https://vibecode.helmus.me/projects/Test/status

# SSH tunnel to server
ssh -L 4096:localhost:4096 user@server

# Connect directly to OpenCode SSE
curl -N http://localhost:4096/event
```

### Step 3: Add Gateway Logging
If direct works but gateway doesn't, add logging to `main.py`:
```python
async for chunk in response.aiter_bytes():
    print(f"SSE Proxy: {chunk[:100]}")  # Debug
    yield chunk
```

### Step 4: Try Line-by-Line Streaming
Replace `aiter_bytes()` with `aiter_lines()`:
```python
async for line in response.aiter_lines():
    yield line.encode() + b"\n"
```

---

## API Reference

### Gateway Endpoints
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (no auth) |
| `/projects` | GET | List all projects |
| `/projects/{name}/start` | POST | Start OpenCode |
| `/projects/{name}/stop` | DELETE | Stop OpenCode |
| `/projects/{name}/api/{path}` | ANY | Proxy to OpenCode |

### OpenCode Endpoints (via Gateway)
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/session` | GET | List sessions |
| `/session` | POST | Create session |
| `/session/{id}` | GET | Get session |
| `/session/{id}` | DELETE | Delete session |
| `/session/{id}/message` | GET | Get messages |
| `/session/{id}/prompt_async` | POST | Send message (async) |
| `/session/{id}/abort` | POST | Abort generation |
| `/config/providers` | GET | Get providers/models |
| `/event` | GET | SSE event stream |

### SSE Event Types
| Event | Description |
|-------|-------------|
| `server.heartbeat` | Keep-alive ping |
| `message.updated` | Message metadata changed |
| `message.part.updated` | Streaming text chunk |

---

## Expected SSE Event Sequence

After sending a prompt, you should receive:

```
data: {"type":"message.updated","properties":{"sessionID":"...","info":{"id":"msg_user_123","role":"user","completed":true}}}

data: {"type":"message.updated","properties":{"sessionID":"...","info":{"id":"msg_asst_456","role":"assistant","completed":false}}}

data: {"type":"message.part.updated","properties":{"sessionID":"...","messageID":"msg_asst_456","part":{"type":"text","text":"Hello"}}}

data: {"type":"message.part.updated","properties":{"sessionID":"...","messageID":"msg_asst_456","part":{"type":"text","text":"! How can I help?"}}}

data: {"type":"message.updated","properties":{"sessionID":"...","info":{"id":"msg_asst_456","role":"assistant","completed":true}}}
```

---

## How to Run Tests

```bash
cd /Users/davidhelmus/Repos/VibeRemote/gateway

# Setup
python3 -m venv venv
source venv/bin/activate
pip install httpx

# Run existing tests
python verify_gateway.py
python test_chat_flow.py

# Run comprehensive test (after creating it)
python test_all_endpoints.py
```

---

## Files to Read

| File | Purpose |
|------|---------|
| `GATEWAY_TEST_PLAN.md` | Full test plan with all test cases |
| `gateway/main.py` | Gateway implementation (SSE proxy at line 346) |
| `gateway/verify_gateway.py` | Existing infrastructure test |
| `gateway/test_chat_flow.py` | Existing SSE test |

---

## Success Criteria

The task is complete when:

1. ✅ `test_all_endpoints.py` created and runs successfully
2. ✅ All infrastructure tests pass
3. ✅ Session CRUD tests pass
4. ✅ Message operations tests pass
5. ✅ SSE streaming works with at least one model
6. ✅ `GATEWAY_TEST_PLAN.md` updated with actual results
7. ✅ Any bugs found are documented with root cause

If SSE is broken:
- Document exactly which models work/fail
- Identify if issue is gateway or OpenCode
- Propose fix (or implement if straightforward)

---

## Notes for Next Session

1. **Don't assume anything works** - verify with actual tests
2. **Start with fast model** (`big-pickle`) for quick iteration
3. **Log everything** - SSE debugging needs visibility
4. **Check session ID** - make sure SSE is connected to the right session
5. **Timeout handling** - thinking models can take 30+ seconds

Good luck!
