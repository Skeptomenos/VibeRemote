# VibeRemote - Design & Architecture Decisions

## 1. Network Access Strategy

**Decision:** Use **Cloudflare Tunnel** as the primary access method.
**Domain:** `vibecode.helmes.me`

| Method | Role | Details |
|--------|------|---------|
| **Cloudflare Tunnel** | **Primary (API)** | Points `vibecode.helmes.me` → Local Gateway Port (4000). Allows access from anywhere without VPN. |
| **Tailscale** | **Backup (Secure)** | Available as fallback if Cloudflare is down or for direct SSH debugging. |
| **SSH (Port 22)** | **Legacy/Fallback** | Used for the existing Terminal view and server maintenance. |

**Implication for iOS:**
The iOS app will default to HTTPS requests against `https://vibecode.helmes.me`.

---

## 2. Authentication Strategy

**Decision:** **Shared Secret API Key (Bearer Token)** implemented at the Gateway level.

**Why:**
- **Lightweight:** Easy to implement in Python (Gateway) and Swift (iOS).
- **Secure Enough:** Traffic is encrypted via Cloudflare (HTTPS). The key ensures only the VibeRemote app can talk to the Gateway.
- **User Friendly:** User generates a key once on the server, scans a QR code (future) or pastes it into the iOS app.

**Implementation:**
1.  **Server:** Gateway starts with `VIBE_AUTH_SECRET="my-super-secret-key"`.
2.  **Gateway:** Middleware checks every request for `Authorization: Bearer my-super-secret-key`.
3.  **iOS:** User enters this key in Settings. It is stored in the Keychain.

*Note: Cloudflare Access (Zero Trust) was considered but rejected for MVP due to the complexity of implementing the web-login flow in a native API client.*

---

## 3. Project Discovery & Entry Point

**Decision:** **Home Directory (`~/`) is the Root.**

**Logic:**
- The Gateway (running in Docker) will mount the host user's home directory (read-only for discovery).
- **Discovery Algorithm:**
    1. Scan immediate subdirectories of `~/`.
    2. Filter for valid projects (contain `.git`, `package.json`, or explicitly allow all).
    3. Return list to iOS app.

**Example:**
- `~/Personal-OS` → Project "Personal-OS"
- `~/VibeRemote` → Project "VibeRemote"

---

## 4. Server-Side Infrastructure (The Gateway)

**Decision:** **Hybrid Docker + Systemd Architecture.**

This approach provides the best balance of isolation (Gateway) and capability (OpenCode access to host tools).

### Component A: The VibeGateway (Dockerized)
- **Role:** The "Traffic Cop" and "Manager".
- **Tech:** Python (FastAPI).
- **Functions:**
    - Authenticates requests.
    - Lists projects (scanning `~/`).
    - Starts/Stops OpenCode instances using `systemctl --user`.
    - Proxies API traffic to the correct running instance.
- **Port:** 4000 (exposed via Cloudflare).

### Component B: OpenCode Instances (Systemd)
- **Role:** The actual AI Agents.
- **Tech:** `opencode serve`.
- **Management:** Controlled by systemd user services.
- **Isolation:** Each project runs on a unique port (assigned dynamically or static range).

---

## 5. Unified Onboarding & Connection Flow

**Decision:** **Single "Server Profile" configuration supporting both modes.**

The app will have a "Servers" list. Each server profile contains:

| Field | Purpose | Required? |
|-------|---------|-----------|
| **Name** | Display name (e.g., "Home Server") | Yes |
| **API URL** | `https://vibecode.helmes.me` | For Chat/Native UI |
| **API Key** | The Shared Secret | For Chat/Native UI |
| **SSH Host** | IP or Hostname (e.g., `192.168.x.x` or Tailscale) | For Terminal/Fallback |
| **SSH User** | Linux username (`linux`) | For Terminal/Fallback |
| **SSH Key** | Private Key | For Terminal/Fallback |

**User Experience:**
1.  **Dashboard:** Shows list of detected projects (fetched via API).
2.  **Tap Project:** Opens **Native Chat View** (via API).
3.  **Long Press / Toggle:** Option to "Open in Terminal" (uses SSH).
4.  **Fallback:** If API is unreachable, UI suggests using SSH/Terminal mode.

---

## 6. Implementation Checklist

### Server-Side
- [ ] **Systemd Template:** Create `~/.config/systemd/user/opencode@.service`.
- [ ] **Gateway Service:**
    - [ ] Create `gateway/` directory with `main.py` (FastAPI).
    - [ ] Implement Auth Middleware.
    - [ ] Implement Project Scanner.
    - [ ] Implement `systemctl` wrapper.
    - [ ] Create `Dockerfile` & `docker-compose.yml`.
- [ ] **Cloudflare:** Update tunnel config to point to `localhost:4000`.

### iOS Client
- [ ] **Settings:** Update `ServerConfig` model to include `apiURL` and `apiKey`.
- [ ] **Networking:** Update `OpenCodeClient` to use the API Key header.
- [ ] **Discovery:** Add "Projects" screen that fetches from Gateway.

