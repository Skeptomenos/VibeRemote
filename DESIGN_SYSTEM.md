# VibeRemote Design System

## Vision

VibeRemote is a **native iOS app for controlling AI coding agents**. The design should feel like a premium Apple application - clean, focused, and delightful to use. We draw inspiration from ChatGPT's conversational interface while embracing Apple's Human Interface Guidelines.

**Core Philosophy:** The interface should disappear. Users should feel like they're having a conversation with an intelligent coding partner, not operating a complex tool.

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Visual Language](#visual-language)
3. [Color System](#color-system)
4. [Typography](#typography)
5. [Layout & Spacing](#layout--spacing)
6. [Component Library](#component-library)
7. [Interaction Patterns](#interaction-patterns)
8. [Animation & Motion](#animation--motion)
9. [Accessibility](#accessibility)
10. [Platform Adaptations](#platform-adaptations)
11. [Reference Designs](#reference-designs)

---

## Design Principles

### 1. Content First, Chrome Last

The conversation is the product. Every pixel of UI chrome (headers, buttons, decorations) must justify its existence. If it doesn't help the user accomplish their goal, remove it.

**Do:**
- Maximize space for message content
- Use subtle dividers instead of heavy borders
- Hide secondary controls until needed

**Don't:**
- Add decorative elements that don't serve a purpose
- Use thick borders or heavy shadows
- Show all options at once

### 2. Conversational, Not Transactional

This is a chat with an AI partner, not a form submission. The interface should feel like a natural dialogue.

**Do:**
- Let messages flow like a document
- Use natural language in UI copy
- Show the AI's "thinking" process transparently

**Don't:**
- Use rigid grid layouts for messages
- Make it feel like filling out forms
- Hide what the AI is doing

### 3. Progressive Disclosure

Show only what's needed at each moment. Advanced features reveal themselves when relevant.

**Do:**
- Start with a clean, minimal interface
- Reveal tool details on tap/expand
- Group related settings logically

**Don't:**
- Overwhelm with options upfront
- Force users through complex setup flows
- Show technical details by default

### 4. Responsive Confidence

The app should feel alive and responsive. Every action should have immediate feedback.

**Do:**
- Acknowledge input instantly (optimistic updates)
- Show streaming text as it arrives
- Animate state changes smoothly

**Don't:**
- Leave users wondering if their tap registered
- Show loading spinners for fast operations
- Use jarring, instant transitions

### 5. Dark Mode Native

Dark mode is the primary design target. Many developers work in dark environments, and the app should feel at home there.

**Do:**
- Design dark mode first, then adapt for light
- Use subtle color variations for depth
- Ensure sufficient contrast for readability

**Don't:**
- Simply invert light mode colors
- Use pure black (#000000) as background
- Neglect light mode entirely

---

## Visual Language

### Overall Aesthetic

**Minimal but Warm:** The interface is clean and uncluttered, but not cold or sterile. Subtle warmth comes from rounded corners, gentle animations, and thoughtful micro-interactions.

**Professional but Approachable:** This is a tool for serious work, but it shouldn't feel intimidating. The design should welcome both experienced developers and newcomers.

**Focused but Flexible:** The primary use case (chat) is optimized, but the app gracefully accommodates secondary features (settings, history, status panels).

### Design DNA

| Attribute | Expression |
|-----------|------------|
| **Shape Language** | Rounded rectangles, soft corners, pill shapes |
| **Depth Model** | Subtle elevation through color, minimal shadows |
| **Density** | Comfortable spacing, not cramped or sparse |
| **Contrast** | High for text, subtle for UI elements |
| **Texture** | Flat with subtle gradients, no skeuomorphism |

### Inspiration Sources

1. **ChatGPT iOS App** - Conversational flow, minimal chrome, centered content
2. **Apple Notes** - Clean typography, document-like feel
3. **Linear** - Professional dark theme, subtle interactions
4. **Raycast** - Command palette, keyboard-first design
5. **GitHub Mobile** - Code display, developer-focused UI

---

## Color System

### Philosophy

Colors serve function, not decoration. The palette is intentionally restrained to keep focus on content. Accent colors are used sparingly to draw attention to interactive elements.

### Dark Mode (Primary)

```
Background Hierarchy:
┌─────────────────────────────────────────────────────────┐
│  Level 0: Base Background                               │
│  #212121 - Deep charcoal, main canvas                   │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Level 1: Surface                                 │  │
│  │  #2F2F2F - Cards, input fields, elevated content │  │
│  │                                                   │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Level 2: Surface Elevated                  │  │  │
│  │  │  #3A3A3A - Modals, popovers, dropdowns     │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | #212121 | Main app background |
| `surface` | #2F2F2F | Cards, input bar, elevated sections |
| `surfaceElevated` | #3A3A3A | Modals, sheets, dropdowns |
| `surfaceHover` | #404040 | Hover states on interactive surfaces |
| `border` | #3A3A3A | Subtle dividers and borders |
| `borderSubtle` | #2A2A2A | Very subtle separators |

### Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `textPrimary` | #ECECEC | Main body text, headings |
| `textSecondary` | #9A9A9A | Supporting text, labels |
| `textTertiary` | #666666 | Disabled text, timestamps |
| `textInverse` | #1A1A1A | Text on light backgrounds |

### Accent Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `accent` | #0A84FF | Primary actions, links, active states |
| `accentSubtle` | #1A3A5C | Subtle accent backgrounds |
| `accentHover` | #409CFF | Hover state for accent elements |

### Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `success` | #34C759 | Completed actions, online status |
| `warning` | #FF9500 | Warnings, pending states |
| `error` | #FF3B30 | Errors, destructive actions |
| `info` | #5AC8FA | Informational messages |

### Code Block Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `codeBackground` | #1E1E1E | Code block background |
| `codeBorder` | #3A3A3A | Code block border |
| `codeText` | #D4D4D4 | Default code text |
| `codeKeyword` | #569CD6 | Keywords (const, function, etc.) |
| `codeString` | #CE9178 | String literals |
| `codeComment` | #6A9955 | Comments |
| `codeNumber` | #B5CEA8 | Numbers |

### Light Mode

Light mode inverts the hierarchy while maintaining the same semantic meaning.

| Token | Dark | Light |
|-------|------|-------|
| `background` | #212121 | #FFFFFF |
| `surface` | #2F2F2F | #F7F7F8 |
| `surfaceElevated` | #3A3A3A | #FFFFFF |
| `textPrimary` | #ECECEC | #1A1A1A |
| `textSecondary` | #9A9A9A | #6B6B6B |
| `accent` | #0A84FF | #007AFF |

---

## Typography

### Font Stack

**Primary:** SF Pro (San Francisco) - Apple's system font
**Monospace:** SF Mono - For code blocks and technical content

Using system fonts ensures:
- Optimal rendering on all Apple devices
- Automatic support for Dynamic Type
- Familiar, native feel

### Type Scale

| Style | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| `largeTitle` | 34pt | Bold | 41pt | Empty state headlines |
| `title` | 28pt | Bold | 34pt | Sheet titles |
| `title2` | 22pt | Bold | 28pt | Section headers |
| `title3` | 20pt | Semibold | 25pt | Card titles |
| `headline` | 17pt | Semibold | 22pt | List headers |
| `body` | 17pt | Regular | 22pt | Message content |
| `callout` | 16pt | Regular | 21pt | Secondary content |
| `subheadline` | 15pt | Regular | 20pt | Supporting text |
| `footnote` | 13pt | Regular | 18pt | Metadata, timestamps |
| `caption` | 12pt | Regular | 16pt | Labels, badges |
| `caption2` | 11pt | Regular | 13pt | Smallest text |

### Message Typography

Messages are the core content. Typography must be optimized for readability.

**User Messages:**
- Font: Body (17pt), Medium weight
- Color: `textPrimary`
- Alignment: Right (but no bubble)

**Assistant Messages:**
- Font: Body (17pt), Regular weight
- Color: `textPrimary`
- Alignment: Left, full width
- Line height: Generous (1.5x) for readability

**Code Blocks:**
- Font: SF Mono, 14pt
- Background: `codeBackground`
- Padding: 12pt
- Border radius: 8pt
- Syntax highlighting with semantic colors

### Dynamic Type Support

All text must scale with the user's accessibility settings. Use SwiftUI's built-in font styles or ensure custom fonts respond to `@ScaledMetric`.

```
Minimum: 14pt body text
Default: 17pt body text
Maximum: 23pt body text (xxxLarge)
```

---

## Layout & Spacing

### Spacing Scale

Use a consistent spacing scale based on 4pt increments:

| Token | Value | Usage |
|-------|-------|-------|
| `xxxs` | 2pt | Hairline gaps |
| `xxs` | 4pt | Icon-to-text gaps |
| `xs` | 8pt | Tight grouping |
| `sm` | 12pt | Related elements |
| `md` | 16pt | Standard padding |
| `lg` | 24pt | Section separation |
| `xl` | 32pt | Major sections |
| `xxl` | 48pt | Page-level spacing |
| `xxxl` | 64pt | Hero spacing |

### Content Width

Messages should not span the full width on large screens. This improves readability.

```
Maximum content width: 720pt
Centered horizontally on iPad/large screens
Full width (with padding) on iPhone
```

### Safe Areas

Always respect safe areas:
- Top: Status bar, Dynamic Island
- Bottom: Home indicator
- Sides: Device curves on newer iPhones

### Grid System

**iPhone (Compact Width):**
- Single column layout
- 16pt horizontal margins
- Full-width input bar

**iPad (Regular Width):**
- Sidebar (280pt) + Main content
- Sidebar collapsible
- Content centered with max-width

```
┌──────────────────────────────────────────────────────────┐
│                        iPad Layout                        │
├────────────┬─────────────────────────────────────────────┤
│            │                                              │
│  Sidebar   │              Main Content                   │
│   280pt    │         (centered, max 720pt)               │
│            │                                              │
│            │                                              │
└────────────┴─────────────────────────────────────────────┘
```

---

## Component Library

### 1. Chat Input Bar

The input bar is the primary interaction point. It must be instantly recognizable and delightful to use.

**Anatomy:**
```
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────────┐   │
│  │ [+]  Type a message...                    [🎤] [↑] │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
     │                                           │    │
     │                                           │    └── Send button (accent when active)
     │                                           └─────── Voice input
     └─────────────────────────────────────────────────── Attachments/commands
```

**Specifications:**
- Shape: Pill (fully rounded ends)
- Background: `surface`
- Border: 1pt, `border` color
- Height: 44pt minimum, expands for multi-line
- Max height: 120pt (then scrolls internally)
- Padding: 12pt horizontal, 10pt vertical
- Shadow: Subtle glow when focused

**States:**
- Default: Subtle border, placeholder text
- Focused: Accent border or glow
- With text: Send button becomes active (accent color)
- Streaming: Send button becomes Stop button (red)
- Disabled: Reduced opacity

### 2. Message Display

Messages flow like a document, not chat bubbles.

**User Message:**
```
                                          ┌─────────────┐
                                          │ User text   │
                                          │ goes here   │
                                          └─────────────┘
                                                    12:34 PM
```
- Alignment: Right
- No background/bubble
- Color: `textPrimary` with slightly higher weight
- Timestamp: Below, right-aligned, `textTertiary`

**Assistant Message:**
```
┌──────────────────────────────────────────────────────────┐
│ Assistant response flows naturally across the full       │
│ width of the content area. It reads like a document,    │
│ not a chat bubble.                                       │
│                                                          │
│ Code blocks have their own styling:                      │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ const greeting = "Hello, world!";                    │ │
│ └──────────────────────────────────────────────────────┘ │
│                                                          │
│ ▼ Read: src/auth.ts                              [card] │
│                                                          │
└──────────────────────────────────────────────────────────┘
                                                   12:35 PM
```
- Alignment: Left, full content width
- No background/bubble
- Color: `textPrimary`
- Generous line height for readability

### 3. Tool Call Cards

Tool calls (file reads, edits, bash commands) are shown as collapsible cards.

**Collapsed State:**
```
┌─────────────────────────────────────────────────────────┐
│  📄  Read: src/auth.ts                            [▼]  │
└─────────────────────────────────────────────────────────┘
```

**Expanded State:**
```
┌─────────────────────────────────────────────────────────┐
│  📄  Read: src/auth.ts                            [▲]  │
├─────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────┐  │
│  │ 1  import { hash } from 'bcrypt';                │  │
│  │ 2                                                 │  │
│  │ 3  export async function validateUser() {        │  │
│  │ 4    // Implementation...                        │  │
│  │ 5  }                                             │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Tool Icons:**
| Tool | Icon | Color |
|------|------|-------|
| read | 📄 `doc.text` | Blue |
| write/edit | ✏️ `pencil` | Orange |
| bash | 💻 `terminal` | Green |
| glob/grep | 🔍 `magnifyingglass` | Purple |
| web | 🌐 `globe` | Teal |

**Specifications:**
- Background: `surface`
- Border: 1pt, `border`
- Border radius: 8pt
- Padding: 12pt
- Chevron animates on expand/collapse

### 4. Code Blocks

Code is displayed with syntax highlighting and utility actions.

```
┌─────────────────────────────────────────────────────────┐
│  typescript                                    [Copy]  │
├─────────────────────────────────────────────────────────┤
│  const greeting: string = "Hello";                     │
│  console.log(greeting);                                │
└─────────────────────────────────────────────────────────┘
```

**Specifications:**
- Background: `codeBackground` (#1E1E1E)
- Border radius: 8pt
- Font: SF Mono, 14pt
- Line numbers: Optional, `textTertiary`
- Language label: Top-left, `caption`, `textSecondary`
- Copy button: Top-right, appears on hover/tap
- Horizontal scroll for long lines
- Max height: 300pt, then scrolls vertically

### 5. Sidebar (iPad)

The sidebar provides navigation and chat history.

```
┌────────────────────────────┐
│  VibeRemote           [×]  │
├────────────────────────────┤
│  [+] New Chat              │
│  [🔍] Search               │
├────────────────────────────┤
│  Today                     │
│    Fix authentication...   │
│    Add unit tests for...   │
├────────────────────────────┤
│  Yesterday                 │
│    Refactor API endpoi...  │
│    Debug crash in prod...  │
├────────────────────────────┤
│  Previous 7 Days           │
│    Implement caching...    │
│    Review PR #234...       │
├────────────────────────────┤
│                            │
│                            │
├────────────────────────────┤
│  [👤] Settings             │
└────────────────────────────┘
```

**Specifications:**
- Width: 280pt
- Background: `background` (slightly darker than main)
- Collapsible with hamburger menu
- Grouped by date (Today, Yesterday, Previous 7 Days, Older)
- Each chat row: Title (truncated), subtle preview
- Selected state: `accentSubtle` background
- Settings at bottom, always visible

### 6. Model Picker

Dropdown/sheet for selecting the AI model.

**Trigger (in header):**
```
┌─────────────────────────────┐
│  claude-sonnet-4  [▼]      │
└─────────────────────────────┘
```

**Sheet Content:**
```
┌─────────────────────────────────────────────────────────┐
│                    Select Model                    [×]  │
├─────────────────────────────────────────────────────────┤
│  ANTHROPIC                                              │
│  ┌───────────────────────────────────────────────────┐  │
│  │  claude-sonnet-4                            [✓]  │  │
│  │  claude-opus-4                                   │  │
│  │  claude-haiku                                    │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  OPENAI                                                 │
│  ┌───────────────────────────────────────────────────┐  │
│  │  gpt-4o                                          │  │
│  │  gpt-4o-mini                                     │  │
│  │  o1                                              │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  GOOGLE                                                 │
│  ┌───────────────────────────────────────────────────┐  │
│  │  gemini-2.0-flash                                │  │
│  │  gemini-2.5-pro                                  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Specifications:**
- Presentation: Sheet (`.medium` detent on iPhone)
- Grouped by provider
- Checkmark for selected model
- Optional: Show context window size, capabilities

### 7. Empty State

Shown when no messages exist in the current chat.

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                                                         │
│                                                         │
│                                                         │
│              What can I help with?                      │
│                                                         │
│                                                         │
│         ┌─────────────────────────────────────┐        │
│         │ [+]  Ask anything...          [🎤] [↑] │        │
│         └─────────────────────────────────────┘        │
│                                                         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Specifications:**
- Headline: `title2`, centered
- Input bar: Centered, max-width 600pt
- Optional: Quick action chips below headline

### 8. Status Panel

Slide-up sheet showing session details.

```
┌─────────────────────────────────────────────────────────┐
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                         │
│  SESSION STATISTICS                                     │
│  ─────────────────────────────────────────────────────  │
│  📊 Tokens        2,450 in / 1,230 out                 │
│  💰 Cost          $0.15                                │
│  ⏱️ Duration      45.2s                                │
│                                                         │
│  MODIFIED FILES                                         │
│  ─────────────────────────────────────────────────────  │
│  📄 src/auth.ts                          [View Diff]   │
│  📄 src/middleware.ts                    [View Diff]   │
│                                                         │
│  TODO LIST                                              │
│  ─────────────────────────────────────────────────────  │
│  ☑️ Analyze authentication flow                        │
│  ⬜ Add unit tests                                      │
│                                                         │
│  MCP SERVERS                                            │
│  ─────────────────────────────────────────────────────  │
│  🟢 filesystem    Connected                            │
│  🔴 slack         Disconnected          [Connect]      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Interaction Patterns

### Gestures

| Gesture | Context | Action |
|---------|---------|--------|
| Swipe right | Chat view (iPhone) | Reveal sidebar |
| Swipe left | Sidebar chat row | Delete/archive options |
| Long press | Message | Copy, delete, retry menu |
| Pull down | Message list | Refresh |
| Tap | Tool card | Expand/collapse |
| Double tap | Code block | Select all |

### Keyboard Shortcuts (iPad with keyboard)

| Shortcut | Action |
|----------|--------|
| ⌘ + N | New chat |
| ⌘ + / | Focus input |
| ⌘ + K | Command palette |
| ⌘ + , | Settings |
| ⌘ + [ | Previous chat |
| ⌘ + ] | Next chat |
| Escape | Stop generation |

### Focus States

All interactive elements must have visible focus states for keyboard navigation:
- Buttons: Accent ring (2pt)
- Input fields: Accent border
- List items: Subtle background highlight

---

## Animation & Motion

### Principles

1. **Purposeful:** Animations guide attention and provide feedback
2. **Quick:** Most animations complete in 200-350ms
3. **Natural:** Use spring physics for organic feel
4. **Subtle:** Don't distract from content

### Timing Curves

| Name | Curve | Duration | Usage |
|------|-------|----------|-------|
| `quick` | easeOut | 150ms | Micro-interactions |
| `standard` | easeInOut | 250ms | Most transitions |
| `smooth` | easeInOut | 350ms | Page transitions |
| `spring` | spring(0.35, 0.7) | ~400ms | Bouncy elements |

### Specific Animations

**Message Appearance:**
- Fade in + slight slide up
- Duration: 250ms
- Stagger: 50ms between messages

**Streaming Text:**
- Characters appear with subtle fade
- Cursor blinks at end (500ms interval)

**Tool Card Expand:**
- Height animates with spring
- Content fades in after height settles
- Chevron rotates 180°

**Sidebar Slide:**
- Slides from left edge
- Main content dims slightly
- Duration: 300ms, spring curve

**Send Button:**
- Subtle scale pulse on tap (1.0 → 0.95 → 1.0)
- Color transition when becoming active

**Typing Indicator:**
- Three dots pulsing in sequence
- Each dot: scale 1.0 → 1.3 → 1.0
- Stagger: 150ms between dots

---

## Accessibility

### Requirements

1. **Dynamic Type:** All text scales with system settings
2. **VoiceOver:** Full screen reader support with meaningful labels
3. **Reduce Motion:** Respect `accessibilityReduceMotion` preference
4. **Color Contrast:** Minimum 4.5:1 for body text, 3:1 for large text
5. **Touch Targets:** Minimum 44×44pt for all interactive elements

### VoiceOver Labels

| Element | Label | Hint |
|---------|-------|------|
| Send button | "Send message" | "Double tap to send" |
| Stop button | "Stop generation" | "Double tap to stop AI response" |
| Model picker | "Current model: [name]" | "Double tap to change model" |
| Tool card | "[Tool name]: [file/command]" | "Double tap to expand" |
| Sidebar toggle | "Toggle sidebar" | "Double tap to show chat history" |

### Reduced Motion

When `accessibilityReduceMotion` is enabled:
- Replace animations with instant transitions
- Disable parallax effects
- Use simple fades instead of slides

---

## Platform Adaptations

### iPhone

- Single-column layout
- Sidebar accessed via swipe or hamburger menu
- Input bar at bottom, respects keyboard
- Compact header

### iPad

- Split view: Sidebar + Main content
- Sidebar always visible in landscape (collapsible)
- Keyboard shortcuts supported
- Pointer/trackpad hover states

### iPad Multitasking

- Support Slide Over (compact width)
- Support Split View (1/3, 1/2, 2/3)
- Adapt layout based on available width

### Stage Manager

- Support resizable windows
- Minimum window size: 320×480pt
- Adapt to any aspect ratio

---

## Reference Designs

### ChatGPT (Primary Inspiration)

**What to adopt:**
- Clean, minimal header with model selector
- Document-like message flow (no bubbles)
- Centered content with max-width
- Pill-shaped input bar
- Sidebar with chat history grouped by date
- Empty state with centered prompt

**What to adapt for Apple:**
- Use SF Pro instead of custom fonts
- Follow iOS navigation patterns
- Use native sheet presentations
- Respect safe areas and Dynamic Island

### Apple Notes

**What to adopt:**
- Clean typography hierarchy
- Subtle toolbar
- Seamless sync indication

### Linear

**What to adopt:**
- Sophisticated dark theme
- Subtle hover states
- Keyboard-first design

### Differences from iMessage/WhatsApp

| Aspect | iMessage Style | VibeRemote Style |
|--------|----------------|------------------|
| Messages | Bubbles with tails | No bubbles, document flow |
| Alignment | Alternating left/right | User right, AI full-width |
| Background | Per-message colors | No per-message background |
| Density | Compact | Generous spacing |
| Focus | Quick back-and-forth | Long-form responses |

---

## Implementation Notes

### SwiftUI Best Practices

1. Use `@Environment(\.colorScheme)` for theme adaptation
2. Use `@ScaledMetric` for spacing that scales with Dynamic Type
3. Use `preferredColorScheme(.dark)` for previews
4. Extract reusable components into separate files
5. Use `ViewModifier` for consistent styling

### File Organization

```
Sources/
├── Theme/
│   └── VibeTheme.swift          # Colors, typography, spacing
├── Views/
│   ├── Chat/
│   │   ├── ChatView.swift       # Main container
│   │   ├── MessageView.swift    # Message display
│   │   ├── ChatInputBar.swift   # Input component
│   │   ├── ToolCallView.swift   # Tool cards
│   │   └── CodeBlockView.swift  # Code display
│   ├── Sidebar/
│   │   └── ChatSidebarView.swift
│   └── Components/
│       ├── ModelPickerView.swift
│       └── StatusPanelView.swift
└── Models/
    └── ChatMessage.swift        # Message data model
```

### Testing Checklist

- [ ] Dark mode appearance
- [ ] Light mode appearance
- [ ] Dynamic Type (all sizes)
- [ ] VoiceOver navigation
- [ ] Reduced Motion
- [ ] iPhone SE (smallest screen)
- [ ] iPhone 15 Pro Max (largest phone)
- [ ] iPad Mini
- [ ] iPad Pro 12.9"
- [ ] iPad with keyboard
- [ ] Split View multitasking

---

*Last updated: January 2026*
