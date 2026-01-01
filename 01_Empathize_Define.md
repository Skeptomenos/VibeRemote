# Phase 1: Empathize & Define

## 1. User Persona: "The Hybrid Architect"
**Role**: Senior AI Engineer / Tech Lead
**Context**: Works with multiple autonomous agents simultaneously. Moves frequently between desktop (deep work) and mobile (monitoring/unblocking).
**Pain Points**:
*   **Anxiety**: "Is the agent stuck on a prompt? Did it crash?"
*   **Friction**: SSH apps on mobile are clunky. Typing `Ctrl-C` or `Esc` is difficult.
*   **Context Switching**: Keeping mental track of 4 different terminal windows is exhausting.

## 2. Problem Statement
> "Standard terminal apps (Termius, Blink) are designed for *sysadmins* to manage servers. They are not designed for *developers* to collaborate with *AI Agents*."

We need an interface that treats an **Agent Session** as a first-class citizen—not just a raw shell, but a persistent workspace with metadata, state, and specialized input controls.

## 3. User Stories

### Story A: "The Commuter Check-in"
*   **Scenario**: User is on a train with spotty signal.
*   **Need**: Open the app and *immediately* see the last 100 lines of the agent's output without waiting for a connection handshake.
*   **Solution**: **Snapshot Caching**. The app saves the terminal state to disk on suspend. On resume, it displays the "Ghost" state (greyed out) instantly while the SSH connection reconnects in the background.

### Story B: "The Unblocker"
*   **Scenario**: The agent pauses and asks: *"Delete 14 files? (y/n)"*.
*   **Need**: User needs to send a confirmation command effortlessly.
*   **Solution**: **Action Toolbar**. A dedicated accessory view above the keyboard with large `YES` (`y`+`Enter`), `NO` (`n`+`Enter`), `ESC`, and `Arrow` keys.

### Story C: "The Strategic Pivot"
*   **Scenario**: User manages 3 projects (Backend, Frontend, Docs).
*   **Need**: Switch context instantly.
*   **Solution**: **Project Sidebar**. A "ChatGPT-style" sidebar listing active agents. Tapping one instantly detaches the current SSH stream and attaches the new `tmux` session, preserving the exact scroll position.

## 4. Core Design Principles

### A. The Visual Metaphor: "The Chat Wrapper"
The app should not look like a raw hacker terminal. It should look like a modern productivity tool.
*   **Container**: Clean, white/dark mode UI for navigation and settings.
*   **Content**: High-fidelity terminal window inside the "Message Area".
*   **Result**: It feels like chatting with the agent, but the "Chat" is the live TUI stream.

### B. Input Handling: "Stable View"
Reflowing text (wrapping lines when keyboard opens) breaks TUI layouts like progress bars and spinners.
*   **Decision**: The terminal viewport remains fixed-width. When the keyboard opens, the viewport slides up/pans.
*   **Key**: The **Input Accessory View** is crucial for TUI navigation (`Tab`, `Ctrl`, `Esc`).

### C. The "Strict Mode" Philosophy
The app is not a general-purpose SSH client. It is an **Agent Controller**.
*   It assumes `tmux` is installed.
*   It assumes a specific folder structure (`~/AgentOS`).
*   It hides the complexity of SSH keys and connection details after initial setup.
