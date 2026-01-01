#!/bin/zsh
# ============================================================================
# VibeRemote: Agent Launcher Script (Hardened)
# ============================================================================
# Usage: ./launch-agent.sh [SESSION_NAME] [PROJECT_PATH] [AGENT_TYPE] [ACTION]
#
# Arguments:
#   SESSION_NAME  - The tmux session identifier (e.g., "website-refactor")
#   PROJECT_PATH  - Absolute path to the project directory (e.g., ~/Repos/my-app)
#   AGENT_TYPE    - The agent to run: "opencode", "claude", or "shell"
#   ACTION        - Command: "start", "restart", "stop", "update", "status"
#
# Examples:
#   ./launch-agent.sh my-project ~/Repos/my-project opencode start
#   ./launch-agent.sh my-project ~/Repos/my-project opencode restart
#   ./launch-agent.sh my-project ~/Repos/my-project opencode stop
# ============================================================================

set -e

# --- GAP 2 FIX: Environment Loading ---
# SSH non-interactive shells don't load profiles. We must do it explicitly.
if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc" 2>/dev/null || true
elif [ -f "$HOME/.bash_profile" ]; then
    source "$HOME/.bash_profile" 2>/dev/null || true
fi

# Fallback: Ensure Homebrew and common paths are available
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# ============================================================================
# Arguments
# ============================================================================
SESSION="${1:?Error: SESSION_NAME required}"
PROJECT_PATH="${2:?Error: PROJECT_PATH required}"
AGENT="${3:?Error: AGENT_TYPE required (opencode|claude|shell)}"
ACTION="${4:-start}"

# Sanitize session name for tmux (replace spaces with dashes)
SESSION=$(echo "$SESSION" | tr ' ' '-' | tr -cd '[:alnum:]-_')

# ============================================================================
# Helper Functions
# ============================================================================
log() {
    echo "[VibeRemote] $1"
}

get_agent_command() {
    case "$AGENT" in
        opencode)
            echo "opencode"
            ;;
        claude)
            echo "claude"
            ;;
        shell)
            echo "zsh"
            ;;
        *)
            echo "Error: Unknown agent type: $AGENT" >&2
            exit 1
            ;;
    esac
}

# ============================================================================
# Actions
# ============================================================================

action_status() {
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        log "Session '$SESSION' is RUNNING"
        echo "RUNNING"
    else
        log "Session '$SESSION' is STOPPED"
        echo "STOPPED"
    fi
}

action_stop() {
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        tmux kill-session -t "$SESSION"
        log "Session '$SESSION' stopped."
        echo "STOPPED"
    else
        log "Session '$SESSION' was not running."
        echo "NOT_RUNNING"
    fi
}

action_update() {
    log "Updating agent: $AGENT"
    case "$AGENT" in
        opencode)
            pip install --upgrade opencode 2>&1 || npm install -g opencode 2>&1
            ;;
        claude)
            npm install -g @anthropic-ai/claude-code 2>&1
            ;;
        shell)
            log "Shell does not require updates."
            ;;
    esac
    log "Update complete."
    echo "UPDATED"
}

action_start() {
    # Ensure project directory exists
    mkdir -p "$PROJECT_PATH"
    
    # Check if session already exists
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        log "Session '$SESSION' already exists. Ready to attach."
        echo "READY"
        exit 0
    fi
    
    # Get the command to run
    CMD=$(get_agent_command)
    
    # --- GAP 4 FIX: Keep-Alive Wrapper ---
    # Wrap the agent in a loop so the window stays open on crash/exit.
    # This allows the user to see error messages before the window vanishes.
    SAFE_CMD="while true; do
        clear
        echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
        echo '  VibeRemote Agent: $AGENT'
        echo '  Project: $PROJECT_PATH'
        echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
        echo ''
        $CMD
        EXIT_CODE=\$?
        echo ''
        echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
        echo \"  Agent exited with code: \$EXIT_CODE\"
        echo '  Press ENTER to restart, or Ctrl-C to stop.'
        echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
        read
    done"
    
    # Create the tmux session
    tmux new-session -d -s "$SESSION" -c "$PROJECT_PATH"
    
    # Send the safe command to the session
    tmux send-keys -t "$SESSION" "$SAFE_CMD" C-m
    
    log "Session '$SESSION' created and running."
    echo "CREATED"
}

action_restart() {
    log "Restarting session '$SESSION'..."
    action_stop
    sleep 1
    action_start
}

# ============================================================================
# Main Dispatcher
# ============================================================================
case "$ACTION" in
    start)
        action_start
        ;;
    stop)
        action_stop
        ;;
    restart)
        action_restart
        ;;
    update)
        action_update
        ;;
    status)
        action_status
        ;;
    *)
        echo "Error: Unknown action: $ACTION" >&2
        echo "Valid actions: start, stop, restart, update, status" >&2
        exit 1
        ;;
esac
