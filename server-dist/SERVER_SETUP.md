# VibeRemote Server Setup Guide

This guide explains how to prepare a Linux server to work with the VibeRemote iOS app.

## Prerequisites

- Linux server (tested on Fedora, should work on Ubuntu/Debian with `apt` instead of `dnf`)
- SSH access with key-based authentication
- sudo privileges

## Step 1: Install tmux

```bash
# Fedora/RHEL/CentOS
sudo dnf install -y tmux

# Ubuntu/Debian
# sudo apt install -y tmux
```

Verify installation:
```bash
tmux -V
```

## Step 2: Create the AgentOS Directory

```bash
mkdir -p ~/AgentOS
```

## Step 3: Create the Launch Script

```bash
cat > ~/AgentOS/launch-agent.sh << 'SCRIPT_EOF'
#!/bin/bash
#
# VibeRemote Launch Agent Script
# Manages tmux sessions for AI coding agents (opencode, claude, shell)
#
# Usage: launch-agent.sh <session-name> <project-path> <agent-type> <action>
#
# Arguments:
#   session-name  - Unique name for the tmux session
#   project-path  - Working directory for the session
#   agent-type    - One of: opencode, claude, shell
#   action        - One of: start, stop, restart, status
#

set -e

SESSION_NAME="$1"
PROJECT_PATH="$2"
AGENT_TYPE="$3"
ACTION="$4"

# Expand ~ in project path
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

# Validate arguments
if [[ -z "$SESSION_NAME" || -z "$PROJECT_PATH" || -z "$AGENT_TYPE" || -z "$ACTION" ]]; then
    echo "Usage: $0 <session-name> <project-path> <agent-type> <action>"
    echo "  agent-type: opencode, claude, shell"
    echo "  action: start, stop, restart, status"
    exit 1
fi

# Ensure project path exists
if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "Warning: Project path does not exist: $PROJECT_PATH"
    echo "Creating directory..."
    mkdir -p "$PROJECT_PATH"
fi

start_session() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "Session '$SESSION_NAME' already exists"
        return 0
    fi

    # Create new detached session in project directory
    tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_PATH"

    # Start the appropriate agent
    case "$AGENT_TYPE" in
        opencode)
            tmux send-keys -t "$SESSION_NAME" "opencode" Enter
            ;;
        claude)
            tmux send-keys -t "$SESSION_NAME" "claude" Enter
            ;;
        shell)
            # Just leave the shell prompt
            ;;
        *)
            echo "Unknown agent type: $AGENT_TYPE"
            tmux kill-session -t "$SESSION_NAME"
            exit 1
            ;;
    esac

    echo "Session '$SESSION_NAME' started with agent '$AGENT_TYPE' in '$PROJECT_PATH'"
}

stop_session() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t "$SESSION_NAME"
        echo "Session '$SESSION_NAME' stopped"
    else
        echo "Session '$SESSION_NAME' does not exist"
    fi
}

session_status() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "Session '$SESSION_NAME' is running"
        tmux list-windows -t "$SESSION_NAME"
    else
        echo "Session '$SESSION_NAME' is not running"
    fi
}

case "$ACTION" in
    start)
        start_session
        ;;
    stop)
        stop_session
        ;;
    restart)
        stop_session
        sleep 1
        start_session
        ;;
    status)
        session_status
        ;;
    *)
        echo "Unknown action: $ACTION"
        echo "Valid actions: start, stop, restart, status"
        exit 1
        ;;
esac
SCRIPT_EOF

chmod +x ~/AgentOS/launch-agent.sh
```

## Step 4: Verify the Setup

Test that the script works correctly:

```bash
# Start a test session
~/AgentOS/launch-agent.sh test-session ~ shell start

# Check it's running
tmux list-sessions

# Check status
~/AgentOS/launch-agent.sh test-session ~ shell status

# Clean up
~/AgentOS/launch-agent.sh test-session ~ shell stop

# Verify it's gone
tmux list-sessions
```

## Step 5: Install AI Agents (Optional)

If you want to use opencode or claude agents:

### OpenCode
```bash
# Install via npm (requires Node.js)
npm install -g @anthropic/opencode

# Or via curl
curl -fsSL https://opencode.ai/install.sh | sh
```

### Claude Code
```bash
# Install via npm
npm install -g @anthropic/claude-code
```

Verify installations:
```bash
which opencode
which claude
```

## Troubleshooting

### "tmux: command not found"
Make sure tmux is installed and in your PATH:
```bash
which tmux
# If not found, install it (see Step 1)
```

### "Session already exists"
This is normal - the script reuses existing sessions. To force a restart:
```bash
~/AgentOS/launch-agent.sh <session-name> <path> <type> restart
```

### SSH connection works but commands fail
Ensure the script is executable:
```bash
chmod +x ~/AgentOS/launch-agent.sh
```

### Agent command not found (opencode/claude)
The agent binaries need to be in PATH for non-interactive shells. Add to `~/.bashrc`:
```bash
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
```

## Directory Structure

After setup, your home directory should have:
```
~/
└── AgentOS/
    └── launch-agent.sh    # The session management script
```

## Server Requirements Summary

| Component | Required | Notes |
|-----------|----------|-------|
| tmux | Yes | Session management |
| SSH | Yes | With key-based auth |
| opencode | Optional | For opencode agent type |
| claude | Optional | For claude agent type |
