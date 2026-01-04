# VibeRemote Implementation Handoff

**Status:** Ready for Implementation
**Next Step:** Server-Side Setup (Gateway)

## 📂 Documentation Map

| File | Purpose | Critical Notes for Implementation |
|------|---------|-----------------------------------|
| **`DECISIONS.md`** | **SOURCE OF TRUTH** | **Overrides other docs.** Contains final decisions on Auth (Bearer Token), Network (Cloudflare), and Infrastructure. |
| `ARCHITECTURE.md` | System Context | Explains *why* we are doing this. Defines the Systemd template. |
| `IMPLEMENTATION_PLAN.md` | Code Structure | Defines Swift models/views. **NOTE:** Needs adjustment for Auth headers (see below). |
| `DESIGN_SYSTEM.md` | UI/UX Specs | Defines the "ChatGPT-like" aesthetic. No bubbles. |

---

## ⚠️ Critical Implementation Instructions

### 1. Network & Auth Integration (The "Glue")
The `IMPLEMENTATION_PLAN.md` was written before the final Auth decision. When implementing `OpenCodeClient.swift`, you **MUST** apply the rules from `DECISIONS.md`:

1.  **Authorization Header:** Every request to the Gateway or OpenCode API must include:
    ```swift
    "Authorization": "Bearer <user-settings-api-key>"
    ```
2.  **Base URL Structure:**
    - **Gateway:** `https://vibecode.helmes.me`
    - **Project API (Proxy):** `https://vibecode.helmes.me/projects/{project_name}/api`
    - *Do not connect directly to IP:Port unless in SSH fallback mode.*

### 2. Project Discovery Flow
The iOS app needs a new "Projects" view before entering a chat.
1.  **Call Gateway:** `GET /projects`
2.  **Display:** List of folders found in `~/*`
3.  **On Tap:**
    - Call `POST /projects/{path}/start` (Gateway ensures service is running)
    - Navigate to `ChatView` using the proxy URL.

### 3. Execution Order (Strict)

1.  **Server Infrastructure (First):**
    - Create `gateway/` directory with `main.py` (FastAPI).
    - Implement the "Shared Secret" auth middleware.
    - Set up the `opencode@.service` systemd template.
    - Verify `curl -H "Authorization: Bearer key" https://vibecode.helmes.me/projects` works.

2.  **iOS Networking (Second):**
    - Implement `OpenCodeClient` with the Auth header.
    - Create `GatewayClient` for project discovery.

3.  **iOS UI (Third):**
    - Build `ChatView` using `VibeTheme`.
    - Connect the UI to the Client.

---

## Ready to Start?
The documents are consistent enough to proceed, provided you follow the **Overrides** listed above. 

**Start with Step 1: Server Infrastructure.**
