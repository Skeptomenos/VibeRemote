# Testing & Validation Strategy

## 1. Unit Testing (Client Logic)
Since the app relies heavily on state, we must test the data models and connection logic.
*   **Test A**: Creating a `ProjectSession` correctly generates the `tmux` session name (sanitization of spaces/special characters).
*   **Test B**: Updating a project's path in the UI updates the persisted `SwiftData` record.

## 2. Integration Testing (Connectivity)
*   **Scenario 1: The "Cold Start"**
    *   Ensure `tmux` session does *not* exist on Mac.
    *   Connect from App.
    *   **Pass Criteria**: `tmux` session created, Agent starts, App displays prompt.
*   **Scenario 2: The "Reconnect"**
    *   Close App.
    *   Reopen App.
    *   **Pass Criteria**: App attaches to *existing* session. Previous scrollback history is visible (provided by tmux/agent).
*   **Scenario 3: The "Double Agent"**
    *   Open App on iPad.
    *   Open App on iPhone.
    *   Connect to same project.
    *   **Pass Criteria**: Both devices show the same screen (Mirrored). Typing on one updates the other instantly. (Tmux feature).

## 3. UX Validation (The "Thumb Test")
*   **Typing**: Can I exit a `nano` or `vim` editor using only the on-screen toolbar? (Test `ESC`, `:q!`, `Enter`).
*   **Confirmation**: Can I answer a "Yes/No" prompt from the Agent easily?
*   **Scrolling**: Does scrolling up to read history feel native, or does it trigger accidental clicks?

## 4. Network Resilience
*   **Test**: Connect via Wi-Fi. Switch to Cellular (4G/5G).
*   **Expected**: SSH connection will drop.
*   **Requirement**: App must detect drop, show "Reconnecting..." overlay, and auto-reconnect via Tailscale (which handles IP roaming).
