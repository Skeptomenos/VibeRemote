# VibeRemote

A native iOS/iPadOS app for remotely controlling AI coding agent sessions (OpenCode, Claude Code) running on a Linux server via SSH.

![iOS 18+](https://img.shields.io/badge/iOS-18%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Overview

VibeRemote provides a full terminal interface on your iPhone or iPad to interact with AI coding agents running on a remote server. Connect to your development server via SSH, manage multiple agent sessions, and code from anywhere.

### Key Features

- **Native Terminal Experience** - Full terminal emulation using SwiftTerm with colors, escape sequences, and proper rendering
- **SSH Key Authentication** - Secure Ed25519 key-based authentication (no passwords)
- **Multiple Sessions** - Manage multiple agent sessions across different projects
- **Agent Types** - Support for OpenCode, Claude Code, or plain shell sessions
- **Session Persistence** - Sessions run in tmux on the server, persist across app restarts
- **iPad Split View** - Optimized UI for both iPhone and iPad

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

# Create the launch script
mkdir -p ~/AgentOS
# Copy launch-agent.sh from server-dist/
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
3. Set the project path on the server
4. Choose an agent type:
   - **OpenCode** - Anthropic's OpenCode CLI
   - **Claude** - Claude Code CLI
   - **Shell** - Plain bash shell
5. Tap Create

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

🚧 **Work in Progress** - This is an active development project.

### Working
- ✅ SSH connection with Ed25519 key authentication
- ✅ Terminal display with colors and escape sequences
- ✅ Session management UI
- ✅ Server-side launch script

### In Progress
- 🔄 Keyboard input handling
- 🔄 Session persistence and reconnection
- 🔄 tmux integration

### Planned
- 📋 Session snapshots and history
- 📋 Multiple server support
- 📋 Keyboard shortcuts and gestures
- 📋 iPad keyboard support

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
