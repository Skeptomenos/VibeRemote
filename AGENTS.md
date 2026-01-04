# VIBEREMOTE - PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-04  
**Commit:** 9e8dd2c  
**Branch:** main

## OVERVIEW

Native iOS app for remotely controlling OpenCode AI coding sessions via HTTP/SSE gateway. BYOI (Bring Your Own Infrastructure) - your server, your API keys, your data.

## STRUCTURE

```
VibeRemote/
├── ios-app/VibeRemote/     # Swift iOS app (MVVM, SwiftUI)
├── gateway/                # Python FastAPI proxy to OpenCode
├── design-os/              # React design system tool (separate project)
├── server-dist/            # Server deployment scripts
├── *.md                    # Extensive documentation (see below)
└── ssh-test/               # Swift SSH testing playground
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| iOS chat UI | `ios-app/VibeRemote/Sources/Views/Chat/` | ChatView, MessageView |
| SSE streaming | `ios-app/.../Services/OpenCodeClient.swift` | `connectSSE()` method |
| Gateway proxy | `gateway/main.py` | FastAPI, SSE proxy at line 346 |
| API reference | `OPENCODE_API_REFERENCE.md` | **CRITICAL**: Request format gotchas |
| SSE event flow | `IOS_APP_SSE_FLOW_SPEC.md` | Event types, completion detection |
| Test gateway | `gateway/test_all_endpoints.py` | Comprehensive API tests |
| Architecture | `ARCHITECTURE.md` | System design, API capabilities |

## CRITICAL API GOTCHA

**prompt_async request format** - Wrong format silently fails (204 but no SSE events):

```json
// WRONG - top-level fields
{"modelID": "...", "providerID": "...", "parts": [...]}

// CORRECT - nested model object
{"model": {"providerID": "...", "modelID": "..."}, "parts": [...]}
```

See `OPENCODE_API_REFERENCE.md` Section 3 for full details.

## CONVENTIONS

| Area | Convention |
|------|------------|
| iOS architecture | MVVM with SwiftUI |
| iOS data | SwiftData for persistence |
| Gateway | FastAPI with httpx for async HTTP |
| SSE completion | Check `info.time.completed` (timestamp), NOT `info.completed` (doesn't exist) |
| Error handling | Check both `info.error` and `session.error` events |

## ANTI-PATTERNS (THIS PROJECT)

- **NEVER** use top-level `modelID`/`providerID` in prompt_async (must nest in `model` object)
- **NEVER** check `info.completed` boolean (use `info.time.completed` timestamp)
- **NEVER** ignore `session.error` events (causes infinite typing indicator)
- **NEVER** assume gateway port is stable (OpenCode restarts on random port)
- **NEVER** use short SSE timeouts (thinking models need 120s+)

## COMMANDS

```bash
# iOS App
cd ios-app/VibeRemote && xcodegen generate && open VibeRemote.xcodeproj

# Gateway (local)
cd gateway && python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt && python main.py

# Gateway tests
cd gateway && python test_all_endpoints.py

# Design-OS (separate project)
cd design-os && npm install && npm run dev
```

## DOCUMENTATION MAP

| File | Purpose |
|------|---------|
| `ARCHITECTURE.md` | System design, API capabilities, pivot rationale |
| `OPENCODE_API_REFERENCE.md` | **READ FIRST** - API gotchas, request formats |
| `IOS_APP_SSE_FLOW_SPEC.md` | SSE event types, parsing, completion detection |
| `IOS_APP_HANDOVER.md` | Current iOS app status, recent fixes |
| `GATEWAY_TEST_PLAN.md` | Test cases, known issues |
| `HANDOVER.md` | Gateway testing context |
| `IMPLEMENTATION_PLAN.md` | Detailed implementation roadmap |
| `DESIGN_SYSTEM.md` | UI/UX design tokens |

## NOTES

- Gateway runs on `https://vibecode.helmus.me` (Cloudflare tunnel)
- OpenCode binds to `127.0.0.1` only (security via gateway)
- Port discovery via journalctl logs (last match = current port)
- `design-os/` is a separate React project, not part of iOS app
- Build artifacts in `ios-app/VibeRemote/build/` - ignore in searches
