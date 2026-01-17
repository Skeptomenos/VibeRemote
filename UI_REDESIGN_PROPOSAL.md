# VibeRemote UI Redesign Proposal

**Version**: 1.1  
**Date**: January 4, 2026  
**Status**: Approved - Ready for Implementation

---

## 1. Executive Summary

Transform VibeRemote from a sidebar-first navigation pattern to a **chat-first experience** inspired by ChatGPT iOS, with a swipe-to-reveal drawer for session management. The redesign prioritizes speed and efficiency for builders who want to "get in, do something, get out."

### Key Changes

| Current | Proposed |
|---------|----------|
| NavigationSplitView (sidebar-first) | Chat-first with push drawer |
| Single session type | Temporary, Saved, and Favorite sessions |
| Back button navigation | Hamburger menu + edge swipe |
| Flat session list | Date-grouped with search |
| Settings in toolbar | Minimal gear icon, bottom-left |

---

## 2. Design Philosophy

### Core Principles

1. **Speed First** - Builders want to get in quickly. Every interaction should feel snappy (150ms animations).

2. **Chat is the Product** - The conversation is front and center. Chrome is minimal.

3. **Progressive Complexity** - Simple by default, powerful when needed. Temporary sessions for quick tasks, saved sessions for ongoing work.

4. **OpenCode Native** - Use OpenCode's official color palette for brand consistency.

---

## 3. Color Palette (OpenCode Theme)

Based on OpenCode's official theme from `opencode.json`:

### Background Hierarchy

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#0A0A0A` | App background, chat canvas |
| `backgroundPanel` | `#141414` | Sidebar, cards |
| `backgroundElement` | `#1E1E1E` | Buttons, inputs, code blocks |
| `backgroundElevated` | `#282828` | Modals, popovers, hover states |

### Text Hierarchy

| Token | Hex | Usage |
|-------|-----|-------|
| `text` | `#EEEEEE` | Primary text, headings |
| `textMuted` | `#808080` | Secondary text, labels |
| `textSubtle` | `#606060` | Tertiary text, timestamps |

### Accent Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#FAB283` | Primary accent (warm orange/peach) - **Favorite sessions** |
| `secondary` | `#5C9CF5` | Secondary accent (blue) - Links, interactive |
| `accent` | `#9D7CD8` | Tertiary accent (purple) - Thinking indicator |

### Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `success` | `#7FD88F` | Connected, success states |
| `error` | `#E06C75` | Errors, destructive actions |
| `warning` | `#F5A742` | Warnings, connecting state |
| `info` | `#56B6C2` | Info, tool calls |

### Border Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `border` | `#484848` | Standard borders |
| `borderActive` | `#606060` | Focused/active borders |
| `borderSubtle` | `#3C3C3C` | Subtle dividers |

---

## 4. Navigation Architecture

### 4.1 iPhone Behavior

