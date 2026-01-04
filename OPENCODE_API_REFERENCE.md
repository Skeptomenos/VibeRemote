# OpenCode API Reference & Learnings

**Date**: January 4, 2026  
**Purpose**: Comprehensive documentation of OpenCode API behavior, gotchas, and lessons learned

---

## Table of Contents

1. [API Overview](#1-api-overview)
2. [Authentication](#2-authentication)
3. [Request Formats](#3-request-formats)
4. [SSE Streaming](#4-sse-streaming)
5. [Providers & Models](#5-providers--models)
6. [Common Mistakes](#6-common-mistakes)
7. [Error Handling](#7-error-handling)
8. [Server Configuration](#8-server-configuration)
9. [Gateway Architecture](#9-gateway-architecture)
10. [Debugging Guide](#10-debugging-guide)

---

## 1. API Overview

### Base URLs
- **Gateway**: `https://vibecode.helmus.me`
- **OpenCode Direct** (via SSH): `http://127.0.0.1:{PORT}` (port changes on restart)

### API Versioning
OpenCode API version as of January 2026: `0.0.3` (from `/doc` endpoint)

### Request Flow
```
Client Request
    ↓
Gateway (/projects/{name}/api/{path})
    ↓
Port Lookup (from cache or journalctl)
    ↓
Proxy to OpenCode (http://127.0.0.1:{port}/{path})
    ↓
Response back to client
```

---

## 2. Authentication

### Gateway Authentication
```http
Authorization: Bearer {API_KEY}
```

The API key is configured in the gateway and validated on every request except `/health`.

### OpenCode Direct Access
OpenCode itself has no authentication when accessed directly on localhost. Security is provided by:
1. Binding to `127.0.0.1` only (not exposed externally)
2. Gateway authentication layer

---

## 3. Request Formats

### CRITICAL: prompt_async Request Format

This is the most common mistake. The API expects a **nested `model` object**, not top-level fields.

#### WRONG (causes silent failure - no SSE events)
```json
{
  "modelID": "claude-sonnet-4@20250514",
  "providerID": "google-vertex-anthropic",
  "parts": [
    {"type": "text", "text": "Hello"}
  ]
}
```

#### CORRECT
```json
{
  "model": {
    "providerID": "google-vertex-anthropic",
    "modelID": "claude-sonnet-4@20250514"
  },
  "parts": [
    {"type": "text", "text": "Hello"}
  ]
}
```

### Why the Wrong Format "Works"
- The endpoint returns `204 No Content` even with wrong format
- No error is returned
- OpenCode silently fails to process the message
- SSE stream shows only heartbeats, no message events
- This makes debugging extremely difficult

### Full prompt_async Schema
```json
{
  "model": {
    "providerID": "string (required)",
    "modelID": "string (required)"
  },
  "parts": [
    {
      "type": "text",
      "text": "string"
    }
  ],
  "messageID": "string (optional, pattern: ^msg.*)",
  "agent": "string (optional)",
  "noReply": "boolean (optional)",
  "tools": "object (optional)",
  "system": "string (optional)",
  "variant": "string (optional)"
}
```

### Create Session Request
```json
{
  "title": "string (optional)",
  "parentID": "string (optional, pattern: ^ses.*)"
}
```

### Update Session Request (PATCH)
```json
{
  "title": "string (optional)",
  "time": {
    "archived": "number (optional)"
  }
}
```

---

## 4. SSE Streaming

### Connecting to SSE
```http
GET /projects/{name}/api/event
Authorization: Bearer {API_KEY}
Accept: text/event-stream
```

### Event Format
All events follow this structure:
```
data: {"type":"event_type","properties":{...}}

```
Note: Each event ends with two newlines.

### Event Types Reference

| Event Type | Description | Properties |
|------------|-------------|------------|
| `server.connected` | Initial connection | `{}` |
| `server.heartbeat` | Keep-alive (~10s) | `{}` |
| `message.updated` | Message created/updated | `{info: MessageInfo}` |
| `message.part.updated` | Streaming content | `{part: MessagePart}` |
| `session.updated` | Session metadata changed | `{info: SessionInfo}` |
| `session.status` | Busy/idle state | `{sessionID, status: {type}}` |
| `session.idle` | Processing complete | `{sessionID}` |
| `session.error` | Error occurred | `{sessionID, error}` |
| `session.diff` | File changes | `{sessionID, diff: [...]}` |
| `tui.toast.show` | UI notification | `{title, message, variant}` |

### MessageInfo Structure
```json
{
  "id": "msg_xxx",
  "sessionID": "ses_xxx",
  "role": "user" | "assistant",
  "time": {
    "created": 1234567890123,
    "completed": 1234567890456  // TIMESTAMP, not boolean!
  },
  "error": {  // Only present on error
    "name": "APIError",
    "data": {
      "message": "Error description",
      "statusCode": 401
    }
  },
  "parentID": "msg_xxx",  // For assistant messages
  "modelID": "string",
  "providerID": "string",
  "agent": "string",
  "cost": 0,
  "tokens": {
    "input": 0,
    "output": 0,
    "reasoning": 0,
    "cache": {"read": 0, "write": 0}
  }
}
```

### MessagePart Structure
```json
{
  "id": "prt_xxx",
  "sessionID": "ses_xxx",
  "messageID": "msg_xxx",
  "type": "text" | "tool" | "step-start" | "step-finish",
  "text": "string (for text type)"
}
```

### Completion Detection

**WRONG**: Checking for boolean `completed` field
```javascript
if (info.completed === true) { ... }  // WRONG - field doesn't exist
```

**CORRECT**: Checking for `time.completed` timestamp
```javascript
if (info.time && info.time.completed) {
  // Message is complete
  // info.time.completed is Unix timestamp in milliseconds
}
```

### Error Detection
```javascript
// Check message-level error
if (info.error) {
  const message = info.error.data?.message || "Unknown error";
  // Handle error
}

// Check session-level error (separate event)
if (event.type === "session.error") {
  const message = event.properties.error?.data?.message;
  // Handle error
}
```

### SSE Event Sequence (Success)
```
1. server.connected
2. message.updated (role: user)
3. message.part.updated (user text)
4. session.updated
5. session.status (busy)
6. message.updated (role: assistant, no completion)
7. message.part.updated (streaming text...)
8. message.part.updated (more text...)
9. message.updated (role: assistant, time.completed set)
10. session.status (idle)
11. session.idle
```

### SSE Event Sequence (Error)
```
1. server.connected
2. message.updated (role: user)
3. session.status (busy)
4. message.updated (role: assistant, no completion)
5. session.error (error details)
6. message.updated (role: assistant, time.completed + error)
7. session.status (idle)
8. session.idle
```

---

## 5. Providers & Models

### Getting Available Providers
```http
GET /projects/{name}/api/config/providers
```

### Response Format
```json
{
  "providers": [
    {
      "id": "google-vertex-anthropic",
      "name": "Vertex Anthropic",
      "models": {
        "claude-sonnet-4@20250514": {
          "id": "claude-sonnet-4@20250514",
          "name": "Claude Sonnet 4"
        }
      }
    }
  ]
}
```

Note: `providers` is an **array**, not an object/dict.

### Provider Configuration Requirements

| Provider | Requirements |
|----------|--------------|
| `opencode` | Payment method at opencode.ai |
| `google-vertex` | `GOOGLE_VERTEX_LOCATION` env var, active GCP project |
| `google-vertex-anthropic` | Same as google-vertex |
| `google` | Google API key |
| `anthropic` | Anthropic API key |

### Model ID Formats
- OpenCode Zen: `qwen3-coder`, `claude-sonnet-4`, `claude-opus-4-1`
- Google Vertex: `gemini-2.5-flash-preview-05-20`
- Vertex Anthropic: `claude-sonnet-4@20250514` (note the `@` version suffix)

---

## 6. Common Mistakes

### Mistake 1: Wrong prompt_async Format
**Symptom**: 204 response but no SSE events (only heartbeats)
**Cause**: Using `modelID`/`providerID` at top level instead of nested in `model`
**Fix**: Nest under `model` object

### Mistake 2: Wrong Completion Check
**Symptom**: Typing indicator never stops
**Cause**: Checking for `info.completed` boolean
**Fix**: Check for `info.time.completed` timestamp

### Mistake 3: Ignoring Error Events
**Symptom**: App hangs on provider errors
**Cause**: Not handling `session.error` or `info.error`
**Fix**: Parse and display error messages

### Mistake 4: Stale Gateway Port Cache
**Symptom**: 503 errors after OpenCode restart
**Cause**: Gateway cached old port, OpenCode restarted on new port
**Fix**: Stop and start project via gateway to refresh cache

### Mistake 5: Missing Environment Variables
**Symptom**: "location setting is missing" errors
**Cause**: `GOOGLE_VERTEX_LOCATION` not set in systemd service
**Fix**: Add to `~/.config/systemd/user/opencode@.service`

### Mistake 6: Assuming Providers Work
**Symptom**: SSE events received but with errors
**Cause**: Provider not configured (billing, API keys, etc.)
**Fix**: Check provider requirements, use working provider for testing

### Mistake 7: Missing API Keys in Systemd Service (CRITICAL)
**Symptom**: Model works when running OpenCode directly in terminal, but fails via iOS app/gateway with error:
```
"Method doesn't allow unregistered callers (callers without established identity). 
Please use API Key or other form of API consumer identity to call this API."
```

**Root Cause**: When you run OpenCode directly in your terminal, it inherits environment variables from your shell (e.g., `GOOGLE_API_KEY` from `~/.bashrc`). But when OpenCode runs as a **systemd service** (via the gateway), it does NOT have access to your shell environment.

**Why This Is Confusing**: 
- The same model works perfectly when you SSH into the server and run `opencode` manually
- But fails when accessed via the iOS app through the gateway
- This makes it seem like an iOS app bug, when it's actually a server configuration issue

**Fix**: Create an environment file with your API keys and configure systemd to load it:

```bash
# Step 1: Create environment file
mkdir -p ~/.config/opencode
cat > ~/.config/opencode/env << 'EOF'
# Google AI Studio API key (for 'google' provider)
GOOGLE_API_KEY=your-google-api-key-here

# Google Cloud credentials (for 'google-vertex' provider)  
# GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json

# Anthropic API key (if using direct Anthropic)
# ANTHROPIC_API_KEY=your-anthropic-key

# OpenAI API key (if using OpenAI)
# OPENAI_API_KEY=your-openai-key
EOF

# Step 2: Secure the file
chmod 600 ~/.config/opencode/env

# Step 3: Ensure systemd service loads it (already configured in opencode@.service)
# The service file should have: EnvironmentFile=-/home/linux/.config/opencode/env

# Step 4: Reload and restart
systemctl --user daemon-reload
systemctl --user restart opencode@YourProjectName
```

**Key Insight**: The `-` prefix in `EnvironmentFile=-/path/to/env` means systemd won't fail if the file doesn't exist (optional), but will load all variables from it if it does exist.

---

## 7. Error Handling

### Error Response Formats

#### Session Error Event
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
        "isRetryable": false,
        "responseHeaders": {...},
        "responseBody": "..."
      }
    }
  }
}
```

#### Message Error (in message.updated)
```json
{
  "type": "message.updated",
  "properties": {
    "info": {
      "id": "msg_xxx",
      "role": "assistant",
      "time": {
        "created": 1234567890,
        "completed": 1234567891
      },
      "error": {
        "name": "APIError",
        "data": {
          "message": "Error description"
        }
      }
    }
  }
}
```

### Common Error Types

| Error Name | Cause | Solution |
|------------|-------|----------|
| `APIError` | Provider API error | Check provider config |
| `UnknownError` | Generic error | Check error message |
| `CreditsError` | No payment method | Add payment at opencode.ai |

### Error Messages to Handle

| Message Pattern | Meaning |
|-----------------|---------|
| "No payment method" | OpenCode Zen requires billing |
| "location setting is missing" | Set GOOGLE_VERTEX_LOCATION |
| "Permission denied: Consumer...suspended" | GCP project suspended |
| "no providers found" | Invalid provider/model combo |

---

## 8. Server Configuration

### OpenCode Systemd Service
Location: `~/.config/systemd/user/opencode@.service`

```ini
[Unit]
Description=OpenCode Server for %i
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/linux/%i
ExecStart=/home/linux/.opencode/bin/opencode serve --port 0 --hostname 127.0.0.1
Restart=on-failure
RestartSec=5

# Environment - CRITICAL
Environment=HOME=/home/linux
Environment=GOOGLE_VERTEX_LOCATION=global
Environment=PATH=/home/linux/.local/bin:/home/linux/.bun/bin:/home/linux/.opencode/bin:/usr/local/bin:/usr/bin:/bin

# Resource limits
MemoryMax=2G
CPUQuota=200%

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=opencode-%i

[Install]
WantedBy=default.target
```

### Key Configuration Points

1. **Port 0**: OpenCode picks a random available port
2. **Hostname 127.0.0.1**: Only accessible locally (security)
3. **GOOGLE_VERTEX_LOCATION**: Required for Vertex providers
4. **MemoryMax**: Prevents runaway memory usage
5. **EnvironmentFile**: Loads API keys from `~/.config/opencode/env` (see Mistake 7 above)

### Environment File Setup (CRITICAL for API Keys)

When OpenCode runs as a systemd service, it does NOT inherit your shell's environment variables. You MUST create an environment file:

```bash
# Create the file
mkdir -p ~/.config/opencode
echo "GOOGLE_API_KEY=your-key-here" > ~/.config/opencode/env
chmod 600 ~/.config/opencode/env

# Restart the service
systemctl --user restart opencode@ProjectName
```

The systemd service file includes `EnvironmentFile=-/home/linux/.config/opencode/env` which automatically loads these variables.

### Service Management
```bash
# Reload after config changes
systemctl --user daemon-reload

# Start/stop/restart
systemctl --user start opencode@ProjectName
systemctl --user stop opencode@ProjectName
systemctl --user restart opencode@ProjectName

# Check status
systemctl --user status opencode@ProjectName

# View logs
journalctl --user -u opencode@ProjectName -f

# Find current port
journalctl --user -u opencode@ProjectName | grep "listening on"
```

---

## 9. Gateway Architecture

### Port Discovery
The gateway discovers OpenCode ports by:
1. Checking internal cache
2. Parsing journalctl logs for "listening on http://127.0.0.1:{port}"

### Port Cache Invalidation
The cache becomes stale when:
- OpenCode restarts (new port assigned)
- System reboot

### Refreshing Port Cache
```bash
# Stop and start to refresh
curl -X DELETE .../projects/Test/stop
curl -X POST .../projects/Test/start
```

### SSE Proxy Implementation
The gateway proxies SSE using `httpx.AsyncClient.stream()`:
```python
async def stream_sse():
    async with httpx.AsyncClient() as client:
        async with client.stream("GET", target_url, ...) as response:
            async for chunk in response.aiter_bytes():
                yield chunk
```

This correctly streams events without buffering.

---

## 10. Debugging Guide

### Step 1: Verify Gateway Health
```bash
curl https://vibecode.helmus.me/health
# Expected: {"status":"healthy"}
```

### Step 2: Check Project Status
```bash
curl -H "Authorization: Bearer $API_KEY" \
  https://vibecode.helmus.me/projects/Test/status
# Expected: {"name":"Test","port":12345,"status":"running"}
```

### Step 3: Test SSE Connection
```bash
curl -N -H "Authorization: Bearer $API_KEY" \
  https://vibecode.helmus.me/projects/Test/api/event
# Expected: data: {"type":"server.connected","properties":{}}
```

### Step 4: Test Message Sending
```bash
# Create session first
SESSION_ID=$(curl -s -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title":"Debug Test"}' \
  https://vibecode.helmus.me/projects/Test/api/session | jq -r '.id')

# Send message with CORRECT format
curl -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": {
      "providerID": "google-vertex-anthropic",
      "modelID": "claude-sonnet-4@20250514"
    },
    "parts": [{"type": "text", "text": "Say pong"}]
  }' \
  "https://vibecode.helmus.me/projects/Test/api/session/$SESSION_ID/prompt_async"
# Expected: 204 No Content
```

### Step 5: Monitor SSE for Events
Run SSE listener in one terminal, send message in another:
```bash
# Terminal 1: Listen to SSE
curl -N -H "Authorization: Bearer $API_KEY" \
  https://vibecode.helmus.me/projects/Test/api/event

# Terminal 2: Send message (as above)
```

### Step 6: Check Server Logs
```bash
ssh homelab 'journalctl --user -u opencode@Test -n 50 --no-pager'
```

### Common Debug Scenarios

#### No SSE Events After Sending Message
1. Check request format (must use nested `model` object)
2. Check provider is configured
3. Check for errors in server logs

#### 503 Errors
1. OpenCode may have restarted on new port
2. Stop and start project to refresh cache

#### Provider Errors
1. Check error message in SSE events
2. Verify provider configuration (API keys, billing, etc.)

---

## Appendix A: Full Endpoint List

### Gateway Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check (no auth) |
| GET | `/projects` | List projects |
| POST | `/projects/{name}/start` | Start OpenCode |
| DELETE | `/projects/{name}/stop` | Stop OpenCode |
| GET | `/projects/{name}/status` | Get status |
| ANY | `/projects/{name}/api/{path}` | Proxy to OpenCode |

### OpenCode Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/session` | List sessions |
| POST | `/session` | Create session |
| GET | `/session/{id}` | Get session |
| PATCH | `/session/{id}` | Update session |
| DELETE | `/session/{id}` | Delete session |
| GET | `/session/{id}/message` | Get messages |
| POST | `/session/{id}/message` | Send sync message |
| POST | `/session/{id}/prompt_async` | Send async message |
| POST | `/session/{id}/abort` | Abort generation |
| GET | `/session/{id}/todo` | Get todos |
| GET | `/session/{id}/diff` | Get diffs |
| POST | `/session/{id}/fork` | Fork session |
| POST | `/session/{id}/share` | Share session |
| GET | `/config/providers` | Get providers |
| GET | `/command` | Get commands |
| GET | `/mcp` | Get MCP status |
| GET | `/lsp` | Get LSP status |
| GET | `/agent` | Get agents |
| GET | `/event` | SSE stream |
| GET | `/global/health` | OpenCode health |

---

## Appendix B: Test Script

A comprehensive test script is available at `gateway/test_all_endpoints.py`.

Run with:
```bash
cd gateway
python3 test_all_endpoints.py
```

This tests all 24 critical endpoints and SSE streaming.

---

## Appendix C: Quick Reference Card

### Correct Request Format
```json
{
  "model": {"providerID": "...", "modelID": "..."},
  "parts": [{"type": "text", "text": "..."}]
}
```

### Completion Check
```javascript
if (info.time?.completed) { /* done */ }
```

### Error Check
```javascript
if (info.error || event.type === "session.error") { /* error */ }
```

### Working Provider
```
Provider: google-vertex-anthropic
Model: claude-sonnet-4@20250514
```

### Refresh Port Cache
```bash
curl -X DELETE .../projects/Test/stop && curl -X POST .../projects/Test/start
```
