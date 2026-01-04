# iOS App - VibeRemote

## OVERVIEW

SwiftUI iOS app using MVVM pattern. Connects to Gateway via HTTP/SSE for real-time chat with OpenCode.

## STRUCTURE

```
Sources/
├── Views/              # SwiftUI views
│   └── Chat/           # Chat UI components
├── ViewModels/         # MVVM view models
├── Services/           # Network, keychain, SSH
├── Models/             # Data models (SwiftData)
└── Theme/              # Design tokens
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Chat UI | `Views/Chat/ChatView.swift` | Main chat interface |
| Message rendering | `Views/Chat/MessageView.swift` | Markdown, code blocks |
| SSE parsing | `ViewModels/ChatViewModel.swift` | `handleSSEEvent()` |
| API client | `Services/OpenCodeClient.swift` | All OpenCode API calls |
| Gateway client | `Services/GatewayClient.swift` | Project start/stop |
| Data models | `Models/OpenCodeModels.swift` | Codable types for API |

## CONVENTIONS

- All API types in `OpenCodeModels.swift`
- ViewModels use `@MainActor`
- SwiftData for persistence (`AgentSession`, `ServerConfig`)
- Keychain for secrets via `KeychainManager`

## ANTI-PATTERNS

- **NEVER** check `info.completed` boolean (use `info.time.completed` timestamp)
- **NEVER** use short SSE timeouts (<120s) - thinking models need time
- **NEVER** ignore `session.error` events
- **NEVER** send `modelID`/`providerID` at top level (nest in `model` object)

## DEPENDENCIES

- SwiftTerm (terminal emulation - legacy)
- Citadel (SSH - legacy)
- SwiftData (persistence)

## NOTES

- `build/` contains Xcode artifacts - ignore in searches
- Use `xcodegen generate` after modifying `project.yml`
- Simulator testing only (no real device provisioning yet)