```
┌─────────────────────────────────────────────────────────────┐
│                    CHAT VIEW (Default)                       │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ ☰  Session Name                 Model ▼  ● ● ●          ││
│  ├─────────────────────────────────────────────────────────┤│
│  │                                                          ││
│  │              What can I help with?                       ││
│  │                                                          ││
│  │  ┌─────────────────────────────────────────────────┐    ││
│  │  │ Message...                                  [↑] │    ││
│  │  └─────────────────────────────────────────────────┘    ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘

                    ← EDGE SWIPE RIGHT →

┌─────────────────────────────────────────────────────────────┐
│  SIDEBAR (280pt)        │  CHAT (Pushed, Visible)           │
│  ┌───────────────────┐  │  ┌─────────────────────────────┐  │
│  │ VibeRemote   [+]  │  │  │ ☰  Session...               │  │
│  ├───────────────────┤  │  ├─────────────────────────────┤  │
│  │ 🔍 Search...      │  │  │                             │  │
│  ├───────────────────┤  │  │   What can I help with?     │  │
│  │ PINNED            │  │  │                             │  │
│  │ Main Project ~/mp │  │  │                             │  │
│  ├───────────────────┤  │  │                             │  │
│  │ TODAY             │  │  │                             │  │
│  │ Quick test  ~/qt  │  │  │                             │  │
│  │                   │  │  │                             │  │
│  │ YESTERDAY         │  │  │                             │  │
│  │ Auth fix    ~/af  │  │  │                             │  │
│  ├───────────────────┤  │  │                             │  │
│  │ ⚙️                │  │  │                             │  │
│  └───────────────────┘  │  └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Behavior:**
- Edge swipe from left (iOS native gesture)
- Sidebar pushes chat to the right (push drawer)
- Chat remains partially visible
- Tap on chat or swipe left to close sidebar
- Hamburger icon (☰) also toggles sidebar

### 4.2 iPad Behavior

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  SIDEBAR (320pt)              │  CHAT (Squeezed, Full Height)               │
│  ┌─────────────────────────┐  │  ┌───────────────────────────────────────┐  │
│  │ VibeRemote         [+]  │  │  │ ☰  Session Name        Model ▼  ●●●  │  │
│  ├─────────────────────────┤  │  ├───────────────────────────────────────┤  │
│  │ 🔍 Search sessions...   │  │  │                                       │  │
│  ├─────────────────────────┤  │  │                                       │  │
│  │ PINNED                  │  │  │         What can I help with?         │  │
│  │ ★ Main Project   ~/proj │  │  │                                       │  │
│  ├─────────────────────────┤  │  │                                       │  │
│  │ TODAY                   │  │  │                                       │  │
│  │ Quick test       ~/test │  │  │                                       │  │
│  │ API debug        ~/api  │  │  │                                       │  │
│  │                         │  │  │                                       │  │
│  │ YESTERDAY               │  │  │                                       │  │
│  │ Auth refactor    ~/auth │  │  │                                       │  │
│  │                         │  │  │  ┌─────────────────────────────────┐  │  │
│  │                         │  │  │  │ Message...                  [↑] │  │  │
│  ├─────────────────────────┤  │  │  └─────────────────────────────────┘  │  │
│  │ ⚙️                      │  │  │                                       │  │
│  └─────────────────────────┘  │  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Behavior:**
- Edge swipe from left OR hamburger tap
- Sidebar slides in, chat **squeezes** (doesn't get pushed off-screen)
- Chat content reflows to fit narrower width
- Sidebar can be "pinned" open (persists across sessions)
- Swipe left or tap hamburger to close
- Full-screen mode available (sidebar hidden)

---

## 5. Session Types & Launch Logic

### 5.1 Session Types

| Type | Persistence | Indicator | Behavior |
|------|-------------|-----------|----------|
| **Temporary** | Ephemeral | Banner at top | Auto-deleted on close, can be saved |
| **Saved** | Persistent | None (default) | Normal session, persists |
| **Favorite** | Persistent + Pinned | Accent color title | Pinned to top, default launch |

### 5.2 App Launch Logic

```
┌─────────────────────────────────────────┐
│            App Launch                    │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│   Has Favorite Session?                  │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴─────────┐
        │ YES               │ NO
        ▼                   ▼
┌───────────────┐   ┌─────────────────────┐
│ Open Favorite │   │ User Preference?     │
└───────────────┘   └─────────┬───────────┘
                              │
                    ┌─────────┴─────────┐
                    │ "Last Session"    │ "New Session"
                    ▼                   ▼
            ┌───────────────┐   ┌───────────────┐
            │ Open Most     │   │ Create New    │
            │ Recent        │   │ Temporary     │
            └───────────────┘   └───────────────┘
