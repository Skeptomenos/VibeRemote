# Phase 2: Ideate & Architecture

## 1. System Architecture
The system is divided into two distinct planes: **The Engine (Server)** and **The Controller (Client)**.

```mermaid
graph TD
    subgraph "Mac mini (The Engine)"
        OS[macOS Host]
        TS_S[Tailscale IP: 100.x.x.x]
        
        subgraph "Session Layer"
            TMUX[Tmux Server]
            S1[Session: Website]
            S2[Session: Backend]
        end
        
        subgraph "Compute Layer"
            OC[OpenCode Agent]
            CL[Claude Code]
            OL[Ollama (Local LLM)]
        end
        
        FS[File System (~/AgentOS)]
    end

    subgraph "iOS Device (The Controller)"
        APP[AgentOS App]
        DB[SwiftData (Projects)]
        TERM[SwiftTerm (Renderer)]
        SSH[Citadel SSH Client]
        TS_C[Tailscale VPN]
    end

    %% Connections
    APP -- "SSH (Port 22)" --> TS_S
    TS_S --> OS
    OS -- "Spawns" --> TMUX
    TMUX -- "Manages" --> S1
    TMUX -- "Manages" --> S2
    S1 -- "Runs" --> OC
    S2 -- "Runs" --> CL
    OC -- "Queries" --> OL
```

## 2. Technical Stack

### Server-Side (Mac mini)
*   **OS**: macOS Sonoma/Sequoia (Headless mode).
*   **Network**: **Tailscale** (Mesh VPN for secure, zero-config access).
*   **Session Manager**: **tmux** (Terminal Multiplexer).
    *   *Why?* It detaches processes from the UI. If the iPhone disconnects, the Agent keeps running.
*   **Agent Runtimes**:
    *   **OpenCode**: Python-based TUI.
    *   **Claude Code**: Node.js-based TUI.
*   **Scripting**: Zsh scripts to handle session lifecycle (start/stop/update).

### Client-Side (iOS)
*   **Language**: **Swift 6** (SwiftUI).
*   **Terminal Engine**: **SwiftTerm** (by Miguel de Icaza).
    *   *Why?* Native Metal rendering, full xterm compliance, high performance.
*   **SSH Library**: **Citadel** or **NMSSH**.
    *   *Why?* Pure Swift implementation, supports key-based auth.
*   **Persistence**: **SwiftData**.
    *   *Why?* Modern, native persistence for Project metadata (Names, Paths, Agent Types).

## 3. The Connectivity Protocol
We do not use a custom API. We use **Atomic SSH Commands**.

### The "Connect" Sequence
When the user taps a project, the App performs this sequence:
1.  **Auth**: Connect via SSH Key.
2.  **Execute**:
    ```bash
    ~/AgentOS/launch-agent.sh "{SessionName}" "{Path}" "{AgentType}" "start"
    ```
3.  **Attach**: The script executes `tmux attach -t {SessionName}`.
4.  **Stream**: The SSH channel becomes a raw PTY stream. `SwiftTerm` takes over rendering.

### The "launch-agent.sh" Logic
This script is the brain of the server side. It handles idempotency:
*   If session exists -> Attach.
*   If session missing -> Create `tmux new-session` -> Send Agent Command -> Attach.
*   If update requested -> Run `npm update` -> Restart session.

## 4. Directory Structure
We enforce this structure to simplify the Client logic:

```text
/Users/{user}/AgentOS/
├── launch-agent.sh       # The master control script
├── Projects/             # Root for all agent workspaces
│   ├── project-alpha/
│   ├── website-v2/
│   └── experimentation/
└── Logs/                 # (Optional) Activity logs
```
