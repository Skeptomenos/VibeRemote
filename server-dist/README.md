# VibeRemote Server Setup

## Installation

1. **Copy the script to your home directory:**
   ```bash
   mkdir -p ~/AgentOS
   cp launch-agent.sh ~/AgentOS/
   chmod +x ~/AgentOS/launch-agent.sh
   ```

2. **Ensure dependencies are installed:**
   ```bash
   brew install tmux
   # For OpenCode:
   pip install opencode
   # For Claude:
   npm install -g @anthropic-ai/claude-code
   ```

3. **Install Tailscale (for remote access):**
   ```bash
   brew install tailscale
   # Follow Tailscale setup to join your network
   ```

## Usage

The iOS app will call this script via SSH. You can also test it manually:

```bash
# Start a new session
~/AgentOS/launch-agent.sh my-project ~/Repos/my-project opencode start

# Check status
~/AgentOS/launch-agent.sh my-project ~/Repos/my-project opencode status

# Restart (useful after updates)
~/AgentOS/launch-agent.sh my-project ~/Repos/my-project opencode restart

# Stop a session
~/AgentOS/launch-agent.sh my-project ~/Repos/my-project opencode stop

# Update the agent
~/AgentOS/launch-agent.sh my-project ~/Repos/my-project opencode update
```

## Attaching Manually

To view a running session from your Mac terminal:
```bash
tmux attach -t my-project
```

To detach (leave it running): Press `Ctrl-B` then `D`.