```

### 5.3 Temporary Session Banner

```
┌─────────────────────────────────────────────────────────────┐
│  ⏱ Temporary Session                              [Save]    │
└─────────────────────────────────────────────────────────────┘
│                                                              │
│  (Chat content below)                                        │
```

- Subtle banner at top of chat (below header)
- Background: `backgroundElement` (#1E1E1E)
- Text: `textMuted` (#808080)
- "Save" button: `primary` accent (#FAB283)
- Tapping banner or "Save" opens save dialog
- Banner dismisses after saving

---

## 6. Sidebar Design

### 6.1 Structure

```
┌─────────────────────────────────────┐
│                                     │  ← 12pt top padding
│  VibeRemote                   [+]   │  ← Header
│                                     │  ← 8pt
├─────────────────────────────────────┤
│  🔍 Search sessions...              │  ← Search bar
├─────────────────────────────────────┤
│                                     │  ← 16pt
│  PINNED                             │  ← Section header (if favorites exist)
│  ┌─────────────────────────────────┐│
│  │ Main Project          ~/proj    ││  ← Favorite row (accent color)
│  └─────────────────────────────────┘│
│                                     │  ← 16pt
│  TODAY                              │  ← Date group header
│  ┌─────────────────────────────────┐│
│  │ Quick test            ~/test    ││  ← Session row
│  │ API debug             ~/api     ││
│  └─────────────────────────────────┘│
│                                     │
│  YESTERDAY                          │
│  ┌─────────────────────────────────┐│
│  │ Auth refactor         ~/auth    ││
│  └─────────────────────────────────┘│
│                                     │
│  (Scrollable area)                  │
│                                     │
├─────────────────────────────────────┤
│  ⚙️                                 │  ← Settings icon, bottom-left
│                                     │  ← 12pt bottom padding (safe area)
└─────────────────────────────────────┘
```

### 6.2 Component Specifications

#### Header

```
┌─────────────────────────────────────┐
│  VibeRemote                   [+]   │
└─────────────────────────────────────┘
```

- Title: `text` (#EEEEEE), 22pt Bold (Title2)
- "+" button: 28x28pt, `textMuted` (#808080), `plus` SF Symbol
- Padding: 16pt horizontal, 12pt vertical

#### Search Bar

```
┌─────────────────────────────────────┐
│  🔍 Search sessions...              │
└─────────────────────────────────────┘
```

- Background: `backgroundElement` (#1E1E1E)
- Corner radius: 8pt
- Height: 36pt
- Icon: `magnifyingglass`, `textMuted`
- Placeholder: `textSubtle` (#606060), 15pt Regular
- Padding: 16pt horizontal

#### Section Headers

```
  PINNED
  TODAY
  YESTERDAY
  PREVIOUS 7 DAYS
  OLDER
```

- Text: `textSubtle` (#606060), 11pt Bold, uppercase
- Letter spacing: 0.5pt
- Padding: 16pt left, 8pt top/bottom

#### Session Row

```
┌─────────────────────────────────────┐
│  Session Name              ~/path   │
└─────────────────────────────────────┘
```

- Height: 44pt (touch target)
- Name (left): `text` (#EEEEEE), 15pt Regular
- Path (right): `textMuted` (#808080), 13pt Regular
- Padding: 16pt horizontal, 12pt vertical
- Selected state: `backgroundElement` (#1E1E1E) background
- Favorite row: Name in `primary` (#FAB283)

#### Settings Icon

```
┌─────────────────────────────────────┐
│  ⚙️                                 │
└─────────────────────────────────────┘
```

- Icon: `gearshape`, 20pt, `textMuted` (#808080)
- Position: Bottom-left, 16pt from edges
- Touch target: 44x44pt
- No label (icon only)

---

## 7. Chat Header Redesign

### Current vs. Proposed

**Current:**
```
┌─────────────────────────────────────────────────────────────┐
│  [<]  Session Name        Select Model ▼    [●●●]    ●      │
│       ~/path                                                 │
└─────────────────────────────────────────────────────────────┘
```

**Proposed:**
```
┌─────────────────────────────────────────────────────────────┐
│  [☰]  Session Name              Model ▼    [●●●]    ●       │
└─────────────────────────────────────────────────────────────┘
```

### Specifications

- Hamburger icon (☰): `line.3.horizontal`, 20pt, `textMuted`
- Session name: `text`, 17pt Semibold
- Path removed from header (visible in sidebar)
- Model picker: `text`, 12pt Regular, with chevron
- Menu button: `ellipsis.circle`, 18pt, `textMuted`
- Connection indicator: 8pt circle, semantic color

---

## 8. Animation Specifications

### Timing (Snappy)

| Animation | Duration | Curve | Usage |
|-----------|----------|-------|-------|
| `instant` | 100ms | easeOut | Button taps, toggles |
| `quick` | 150ms | easeOut | Micro-interactions |
| `standard` | 200ms | easeInOut | Sidebar open/close |
| `spring` | ~250ms | spring(0.5, 0.8) | Bouncy elements |

### Sidebar Animation

```swift
// iPhone - Push drawer
withAnimation(.easeInOut(duration: 0.2)) {
    sidebarOffset = isOpen ? 0 : -sidebarWidth
    chatOffset = isOpen ? sidebarWidth : 0
}

