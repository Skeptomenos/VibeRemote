# VibeRemote - Architecture & Project Status

## Vision

**VibeRemote** is a native iOS/iPadOS app for remotely controlling AI coding agent sessions (OpenCode) running on a Linux server. The core principle is **BYOI (Bring Your Own Infrastructure)** - your code stays on your server, your API keys, your control.

**Repository:** https://github.com/Skeptomenos/VibeRemote  
**Server:** 192.168.178.2 (Debian Linux, 16GB RAM, 8 cores)

---

## Table of Contents

1. [Current State](#current-state)
2. [The Pivot: OpenCode Server API](#the-pivot-opencode-server-api)
3. [API Capabilities](#api-capabilities)
4. [Challenges & Solutions](#challenges--solutions)
5. [Architecture Plan](#architecture-plan)
6. [Implementation Plan](#implementation-plan)
7. [Comparison: Old vs New Approach](#comparison-old-vs-new-approach)
8. [Next Steps](#next-steps)
9. [Open Questions](#open-questions)

---

## Current State

### What We Built (SSH + Terminal Approach)

| Component                        | Status      | Notes                  |
| -------------------------------- | ----------- | ---------------------- |
| SSH key-based connection         | ✅ Working  | Via Citadel library    |
| Terminal display                 | ✅ Working  | SwiftTerm library      |
| Scrolling (Page Up/Down buttons) | ✅ Working  | Sends escape sequences |
| OpenCode dark theme              | ✅ Working  | Immersive UI           |
| Password-based SSH auth          | ❌ Broken   | Citadel library issue  |
| Two-finger touch scroll          | ❓ Untested | Needs real device      |

### Key Files

```
ios-app/VibeRemote/Sources/
├── Views/
│   ├── TerminalView.swift      # Terminal UI, scroll controls
│   ├── SettingsView.swift      # Settings with SSH key setup
│   └── NewSessionWizard.swift  # Session creation flow
├── Services/
│   ├── SSHConnectionManager.swift  # SSH connection handling
│   └── SnapshotManager.swift       # Session state management
└── Models/
    ├── AgentSession.swift      # Session data model
    └── ServerConfig.swift      # Server configuration
```

---

## The Pivot: OpenCode Server API

### Discovery

We discovered that OpenCode has an **official HTTP server** (`opencode serve`) that eliminates the need for terminal emulation entirely.

**How we found it:**
1. Researched OpenCode ecosystem
2. Found `hosenur/portal` - a mobile-first web UI using the API (144 stars)
3. Discovered `@opencode-ai/sdk` npm package with TypeScript types
4. Tested the API directly on the server

### Why This Changes Everything

```
OLD APPROACH:
iPhone → SSH → tmux → OpenCode TUI → Parse terminal escape codes

NEW APPROACH:
iPhone → HTTP/SSE → OpenCode Server → Clean JSON responses
```

**Benefits:**
- Native SwiftUI chat interface (no terminal emulation)
- Standard iOS networking (URLSession, Codable)
- Real-time via SSE (well-supported in iOS)
- No SwiftTerm/PTY complexity
- Scrolling = native scroll view
- BYOI preserved (runs on your infrastructure with your API keys)

---

## API Capabilities

### Endpoints (Complete List)

#### Core Session Management

| Endpoint                          | Method | Description                          |
| --------------------------------- | ------ | ------------------------------------ |
| `/session`                        | GET    | List all sessions                    |
| `/session`                        | POST   | Create new session                   |
| `/session/{id}`                   | GET    | Get session details                  |
| `/session/{id}`                   | DELETE | Delete session                       |
| `/session/{id}/message`           | GET    | Get all messages                     |
| `/session/{id}/message`           | POST   | Send message (streaming response)    |
| `/session/{id}/message/{msgID}`   | DELETE | Delete specific message              |
| `/session/{id}/prompt_async`      | POST   | Send message async (fire-and-forget) |
| `/session/{id}/abort`             | POST   | Abort current operation              |
| `/session/{id}/fork`              | POST   | Fork session                         |
| `/session/{id}/todo`              | GET    | Get session todos                    |
| `/session/{id}/diff`              | GET    | Get session diffs                    |
| `/session/{id}/revert`            | POST   | Revert changes                       |
| `/session/{id}/share`             | POST   | Share session                        |
| `/session/{id}/summarize`         | POST   | Summarize session                    |
| `/session/status`                 | GET    | Get session status                   |

#### File Operations

| Endpoint       | Method | Description       |
| -------------- | ------ | ----------------- |
| `/file`        | GET    | List files        |
| `/file/content`| GET    | Read file content |
| `/file/status` | GET    | Get file status   |
| `/find/file`   | GET    | Fuzzy file search |
| `/find/symbol` | GET    | Symbol search     |

#### Configuration & Providers

| Endpoint           | Method   | Description                |
| ------------------ | -------- | -------------------------- |
| `/config`          | GET      | Get configuration          |
| `/config/providers`| GET      | List AI providers & models |
| `/provider`        | GET      | Provider info              |
| `/provider/auth`   | GET/POST | Provider authentication    |

#### Real-Time Events

| Endpoint        | Method | Description                   |
| --------------- | ------ | ----------------------------- |
| `/event`        | GET    | **SSE stream** - Real-time events |
| `/global/event` | GET    | Global events                 |
| `/global/health`| GET    | Health check                  |

#### Advanced Features

| Endpoint              | Method | Description            |
| --------------------- | ------ | ---------------------- |
| `/agent`              | GET    | List agents            |
| `/command`            | GET    | List commands          |
| `/mcp`                | GET    | MCP server status      |
| `/mcp/{name}/connect` | POST   | Connect MCP            |
| `/lsp`                | GET    | LSP status             |
| `/vcs`                | GET    | Version control status |
| `/pty`                | GET    | PTY sessions           |
| `/log`                | GET    | Logs                   |

### Key Findings

| Question                           | Answer                                                |
| ---------------------------------- | ----------------------------------------------------- |
| Multiple sessions simultaneously?  | ✅ YES - Fully supported                              |
| Sessions persist on restart?       | ✅ YES - Stored in `~/.local/share/opencode/storage/` |
| Sessions continue when app closes? | ✅ YES - `prompt_async` + server-side processing     |
| Different working directories?     | ⚠️ PARTIAL - One directory per server instance       |
| Update OpenCode?                   | ✅ YES - `opencode upgrade` command                   |

### Message Format

#### Sending a Message

```json
POST /session/{id}/message
{
  "parts": [
    {
      "type": "text",
      "text": "Your prompt here"
    }
  ],
  "providerID": "opencode",
  "modelID": "claude-sonnet-4"
}
```

#### Response Format

```json
{
  "info": {
    "id": "msg_XXX",
    "sessionID": "ses_XXX",
    "role": "assistant",
    "time": { "created": 1234567890, "completed": 1234567891 },
    "modelID": "claude-sonnet-4",
    "providerID": "opencode",
    "cost": 0.0023,
    "tokens": { "input": 100, "output": 50, "reasoning": 0 }
  },
  "parts": [
    { "type": "text", "text": "Response text..." },
    { "type": "tool-invocation", ... },
    { "type": "tool-result", ... }
  ]
}
```

### SSE Event Types

The `/event` endpoint streams these event types:
- `server.connected` - Initial connection
- `message.updated` - Message content updates
- `message.removed` - Message deleted
- `part.updated` - Part content updates (streaming text)
- `session.updated` - Session state changes
- `lsp.client.diagnostics` - LSP diagnostics
- `installation.update-available` - Update available

### Session Storage

```
~/.local/share/opencode/
├── storage/
│   ├── session/{projectID}/{sessionID}.json
│   ├── message/{messageID}.json
│   ├── part/{partID}.json
│   └── project/{projectID}.json
├── log/
└── auth.json
```

- **projectID** = SHA1 hash of directory path
- Sessions are project-scoped
- Messages/parts stored separately for efficiency

---

## Challenges & Solutions

### Challenge 1: One Server = One Directory

**Problem:** Each `opencode serve` instance is bound to the directory it started in.

**Solution:** Run multiple server instances on different ports.

```bash
cd ~/Personal-OS && opencode serve --port 4096 --hostname 0.0.0.0
cd ~/AgentOS && opencode serve --port 4097 --hostname 0.0.0.0
```

**Discovery:** `--port 0` auto-assigns a random port and prints it to stdout:
```
opencode server listening on http://0.0.0.0:45535
```

---

### Challenge 2: Network Access (Firewall)

**Problem:** Direct HTTP access to port 4096 blocked from external machines, even though server binds to `0.0.0.0`.

**Workaround:** SSH port forwarding works:
```bash
ssh -L 4096:localhost:4096 linux@192.168.178.2
# Then connect to http://localhost:4096
```

**Production options:**
1. **SSH tunnel** from iOS app (already have SSH working)
2. **Tailscale** (already have `tailscale-router` container)
3. **Cloudflare tunnel** (already have `cloudflared` container)

---

### Challenge 3: Managing Multiple OpenCode Instances

**Problem:** How does the iOS app know which servers are running, on which ports, for which projects?

**Initial idea:** Per-folder JSON config files.

**Issue:** Creates chicken-and-egg problem:
- To read the JSON, you need to know the folder
- To know the folder, you need... what exactly?
- The server must be running to serve the folder
- But you need to know the port to connect to the server

**Solution:** Centralized Gateway service that:
- Discovers available projects
- Starts/stops OpenCode instances on demand
- Tracks port assignments
- Proxies requests to correct instance

---

### Challenge 4: Docker vs Native for OpenCode

**Problem:** Should OpenCode run in Docker for stability/restart capability?

**Analysis:** OpenCode is fundamentally a HOST tool:
- Needs access to ALL project directories
- Spawns MCP servers (Python, Go, Node processes)
- Uses host SSH keys, git, npm, etc.
- Self-updates via `opencode upgrade`

**Containerizing would require:**
```yaml
volumes:
  - /home/linux:/home/linux          # ALL home directory
  - /home/linux/.ssh:/root/.ssh      # SSH keys
  - /home/linux/.config:/root/.config # All configs
```

This is essentially "Docker as a process manager" with no real isolation benefit.

**Solution:** Hybrid approach:
- **Gateway** → Docker (clean, isolated, integrates with Traefik)
- **OpenCode instances** → Systemd user services (native access, proper process management)

---

### Challenge 5: Session Persistence When App Closes

**Problem:** Does the AI keep running when the iOS app closes?

**Tested behavior:**
1. `POST /session/{id}/prompt_async` returns immediately
2. AI processing continues on server regardless of client connection
3. Response is persisted to session when complete
4. Client can reconnect later and fetch messages via `GET /session/{id}/message`

**iOS App Flow:**
```
1. User sends message
   ├── App in foreground → Use /message (streaming)
   └── App going to background → Use /prompt_async

2. App closes/backgrounds
   └── Server continues processing → Saves response

3. App reopens
   ├── GET /session/{id}/message → Fetch all messages
   └── Connect to /event SSE → Resume real-time updates
```

---

## Architecture Plan

### System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Linux Server                            │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │     VibeRemote Gateway (Docker Container)              │ │
│  │     Port 4000 (via Traefik)                            │ │
│  │                                                         │ │
│  │     Endpoints:                                          │ │
│  │     - GET  /projects         → List available projects │ │
│  │     - POST /projects/{path}/start → Start OpenCode     │ │
│  │     - DELETE /projects/{path}/stop → Stop OpenCode     │ │
│  │     - GET  /projects/{path}/status → Check if running  │ │
│  │     - *    /projects/{path}/api/* → Proxy to OpenCode  │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │     Systemd User Services (Native)                      │ │
│  │                                                         │ │
│  │     opencode@Personal-OS.service  → :4096              │ │
│  │     opencode@AgentOS.service      → :4097              │ │
│  │     (on-demand, auto-restart, resource-limited)        │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │     Project Directories + OpenCode Storage              │ │
│  │     /home/linux/Personal-OS/                           │ │
│  │     /home/linux/AgentOS/                               │ │
│  │     ~/.config/opencode/                                │ │
│  │     ~/.local/share/opencode/                           │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ HTTPS (Tailscale/Cloudflare)
                          │
                ┌─────────────────┐
                │   iOS App       │
                │   (VibeRemote)  │
                │                 │
                │   Native SwiftUI│
                │   Chat Interface│
                └─────────────────┘
```

### Systemd Service Template

```ini
# ~/.config/systemd/user/opencode@.service
[Unit]
Description=OpenCode Server for %i
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/linux/%i
ExecStart=/home/linux/.opencode/bin/opencode serve --port 0 --hostname 127.0.0.1
Restart=on-failure
RestartSec=5
Environment=HOME=/home/linux
Environment=PATH=/home/linux/.local/bin:/home/linux/.bun/bin:/usr/local/bin:/usr/bin:/bin

# Resource limits
MemoryMax=2G
CPUQuota=200%

[Install]
WantedBy=default.target
```

**Usage:**
```bash
# Enable lingering (services run without login)
loginctl enable-linger linux

# Start for a project
systemctl --user start opencode@Personal-OS

# Enable auto-start
systemctl --user enable opencode@Personal-OS

# Check status
systemctl --user status opencode@Personal-OS

# View logs
journalctl --user -u opencode@Personal-OS -f
```

### Gateway Docker Compose

```yaml
# docker-compose.yml
services:
  viberemote-gateway:
    image: viberemote-gateway:latest
    container_name: viberemote-gateway
    restart: unless-stopped
    ports:
      - "4000:4000"
    environment:
      - OPENCODE_BASE_PORT=4096
      - PROJECTS_BASE_PATH=/home/linux
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro  # Optional: for container management
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.viberemote.rule=Host(`viberemote.local`)"
      - "traefik.http.services.viberemote.loadbalancer.server.port=4000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  traefik:
    external: true
```

---

## Implementation Plan

### Phase 1: Swift API Client

Create `OpenCodeClient.swift` with:

```swift
// Models (from @opencode-ai/sdk types)
struct Session: Codable {
    let id: String
    let version: String
    let projectID: String
    let directory: String
    let title: String
    let time: SessionTime
    let summary: SessionSummary?
}

struct Message: Codable {
    let info: MessageInfo
    let parts: [MessagePart]
}

// Client
class OpenCodeClient {
    private let baseURL: URL
    private let session: URLSession
    
    func listSessions() async throws -> [Session]
    func createSession(title: String) async throws -> Session
    func deleteSession(id: String) async throws
    func getMessages(sessionId: String) async throws -> [Message]
    func sendMessage(sessionId: String, text: String) async throws -> Message
    func sendMessageAsync(sessionId: String, text: String) async throws
    func subscribeToEvents(sessionId: String) -> AsyncStream<ServerEvent>
    func abort(sessionId: String) async throws
}
```

### Phase 2: Native Chat UI

Replace terminal emulation with SwiftUI:

- Message bubbles (user/assistant)
- Streaming text display with typing indicator
- Native scrolling (finally!)
- Tool call visualization (collapsible)
- Todo list display
- Diff viewer
- Session picker

### Phase 3: Gateway Service

Build Docker container with:

```python
# gateway.py (FastAPI)
from fastapi import FastAPI, HTTPException
import subprocess
import httpx

app = FastAPI()
servers: dict[str, dict] = {}  # path -> {port, pid}

@app.get("/projects")
async def list_projects():
    """Scan for directories with .git"""
    ...

@app.post("/projects/{path:path}/start")
async def start_server(path: str):
    """Start OpenCode via systemctl, return port"""
    ...

@app.delete("/projects/{path:path}/stop")
async def stop_server(path: str):
    """Stop OpenCode server"""
    ...

@app.get("/projects/{path:path}/status")
async def server_status(path: str):
    """Check if server is running"""
    ...

@app.api_route("/projects/{path:path}/api/{endpoint:path}", methods=["GET", "POST", "DELETE"])
async def proxy(path: str, endpoint: str):
    """Proxy to correct OpenCode instance"""
    ...
```

### Phase 4: Network & Security

Options (choose one):

1. **Tailscale** (Recommended)
   - Install Tailscale on iOS device
   - Access server via Tailscale IP
   - Encrypted, no port exposure
   - Already have `tailscale-router` container

2. **Cloudflare Tunnel**
   - Already have `cloudflared` container
   - Expose Gateway via tunnel
   - Add authentication layer

3. **SSH Tunnel** (Fallback)
   - Use existing SSH connection
   - Forward Gateway port
   - Works but less elegant

### Phase 5: Multi-Project Support

- Project picker in iOS app
- On-demand server startup
- Session management per project
- Background refresh of project list

---

## Comparison: Old vs New Approach

| Aspect                | SSH + Terminal            | HTTP API                    |
| --------------------- | ------------------------- | --------------------------- |
| Complexity            | High (PTY, escape codes)  | Low (REST/JSON)             |
| Real-time             | Parse terminal output     | SSE events                  |
| Scrolling             | Page Up/Down escape codes | Native scroll view          |
| Multi-session         | Multiple tmux panes       | Multiple API sessions       |
| Persistence           | Tmux session on server    | Built-in JSON storage       |
| iOS Integration       | SwiftTerm library         | URLSession + Codable        |
| Network               | SSH (port 22)             | HTTP (any port)             |
| Background processing | Tmux keeps running        | `prompt_async` + persistence|
| Code complexity       | ~2000 lines               | ~500 lines (estimated)      |

---

## Next Steps

### Immediate (Phase 1)

1. [ ] Create systemd service template for OpenCode instances
2. [ ] Test systemd service with multiple projects
3. [ ] Build basic Gateway service (Python/FastAPI)
4. [ ] Dockerize Gateway with Traefik integration

### Short-term (Phase 2-3)

5. [ ] Create Swift `OpenCodeClient` with API types
6. [ ] Build SwiftUI chat interface
7. [ ] Implement SSE streaming in Swift
8. [ ] Add project picker UI

### Medium-term (Phase 4-5)

9. [ ] Configure Tailscale or Cloudflare access
10. [ ] Add authentication to Gateway
11. [ ] Test end-to-end on real iOS device
12. [ ] Polish UI/UX

---

## Open Questions

### Architecture

1. **Authentication**: How to secure the Gateway?
   - API key in header?
   - OAuth with your identity provider?
   - Tailscale handles it?

2. **Project discovery**: How to find available projects?
   - Scan all directories for `.git`?
   - Explicit config file listing projects?
   - Both?

3. **Resource limits**: How many concurrent OpenCode instances?
   - Each uses ~300-500MB RAM
   - Server has 16GB, ~8GB available
   - Limit to 5-10 concurrent?

### Features

4. **Notifications**: Push notifications when long-running task completes?
   - Requires Apple Push Notification service
   - Gateway would need to track and notify

5. **File editing**: Allow editing files from iOS?
   - Read-only initially?
   - Simple editor for quick fixes?

6. **Image support**: OpenCode supports image input
   - Allow attaching photos from iOS?
   - Screenshot annotation?

---

## Related Projects

- **OpenCode**: https://github.com/sst/opencode
- **OpenCode SDK**: `@opencode-ai/sdk` npm package
- **Portal**: https://github.com/hosenur/portal (mobile-first web UI)
- **opencode-vibe**: https://github.com/joelhooks/opencode-vibe (Next.js web UI)

---

## Build Commands

### iOS App (Current)

```bash
cd ios-app/VibeRemote && xcodegen generate
xcodebuild -project VibeRemote.xcodeproj -scheme VibeRemote \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build build
xcrun simctl install "iPhone 16" build/Build/Products/Debug-iphonesimulator/VibeRemote.app
xcrun simctl launch "iPhone 16" com.vibeRemote.app
```

### Server (Future)

```bash
# Start OpenCode for a project
systemctl --user start opencode@Personal-OS

# Start Gateway
docker-compose up -d viberemote-gateway

# View logs
journalctl --user -u opencode@Personal-OS -f
docker logs -f viberemote-gateway
```

---

*Last updated: January 2026*
