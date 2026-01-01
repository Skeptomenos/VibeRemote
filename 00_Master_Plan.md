# VibeRemote (AgentOS) - Master Plan

## Project Overview
**VibeRemote** (internal codename: AgentOS) is a specialized "Headless Development" ecosystem. It decouples the **Intelligence/Compute** layer (hosted on a Mac mini) from the **Control/Interface** layer (a native iOS application).

This system allows a user to manage, monitor, and interact with persistent AI Agent sessions (running OpenCode, Claude Code, or Gemini CLI) from a mobile device, without sacrificing the power of a full desktop environment.

## Design Thinking Documentation
The project planning follows the Design Thinking methodology. Please refer to the following documents for comprehensive details:

### [01. Empathize & Define](./01_Empathize_Define.md)
*   **User Persona**: The Hybrid Architect.
*   **Problem Statement**: Managing TUI-based agents on mobile is painful due to input limitations and session volatility.
*   **User Stories**: specific scenarios like "The Commuter Check-in" and "The Unblocker".
*   **Core Design Principles**: Visual metaphors and interaction models.

### [02. Ideate & Architecture](./02_Ideate_Architecture.md)
*   **System Architecture**: The split between Server (Mac mini) and Client (iOS).
*   **Tech Stack**: Swift, SwiftTerm, SSH, Tmux, Ollama.
*   **Connectivity**: Atomic SSH commands and Tailscale mesh networking.
*   **Data Flow**: How keystrokes and data move between devices.

### [03. Prototype & Implementation](./03_Prototype_Implementation.md)
*   **Server Setup**: Directory structures and the `launch-agent.sh` script.
*   **Client Development**: Swift Data Models, SSH Controller logic, and UI Wireframes.
*   **Phased Roadmap**: Step-by-step execution plan from "Server Prep" to "Gold Master".

---

## Executive Summary of Technical Strategy

1.  **Persistence is Server-Side**: The iOS app is ephemeral. All state lives in `tmux` on the Mac mini.
2.  **Native over Web**: We use native Swift and SSH (via `SwiftTerm`) instead of WebSockets/Node.js for superior performance, keyboard handling, and background management.
3.  **Strict Structure**: The system relies on a rigid directory structure (`~/AgentOS`) to simplify the client logic.

## Environment Requirements

*   **Host**: Mac mini M1 (or later) running macOS Sonoma/Sequoia.
*   **Client**: iPhone/iPad running iOS 17+.
*   **Network**: Tailscale active on both devices.
*   **Tools**: `tmux`, `zsh`, `ollama`, `opencode`, `claude`.