// iPad - Squeeze
withAnimation(.easeInOut(duration: 0.2)) {
    sidebarOffset = isOpen ? 0 : -sidebarWidth
    chatWidth = isOpen ? screenWidth - sidebarWidth : screenWidth
}
```

### Gesture Handling

```swift
// Edge swipe detection
.gesture(
    DragGesture()
        .onChanged { value in
            // Only respond to edge swipes (start within 20pt of left edge)
            guard value.startLocation.x < 20 else { return }
            sidebarOffset = min(0, -sidebarWidth + value.translation.width)
        }
        .onEnded { value in
            // Snap open if dragged > 50% or velocity > threshold
            let shouldOpen = value.translation.width > sidebarWidth / 2 ||
                             value.velocity.width > 500
            withAnimation(.easeOut(duration: 0.15)) {
                isOpen = shouldOpen
            }
        }
)
```

---

## 9. Data Model Changes

### 9.1 AgentSession Updates

```swift
@Model
class AgentSession {
    // Existing fields...
    var id: UUID
    var name: String
    var projectPath: String
    var agentType: AgentType
    var connectionMode: ConnectionMode
    var lastActive: Date
    
    // NEW: Session type
    var sessionType: SessionType = .saved
    
    // NEW: Favorite flag (for pinning to top)
    var isFavorite: Bool = false
    
    // NEW: Master favorite (opens on launch)
    var isMasterFavorite: Bool = false
    
    // NEW: Created date (for grouping)
    var createdAt: Date = Date()
    
    // Computed: Display in Pinned section
    var isPinned: Bool { isFavorite || isMasterFavorite }
}

enum SessionType: String, Codable {
    case temporary  // Auto-deleted when AI completes and app closes
    case saved      // Persistent (default)
}
```

### 9.2 User Preferences

```swift
@Model
class UserPreferences {
    var id: UUID = UUID()
    
    // Launch behavior
    var launchBehavior: LaunchBehavior = .lastSession
    
    // Sidebar pinned state (iPad)
    var sidebarPinned: Bool = false
    
    // Onboarding completed
    var hasCompletedOnboarding: Bool = false
}

enum LaunchBehavior: String, Codable {
    case masterFavorite  // Open master favorite (if exists)
    case lastSession     // Open most recent
    case newTemporary    // Create new temporary session
}
```

### 9.3 Session Cleanup Logic

```swift
// In VibeRemoteApp.swift or a dedicated SessionCleanupManager

