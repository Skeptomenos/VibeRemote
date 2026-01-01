# VibeRemote

A native iOS/iPadOS app for remotely controlling AI coding agent sessions (OpenCode, Claude Code) running on a Linux server via SSH.

![iOS 18+](https://img.shields.io/badge/iOS-18%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Mission

VibeRemote aims to create a **seamless vibe-coding experience on mobile** that feels like software-as-a-service, but is actually **bring your own infrastructure** and **bring your own API keys**.

No vendor lock-in. No cloud dependencies. Your server, your keys, your data. Just a beautiful native app that connects to your existing setup and gets out of your way.

## Overview

VibeRemote provides a full terminal interface on your iPhone or iPad to interact with AI coding agents running on a remote server. Connect to your development server via SSH, manage multiple agent sessions, and code from anywhere.

## Features

### Core
- **Native Terminal Experience** - Full terminal emulation using SwiftTerm with colors, escape sequences, and proper rendering
- **SSH Key Authentication** - Secure Ed25519 key-based authentication (no passwords)
- **Session Persistence** - Sessions run in tmux on the server, persist across app restarts and network changes
- **Multiple Agent Types** - Support for OpenCode, Claude Code, or plain shell sessions

### Session Management
- **Multiple Sessions** - Run multiple agent sessions across different projects simultaneously
- **UUID-Based Session Binding** - Permanent 1:1 mapping between app connections and tmux sessions (survives renames)
- **Folder Browser** - Browse and select project folders on your server via SSH
- **OpenCode Session Picker** - List, resume, or start new OpenCode sessions with human-readable titles
- **Edit Sessions** - Rename connections, change folders, switch OpenCode sessions
- **Auto-Refresh Titles** - Session titles automatically sync from server when viewing

### Server Administration
- **Tmux Admin Panel** - View all tmux sessions running on your server
- **Orphan Detection** - Identify sessions not linked to any app connection
- **Bulk Cleanup** - Kill individual or all orphaned tmux sessions

### Security
- **Keychain Storage** - SSH keys stored securely in iOS Keychain
- **Input Sanitization** - All shell commands sanitized to prevent injection
- **Thread Safety** - Proper MainActor handling for all UI state updates

### User Interface
- **iPad Split View** - Optimized sidebar + terminal layout for iPad
- **iPhone Support** - Full functionality on iPhone with navigation-based UI
- **Dark Mode** - Native dark mode support

## Architecture

```
┌─────────────────┐         SSH          ┌─────────────────┐
│   iOS Device    │◄──────────────────►  │  Linux Server   │
│                 │                       │                 │
│  ┌───────────┐  │                       │  ┌───────────┐  │
│  │ SwiftTerm │  │   PTY over SSH        │  │   tmux    │  │
│  │ Terminal  │◄─┼───────────────────────┼─►│  session  │  │
│  └───────────┘  │                       │  └─────┬─────┘  │
│                 │                       │        │        │
│  ┌───────────┐  │                       │  ┌─────▼─────┐  │
│  │  Citadel  │  │                       │  │ opencode  │  │
│  │ SSH Client│  │                       │  │  /claude  │  │
│  └───────────┘  │                       │  └───────────┘  │
└─────────────────┘                       └─────────────────┘
```

### Data Model

```
App Connection (AgentSession)
├── id: UUID (immutable, used for tmux session name)
├── name: String (human-readable, editable)
├── projectPath: String (folder on server, editable)
├── agentType: AgentType (opencode/claude/shell)
├── opencodeSessionId: String? (OpenCode session ID)
└── opencodeSessionTitle: String? (cached display name)

Relationships:
- App Connection ←─1:1─→ Tmux Session (permanent, by UUID)
- App Connection → Folder (configurable)
- App Connection → OpenCode Session (configurable)
```

## Requirements

### iOS App
- iOS 18.0+ / iPadOS 18.0+
- Xcode 16.0+

### Server
- Linux server (tested on Fedora, Ubuntu)
- SSH access with key-based authentication
- tmux installed
- (Optional) OpenCode or Claude Code CLI installed

## Installation

### iOS App

1. Clone the repository:
   ```bash
   git clone https://github.com/Skeptomenos/VibeRemote.git
   cd VibeRemote/ios-app/VibeRemote
   ```

2. Generate the Xcode project (requires XcodeGen):
   ```bash
   brew install xcodegen
   xcodegen generate
   ```

3. Open in Xcode and build:
   ```bash
   open VibeRemote.xcodeproj
   ```

4. Build and run on your device or simulator

### Server Setup

See [server-dist/SERVER_SETUP.md](server-dist/SERVER_SETUP.md) for detailed instructions.

Quick setup:
```bash
# Install tmux
sudo dnf install -y tmux  # Fedora
# sudo apt install -y tmux  # Ubuntu/Debian

# Create the launch script directory
mkdir -p ~/AgentOS

# Copy launch-agent.sh from server-dist/ to ~/AgentOS/
chmod +x ~/AgentOS/launch-agent.sh
```

## Configuration

### Adding a Server

1. Open VibeRemote on your iOS device
2. Tap the Settings (gear) icon
3. Add your server details:
   - **Host**: Your server's IP or hostname
   - **Port**: SSH port (default: 22)
   - **Username**: Your SSH username
   - **Private Key**: Paste your Ed25519 private key

### Creating a Session

1. Tap the "+" button
2. Enter a session name
3. Browse and select a project folder on your server
4. Choose an agent type:
   - **OpenCode** - OpenCode CLI
   - **Claude** - Claude Code CLI
   - **Shell** - Plain bash shell
5. For OpenCode: optionally select an existing session to resume
6. Tap Create

### Managing Sessions

- **Edit**: Tap the edit button on a session to rename, change folder, or switch OpenCode session
- **Delete**: Swipe left or use edit view to delete
- **Tmux Admin**: Settings → Tmux Sessions to manage server-side sessions

## Project Structure

```
VibeRemote/
├── ios-app/
│   └── VibeRemote/
│       ├── Sources/
│       │   ├── Models/          # Data models (AgentSession, ServerConfig)
│       │   ├── Services/        # SSH connection, Keychain, Snapshots
│       │   └── Views/           # SwiftUI views and terminal
│       └── project.yml          # XcodeGen project definition
├── server-dist/
│   ├── launch-agent.sh          # Server-side session management script
│   └── SERVER_SETUP.md          # Server setup instructions
└── docs/                        # Design documents and planning
```

## Dependencies

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - Terminal emulator view
- [Citadel](https://github.com/orlandos-nl/Citadel) - Swift SSH client library

## Development Status

### Working
- SSH connection with Ed25519 key authentication
- Terminal display with colors and escape sequences
- Keyboard input
- Folder browser with create folder functionality
- OpenCode session picker with title refresh
- Edit session view (rename, change folder, change session, delete)
- Tmux admin panel (list sessions, kill orphans)
- Session lifecycle (start, stop, restart)
- Multiple parallel sessions to same folder

### Planned
- Keyboard toolbar with Ctrl, Esc, Tab buttons
- OpenCode Server API integration (richer features)
- Session snapshots and history
- Multiple server support

## Known Limitations

- Requires iOS 18+ for PTY support via Citadel
- macOS SSH servers using post-quantum algorithms are not compatible (use Linux servers)
- Ed25519 keys only (RSA not currently supported)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) by Miguel de Icaza
- [Citadel](https://github.com/orlandos-nl/Citadel) by Orlandos
- Inspired by the need to vibe-code from anywhere
