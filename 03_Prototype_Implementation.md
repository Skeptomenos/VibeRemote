# Phase 3: Prototype & Implementation

## 1. Server-Side Implementation (Phase 1)

### A. The Control Script (`launch-agent.sh`)
This script must be placed at `~/AgentOS/launch-agent.sh` on the Mac mini.

```bash
#!/bin/bash
# Usage: ./launch-agent.sh [SESSION_NAME] [PROJECT_PATH] [AGENT_TYPE] [ACTION]

SESSION="$1"
PATH="$2"
AGENT="$3" # "opencode" or "claude"
ACTION="$4" # "start", "restart", "update"

# Ensure Directory Exists
mkdir -p "$PATH"

# Logic: Update
if [ "$ACTION" == "update" ]; then
    echo "Updating Agent..."
    if [ "$AGENT" == "opencode" ]; then
        pip install --upgrade opencode
    elif [ "$AGENT" == "claude" ]; then
        npm install -g @anthropic-ai/claude-code
    fi
    exit 0
fi

# Logic: Restart
if [ "$ACTION" == "restart" ]; then
    tmux kill-session -t "$SESSION" 2>/dev/null
fi

# Logic: Start/Attach
if tmux has-session -t "$SESSION" 2>/dev/null; then
    # Session exists. The App will attach via SSH immediately after this script returns.
    # We essentially do nothing here, or we can echo status.
    echo "READY"
else
    # Create new detached session
    tmux new-session -d -s "$SESSION" -c "$PATH"
    
    # Send the start command
    if [ "$AGENT" == "opencode" ]; then
        tmux send-keys -t "$SESSION" "opencode" C-m
    elif [ "$AGENT" == "claude" ]; then
        tmux send-keys -t "$SESSION" "claude" C-m
    fi
    echo "CREATED"
fi
```

## 2. Client-Side Implementation (Phase 2)

### A. Swift Data Model
```swift
import SwiftData

@Model
class ProjectSession {
    var id: UUID
    var name: String
    var path: String
    var agent: String // "opencode" | "claude"
    var hostParams: HostConnection // Relationship to Host Config
    
    init(name: String, path: String, agent: String) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.agent = agent
    }
}
```

### B. The Connection Controller
The core function that bridges the UI to the Server.

```swift
func connectToProject(_ project: ProjectSession) {
    // 1. Establish SSH
    let client = SSHClient(host: project.host.ip, ...)
    
    // 2. Prepare Command
    // Note: We chain the launch script AND the attach command
    let cmd = """
    ~/AgentOS/launch-agent.sh '\(project.name)' '\(project.path)' '\(project.agent)' 'start' && \
    tmux attach -t '\(project.name)'
    """
    
    // 3. Handover to Terminal View
    terminalView.startSession(client: client, command: cmd)
}
```

### C. UI Wireframe (SwiftUI)

**Main Screen (NavigationSplitView)**
*   **Sidebar**:
    *   List of `ProjectSession` items.
    *   `+` Button to add new project (Wizard Sheet).
*   **Detail View**:
    *   If no selection: "Select a Project".
    *   If selection: `TerminalContainerView`.

**TerminalContainerView**
*   **ZStack**:
    *   Layer 1: `SwiftTermView` (The live terminal).
    *   Layer 2: `LoadingSpinner` (Visible while connecting).
    *   Layer 3: `ReconnectOverlay` (Visible if SSH drops).
*   **Toolbar (InputAccessoryView)**:
    *   [ESC] [TAB] [UP] [DOWN] [CTRL-C] [Enter]

## 3. Implementation Roadmap

### Step 1: "The Ping"
*   Set up Mac mini with Tailscale.
*   Create `~/AgentOS` folder.
*   Verify you can SSH from iPad (using Termius app as a test) and run `tmux`.

### Step 2: "The Skeleton"
*   Create iOS Xcode Project.
*   Add `SwiftTerm` package.
*   Hardcode connection details.
*   Get a raw terminal window rendering on the iPad.

### Step 3: "The Brain"
*   Implement `launch-agent.sh` on Mac.
*   Implement `SwiftData` models on iOS.
*   Connect the two: Tap a list item -> Run specific script -> Attach.

### Step 4: "The Polish"
*   Add the Custom Keyboard Toolbar.
*   Implement "Snapshot Caching" for offline viewing.
*   Add "New Project" Wizard.