func cleanupTemporarySessions() {
    let context = modelContainer.mainContext
    let descriptor = FetchDescriptor<AgentSession>(
        predicate: #Predicate { $0.sessionType == .temporary }
    )
    
    guard let temporarySessions = try? context.fetch(descriptor) else { return }
    
    for session in temporarySessions {
        // Only delete if AI is not actively working
        // This check happens on app launch (safer than background)
        if !isSessionActivelyStreaming(session) {
            context.delete(session)
        }
    }
    
    try? context.save()
}
```

---

## 10. Implementation Phases

### Phase 1: Navigation Restructure (High Priority)

1. **Create `SidebarDrawerView`** - Custom drawer component with push behavior
2. **Create `MainNavigationView`** - Root view with drawer logic
3. **Modify `ContentView`** - Replace NavigationSplitView
4. **Add edge swipe gesture** - iOS native feel (left edge only)
5. **Implement hamburger toggle** - In chat header
6. **iPad squeeze behavior** - Chat compresses when sidebar opens

**Estimated effort**: 2-3 days

### Phase 2: Session Types & Data Model (High Priority)

1. **Update `AgentSession` model** - Add sessionType, isFavorite, isMasterFavorite, createdAt
2. **Create `UserPreferences` model** - Launch behavior settings
3. **Create migration** - SwiftData schema migration
4. **Implement temporary session banner** - With save action
5. **Implement temporary session cleanup** - On app background (if AI complete)
6. **Implement launch logic** - Master Favorite → Last Session → New Temporary

**Estimated effort**: 2 days

### Phase 3: Sidebar Content (Medium Priority)

1. **Redesign session rows** - Name left, path right, compact
2. **Add date grouping** - Today, Yesterday, Previous 7 Days, Older
3. **Implement Pinned section** - Favorites at top with accent color
4. **Add swipe actions** - Edit, Favorite, Delete
5. **Add settings icon** - Bottom-left, gear only
6. **Implement search (MVP)** - Filter by session name only

**Estimated effort**: 2 days

### Phase 4: Onboarding & Empty State (Medium Priority)

1. **Create `OnboardingWizardView`** - First-launch experience
2. **Gateway setup step** - URL + API key input
3. **Connection test step** - Verify connectivity
4. **First session step** - Create initial session
5. **Empty state view** - "Start Building" CTA for new users

**Estimated effort**: 1-2 days

### Phase 5: iPad & Polish (Lower Priority)

1. **Sidebar pinning** - Persists across sessions
2. **Optimize for landscape** - Wider sidebar, better proportions
3. **Keyboard shortcuts** - Cmd+\ to toggle sidebar
4. **Master Favorite UI** - Long-press to set, filled star indicator
5. **Animation polish** - Ensure all transitions are snappy

**Estimated effort**: 1-2 days

### Phase 6: Future Enhancements (Backlog)

1. **Full-text search** - Search message content (requires indexing)
2. **Path search** - Include project paths in search
3. **Session archiving** - Archive instead of delete
4. **iCloud sync** - Sync sessions across devices

---

## 11. File Changes Summary

### New Files

| File | Purpose |
|------|---------|
| `Views/Navigation/SidebarDrawerView.swift` | Custom drawer component with push/squeeze |
| `Views/Navigation/MainNavigationView.swift` | Root navigation container |
| `Views/Sidebar/SidebarContentView.swift` | Sidebar content (header, search, list, settings) |
| `Views/Sidebar/SidebarSessionRowView.swift` | Redesigned session row (name left, path right) |
| `Views/Sidebar/DateGroupedSessionList.swift` | Date-grouped list with Pinned section |
| `Views/Sidebar/SidebarSearchBar.swift` | Search bar component |
| `Views/Chat/TemporarySessionBanner.swift` | Ephemeral session banner with save action |
| `Views/Chat/ChatHeaderView.swift` | Extracted header with hamburger menu |
| `Views/Onboarding/OnboardingWizardView.swift` | First-launch wizard |
| `Views/Onboarding/GatewaySetupStep.swift` | Gateway URL + API key setup |
| `Views/Onboarding/ConnectionTestStep.swift` | Connectivity verification |
| `Views/Onboarding/FirstSessionStep.swift` | Create first session |
| `Views/Onboarding/WelcomeEmptyState.swift` | "Start Building" CTA |
| `Models/UserPreferences.swift` | User preferences model |
| `Services/SessionCleanupManager.swift` | Temporary session cleanup logic |

### Modified Files

| File | Changes |
|------|---------|
| `ContentView.swift` | Replace NavigationSplitView with MainNavigationView |
| `Models/AgentSession.swift` | Add sessionType, isFavorite, isMasterFavorite, createdAt |
| `Views/Chat/ChatView.swift` | Update header (hamburger, remove path) |
| `Theme/OpenCodeTheme.swift` | Ensure all tokens are defined |
| `VibeRemoteApp.swift` | Add UserPreferences to schema, add cleanup on launch |

### Deleted Files

| File | Reason |
|------|--------|
| `Views/SessionSidebarView.swift` | Replaced by SidebarContentView |

---

## 12. Success Criteria

The redesign is complete when:

### Navigation
- [ ] App launches directly to chat (Master Favorite → Last Session → New Temporary)
- [ ] Edge swipe (left edge) reveals sidebar on iPhone
- [ ] Sidebar pushes chat to the right on iPhone
- [ ] Sidebar squeezes/compresses chat on iPad
- [ ] Hamburger icon (☰) toggles sidebar
- [ ] iPad sidebar can be pinned open
- [ ] All animations feel snappy (≤200ms)

### Session Management
- [ ] Temporary sessions show banner with "Save" option
- [ ] Temporary sessions auto-delete when AI completes and app closes
- [ ] Multiple sessions can be favorited (pinned to top)
- [ ] One Master Favorite can be set (opens on launch)
- [ ] Favorite sessions display in accent color (#FAB283)
- [ ] Sessions are grouped by date (Today, Yesterday, Previous 7 Days, Older)

### Sidebar
- [ ] Session rows show name (left) and path (right)
- [ ] Swipe actions: Edit (blue), Favorite (orange), Delete (red)
- [ ] Search bar filters sessions by name
- [ ] Settings icon is gear-only, bottom-left
- [ ] Pinned section appears at top when favorites exist

### Onboarding
- [ ] First launch shows "Start Building" welcome screen
- [ ] Wizard guides through Gateway setup
- [ ] Connection test verifies connectivity
- [ ] First session creation is guided
- [ ] Returning users skip onboarding

---

## 13. Resolved Design Decisions

### 13.1 Temporary Session Deletion

**Decision**: Delete after successful AI response when app is closed.

**Logic**:
```
┌─────────────────────────────────────────┐
│  App Goes to Background / Closes        │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│  Is Session Temporary?                   │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴─────────┐
        │ NO                │ YES
        ▼                   ▼
