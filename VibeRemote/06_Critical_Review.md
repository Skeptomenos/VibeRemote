# Critical Review: VibeRemote Project Plan

## Executive Summary
The architectural foundation (Native iOS + SSH + Tmux) is sound and follows industry best practices for robust remote administration. The "VibeCode as a Service" vision is clear.

However, the implementation plan currently glosses over **four critical "last mile" challenges** that often doom mobile terminal projects. The plan is **NOT** yet ready for coding without addressing these specific risks.

---

## 1. The "First Connect" Friction (Severity: High)
**The Gap**: The plan assumes the iOS app "has the key".
*   **Critique**: How does the private key get from your Mac mini to your iPhone?
    *   Pasting a private key into a text field is a massive security risk and UX nightmare.
    *   AirDrop is reliable but file handling in iOS requires specific entitlements (Document Browser).
*   **Missing Component**: A defined **"Key Import Workflow"**.
    *   *Recommendation*: Implement a "Generate Key Pair" feature on the iPhone itself. Then, the user only has to copy the **Public Key** (safe to share) from the phone to the Mac's `~/.ssh/authorized_keys`. This is much safer and easier than moving private keys around.

## 2. The "Headless Path" Trap (Severity: Critical)
**The Gap**: The `launch-agent.sh` script assumes `opencode` and `tmux` are available.
*   **Critique**: When an app executes a command via SSH (non-interactive shell), it **does NOT** load `~/.zshrc` or `~/.bash_profile` by default on macOS.
    *   **Result**: The app will fail with `command not found: node` or `command not found: tmux`.
*   **Missing Component**: Explicit Environment Loading.
    *   *Mitigation*: The `launch-agent.sh` script must explicitly source the user's profile (`source ~/.zshrc`) OR use absolute paths for binaries (`/opt/homebrew/bin/tmux`).

## 3. The TUI Resize Chain (Severity: Medium)
**The Gap**: Input handling mentions "Sliding up".
*   **Critique**: When the view slides up, the visible viewport gets smaller. Does the terminal *actually* resize (rows/cols)?
    *   If **Yes**: `tmux` needs to receive a window resize signal. If the agent (Claude) doesn't handle resize gracefully, the UI breaks.
    *   If **No** (Overlay): The keyboard covers the bottom half of the terminal. In TUI apps, the "action" (input prompt) is almost *always* at the bottom. The keyboard will cover the exact thing the user needs to see.
*   **Missing Component**: **"Keyboard Avoidance Strategy"**.
    *   *Recommendation*: We must resize the PTY. `SwiftTerm` handles this locally, but we must verify `Citadel` (SSH) propagates the `SIGWINCH` signal to the server correctly.

## 4. Error Visibility (Severity: Medium)
**The Gap**: The `launch-agent.sh` logic is "Fire and Forget".
*   **Critique**: If `opencode` crashes on startup (e.g., API key missing), the `tmux` session might close immediately. The user will see a "Connected" flash and then "Disconnected".
*   **Missing Component**: **"Keep-Alive Wrapper"**.
    *   *Mitigation*: The `tmux` command should wrap the agent in a shell loop: `while true; do opencode; sleep 1; done`. This ensures the window stays open so the user can read the error message.

---

## Action Plan to Remediate
Before writing Swift code, we must refine the **Server-Side Script** and the **Onboarding UX**.

1.  **Refine `launch-agent.sh`**: Add absolute paths and keep-alive logic.
2.  **Redesign Onboarding**: Switch to "Generate Key on Device" -> "Add to Host" flow.
3.  **Update `spec.md`**: Define the keyboard avoidance behavior explicitly (Resize vs Overlay).

**Verdict**: Plan is **85% complete**. The remaining 15% (Environmental & Input edge cases) determines if the app feels "Premium" or "Broken".