┌───────────────┐   ┌─────────────────────┐
│ Keep Session  │   │ Is AI Still Working? │
└───────────────┘   └─────────┬───────────┘
                              │
                    ┌─────────┴─────────┐
                    │ YES (streaming)   │ NO (idle/complete)
                    ▼                   ▼
            ┌───────────────┐   ┌───────────────┐
            │ Keep Session  │   │ Delete Session│
            │ (wait for     │   │ (cleanup)     │
            │  completion)  │   │               │
            └───────────────┘   └───────────────┘
```

**Implementation Notes**:
- Check `isLoading` / streaming state before deletion
- If AI is mid-response, wait for completion
- Use `scenePhase` to detect app backgrounding
- Cleanup happens on next app launch (safer than immediate)

### 13.2 Favorites System

**Decision**: Multiple favorites allowed, one "Master Favorite" for default launch.

**Behavior**:
- Users can favorite multiple sessions (all pinned to top)
- One session can be marked as "Master Favorite" (opens on launch)
- Master Favorite indicated with filled star (★), others with outline (☆)
- Long-press on favorite to set as Master

**Data Model**:
```swift
@Model
class AgentSession {
    var isFavorite: Bool = false      // Pinned to top
    var isMasterFavorite: Bool = false // Opens on launch
}
```

**Constraint**: Only one session can be `isMasterFavorite = true` at a time.

### 13.3 Search Implementation

**Decision**: Defer to later phase. Full-text search across names, paths, and message content.

**Phase 1** (MVP): Search by session name only
**Phase 2** (Later): Add path search
**Phase 3** (Future): Full message content search (requires indexing)

### 13.4 Empty State / First Launch

**Decision**: Onboarding wizard with "Start Building" CTA.

**Flow**:
```
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│                      🚀                                      │
│                                                              │
│              Welcome to VibeRemote                           │
│                                                              │
│     Control your AI coding agents from anywhere.             │
│                                                              │
│         ┌─────────────────────────────┐                     │
│         │      Start Building         │                     │
│         └─────────────────────────────┘                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Wizard Steps**:
1. **Gateway Setup** - Enter gateway URL, API key
2. **Connection Test** - Verify connectivity
3. **First Session** - Create first session (name, project path)
4. **Ready** - Launch into chat

**Returning Users**: Skip wizard, show normal UI.

### 13.5 Swipe Actions on Session Rows

**Decision**: Three actions in order of priority.

```
┌─────────────────────────────────────────────────────────────┐
│  Session Name              ~/path   │ Edit │ ★ │ Delete │  │
└─────────────────────────────────────────────────────────────┘
                                      ← SWIPE LEFT
```

| Position | Action | Icon | Color | Behavior |
|----------|--------|------|-------|----------|
| 1 (First) | Edit | `pencil` | Blue (#5C9CF5) | Opens edit sheet |
| 2 (Second) | Favorite | `star` / `star.fill` | Orange (#FAB283) | Toggles favorite |
| 3 (Third) | Delete | `trash` | Red (#E06C75) | Confirms, then deletes |

**SwiftUI Implementation**:
```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) { deleteSession() } label: {
        Label("Delete", systemImage: "trash")
    }
    
    Button { toggleFavorite() } label: {
        Label(session.isFavorite ? "Unfavorite" : "Favorite", 
              systemImage: session.isFavorite ? "star.slash" : "star.fill")
    }
    .tint(Color(hex: 0xFAB283))
    
    Button { editSession() } label: {
        Label("Edit", systemImage: "pencil")
    }
    .tint(Color(hex: 0x5C9CF5))
}
```

---

## 14. Appendix: Visual Reference

### ChatGPT iOS Inspiration Points

- Chat-first experience (no sidebar on launch)
- Edge swipe to reveal sidebar
- Minimal header with model picker
- Date-grouped conversation list
- Settings at bottom of sidebar
- Clean, dark aesthetic

### OpenCode Brand Alignment

- Warm orange/peach accent (#FAB283)
- Near-black backgrounds (#0A0A0A)
- Muted text hierarchy
- Terminal-inspired aesthetic
- Professional, builder-focused

---

*End of Proposal*
