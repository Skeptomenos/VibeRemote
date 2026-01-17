# UI/UX Design Handover - VibeRemote iOS App

**Date**: January 4, 2026  
**Purpose**: Complete context for a design-focused session to improve the iOS app UI/UX  
**Status**: Functional app ready for visual polish

---

## 1. Executive Summary

VibeRemote is a native iOS app that provides a **ChatGPT-like experience** for interacting with AI coding agents (OpenCode) running on a remote server. The core functionality is working - now it needs visual polish to feel like a premium Apple application.

### The Vision

> "I want to use my own ChatGPT on my iPhone, where the magic happens on my server."

The app should feel like a **premium SaaS chat application** while being fully self-hosted. Think ChatGPT meets Apple Notes - clean, focused, delightful.

---

## 2. Current State

### What Works
- Real-time streaming responses via SSE
- Thinking/reasoning display for thinking models
- Tool call visualization (Bash, Read, Write operations)
- Model picker with provider/model selection
- Session management (create, resume, switch)
- Error handling with descriptive messages

### What Needs Design Love
| Area | Current State | Desired State |
|------|---------------|---------------|
| **Thinking UI** | Plain text with brain icon | Collapsible, visually distinct section |
| **Tool Cards** | Functional but basic | Polished, animated, delightful |
| **Message Flow** | Works but feels static | Smooth animations, natural flow |
| **Empty State** | Basic centered text | Inspiring, welcoming |
| **Model Picker** | Functional sheet | Polished, grouped by provider |
| **Input Bar** | Works well | Could use micro-interactions |
| **Code Blocks** | Basic styling | Syntax highlighting, copy button |
| **Overall Polish** | Functional | Premium, Apple-quality |

---

## 3. Design System (Already Defined)

A comprehensive design system exists in `DESIGN_SYSTEM.md`. Key elements:

### Color Palette (Dark Mode Primary)

```
Background Hierarchy:
├── Level 0: #212121 (Base - main canvas)
├── Level 1: #2F2F2F (Surface - cards, inputs)
└── Level 2: #3A3A3A (Elevated - modals, popovers)

Text:
├── Primary: #ECECEC
├── Secondary: #9A9A9A
└── Tertiary: #666666

Accent: #0A84FF (Apple Blue)
```

### Typography

- **System Font**: SF Pro (San Francisco)
- **Code Font**: SF Mono
- **Body**: 17pt Regular
- **User Messages**: 16pt Medium
- **Assistant Messages**: 16pt Regular
- **Code**: 14pt Monospace

### Spacing Scale (4pt base)

```swift
xxxs: 2pt   // Hairline gaps
xxs:  4pt   // Icon-to-text
xs:   8pt   // Tight grouping
sm:   12pt  // Related elements
md:   16pt  // Standard padding
lg:   24pt  // Section separation
xl:   32pt  // Major sections
```

### Corner Radii

```swift
xs:   4pt   // Small elements
sm:   8pt   // Cards, code blocks
md:   12pt  // Larger cards
lg:   16pt  // Sheets
pill: 999pt // Input bar, buttons
```

---

## 4. Design Principles

### 1. Content First, Chrome Last
The conversation is the product. Minimize UI chrome. Messages should flow like a document.

### 2. Conversational, Not Transactional
This is a chat with an AI partner, not a form. Natural, flowing, document-like.

### 3. Progressive Disclosure
Show only what's needed. Tool details expand on tap. Settings reveal when relevant.

### 4. Responsive Confidence
Every action has immediate feedback. Streaming text appears character by character. Buttons respond instantly.

### 5. Dark Mode Native
Design dark mode first. Many developers work in dark environments.

---

## 5. Component Specifications

### 5.1 Chat Input Bar

**Current**: `ios-app/VibeRemote/Sources/Views/Chat/ChatInputBar.swift`

**Anatomy**:
```
┌─────────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────────┐   │
│  │ Message...                                  [↑] │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Specifications**:
- Shape: Pill (fully rounded ends)
- Background: `surface` (#2F2F2F)
- Border: 1pt, subtle
- Height: 44pt minimum, expands for multi-line (max 120pt)
- Send button: Circular, accent color when text present
- Focus state: Accent border + subtle glow

**Improvements Needed**:
- [ ] Subtle scale animation on send button tap
- [ ] Smooth height transition when expanding
- [ ] Placeholder text animation on focus
- [ ] Stop button pulse animation when streaming

### 5.2 Message Display

**Current**: `ios-app/VibeRemote/Sources/Views/Chat/MessageView.swift`

**User Messages**:
- Alignment: Right
- No bubble/background
- Font: 16pt Medium
- Color: Primary text

**Assistant Messages**:
- Alignment: Left, full width
- No bubble/background
- Font: 16pt Regular
- Generous line height (1.5x)

**Improvements Needed**:
- [ ] Fade-in animation on message appearance
- [ ] Slight slide-up on new messages
- [ ] Staggered animation for multiple messages
- [ ] Streaming cursor at end of text

### 5.3 Thinking/Reasoning Section

**Current**: Basic text with brain icon in `MessageView.swift`

**Desired Design**:
```
┌─────────────────────────────────────────────────────────┐
│  🧠 Thinking                                       [▼]  │
├─────────────────────────────────────────────────────────┤
│  Let me analyze this step by step...                    │
│  First, I need to understand the authentication flow... │
│  The current implementation uses JWT tokens...          │
└─────────────────────────────────────────────────────────┘
```

**Specifications**:
- Collapsible by default (show first 2 lines)
- Background: Subtle, slightly different from main
- Border: Left accent line (purple/blue gradient?)
- Font: Slightly smaller than main text (14pt)
- Color: Secondary text
- Animation: Smooth expand/collapse

**Improvements Needed**:
- [ ] Make collapsible with expand/collapse
- [ ] Add visual distinction (left border, background)
- [ ] Streaming animation while thinking
- [ ] "Thinking..." label with animated dots

### 5.4 Tool Call Cards

**Current**: `ios-app/VibeRemote/Sources/Views/Chat/ToolCallCard.swift`

**Collapsed State**:
```
┌─────────────────────────────────────────────────────────┐
│  📄  Read: src/auth.ts                            [▼]  │
└─────────────────────────────────────────────────────────┘
```

**Expanded State**:
```
┌─────────────────────────────────────────────────────────┐
│  📄  Read: src/auth.ts                            [▲]  │
├─────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────┐  │
│  │ 1  import { hash } from 'bcrypt';                │  │
│  │ 2                                                 │  │
│  │ 3  export async function validateUser() {        │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Tool Icons & Colors**:
| Tool | Icon | Color |
|------|------|-------|
| read | `doc.text` | Blue (#5AC8FA) |
| write/edit | `pencil` | Orange (#FF9500) |
| bash | `terminal` | Green (#34C759) |
| glob/grep | `magnifyingglass` | Purple (#AF52DE) |

**Improvements Needed**:
- [ ] Smooth spring animation on expand/collapse
- [ ] Chevron rotation animation
- [ ] Running state: Animated progress indicator
- [ ] Success state: Checkmark with subtle animation
- [ ] Error state: Red highlight with shake

### 5.5 Code Blocks

**Desired Design**:
```
┌─────────────────────────────────────────────────────────┐
│  typescript                                    [Copy]  │
├─────────────────────────────────────────────────────────┤
│  const greeting: string = "Hello";                     │
│  console.log(greeting);                                │
└─────────────────────────────────────────────────────────┘
```

**Specifications**:
- Background: #1E1E1E (darker than surface)
- Border radius: 8pt
- Font: SF Mono, 14pt
- Language label: Top-left, caption size
- Copy button: Top-right, appears on tap/hover
- Horizontal scroll for long lines
- Max height: 300pt, then scrolls

**Improvements Needed**:
- [ ] Syntax highlighting (basic keywords, strings, comments)
- [ ] Copy button with success feedback
- [ ] Language detection and label
- [ ] Line numbers (optional)

### 5.6 Empty State

**Desired Design**:
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                                                         │
│                                                         │
│              What can I help with?                      │
│                                                         │
│         ┌─────────────────────────────────────┐        │
│         │ Message...                      [↑] │        │
│         └─────────────────────────────────────┘        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Specifications**:
- Headline: Title2 (22pt Bold), centered
- Subtle fade-in animation on appear
- Input bar centered with max-width
- Optional: Quick action chips below headline

### 5.7 Model Picker Sheet

**Desired Design**:
```
┌─────────────────────────────────────────────────────────┐
│                    Select Model                    [×]  │
├─────────────────────────────────────────────────────────┤
│  ANTHROPIC                                              │
│  ┌───────────────────────────────────────────────────┐  │
│  │  claude-sonnet-4                            [✓]  │  │
│  │  claude-opus-4                                   │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  GOOGLE                                                 │
│  ┌───────────────────────────────────────────────────┐  │
│  │  gemini-2.5-flash                                │  │
│  │  gemini-2.5-pro                                  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Specifications**:
- Presentation: Sheet with `.medium` detent
- Grouped by provider
- Checkmark for selected model
- Smooth selection animation

---

## 6. Animation Guidelines

### Timing Curves

| Name | Curve | Duration | Usage |
|------|-------|----------|-------|
| `quick` | easeOut | 150ms | Micro-interactions |
| `standard` | easeInOut | 250ms | Most transitions |
| `smooth` | easeInOut | 350ms | Page transitions |
| `spring` | spring(0.35, 0.7) | ~400ms | Bouncy elements |

### Specific Animations

**Message Appearance**:
- Fade in + slight slide up (8pt)
- Duration: 250ms
- Stagger: 50ms between messages

**Streaming Text**:
- Characters appear naturally (no animation needed, SSE handles this)
- Optional: Subtle cursor blink at end

**Tool Card Expand**:
- Height animates with spring
- Chevron rotates 180°
- Content fades in after height settles

**Send Button**:
- Subtle scale pulse on tap (1.0 → 0.95 → 1.0)
- Color transition when becoming active

**Typing Indicator** (while waiting for response):
- Three dots pulsing in sequence
- Each dot: scale 1.0 → 1.3 → 1.0
- Stagger: 150ms between dots

---

## 7. File Locations

### Views to Modify

| File | Purpose | Priority |
|------|---------|----------|
| `Views/Chat/ChatView.swift` | Main chat container | High |
| `Views/Chat/MessageView.swift` | Message rendering | High |
| `Views/Chat/ChatInputBar.swift` | Input bar | Medium |
| `Views/Chat/ToolCallCard.swift` | Tool call cards | Medium |
| `Views/Chat/ToolPartCard.swift` | Tool result cards | Medium |
| `Views/Chat/StatusPanelView.swift` | Session info sheet | Low |

### Theme/Design System

| File | Purpose |
|------|---------|
| `Theme/VibeTheme.swift` | Design tokens (colors, spacing, typography) |
| `Theme/OpenCodeTheme.swift` | Legacy terminal theme |

### Models (for reference)

| File | Purpose |
|------|---------|
| `Models/OpenCodeModels.swift` | API data models |
| `ViewModels/ChatViewModel.swift` | Chat state management |

---

## 8. Inspiration & References

### Primary Inspiration: ChatGPT iOS App
- Clean, minimal header with model selector
- Document-like message flow (no bubbles)
- Centered content with max-width
- Pill-shaped input bar
- Sidebar with chat history grouped by date

### Secondary Inspiration
- **Apple Notes**: Clean typography, document-like feel
- **Linear**: Sophisticated dark theme, subtle hover states
- **Raycast**: Command palette, keyboard-first design
- **GitHub Mobile**: Code display, developer-focused UI

### What NOT to Do
- No chat bubbles (this is a document, not iMessage)
- No heavy shadows or skeuomorphism
- No overwhelming animations
- No cluttered UI with too many options visible

---

## 9. Accessibility Requirements

- **Dynamic Type**: All text must scale with system settings
- **VoiceOver**: Full screen reader support
- **Reduce Motion**: Respect `accessibilityReduceMotion`
- **Color Contrast**: Minimum 4.5:1 for body text
- **Touch Targets**: Minimum 44×44pt for interactive elements

---

## 10. Platform Considerations

### iPhone
- Single-column layout
- Input bar at bottom, respects keyboard
- Compact header

### iPad
- Split view: Sidebar + Main content
- Sidebar always visible in landscape
- Keyboard shortcuts supported
- Content centered with max-width (720pt)

---

## 11. Priority Order

### Phase 1: Core Polish (High Impact)
1. **Thinking UI** - Make collapsible, add visual distinction
2. **Message Animations** - Fade-in, slide-up on new messages
3. **Tool Card Animations** - Smooth expand/collapse

### Phase 2: Refinement
4. **Code Blocks** - Syntax highlighting, copy button
5. **Input Bar** - Micro-interactions, focus states
6. **Empty State** - Welcoming design

### Phase 3: Delight
7. **Streaming Cursor** - Blinking cursor at end of streaming text
8. **Typing Indicator** - Animated dots while waiting
9. **Success Feedback** - Subtle animations on completion

---

## 12. Technical Notes

### SwiftUI Animations
```swift
// Use VibeTheme.Animation presets
withAnimation(VibeTheme.Animation.spring) {
    isExpanded.toggle()
}

// For message appearance
.transition(.asymmetric(
    insertion: .opacity.combined(with: .move(edge: .bottom)),
    removal: .opacity
))
```

### Respecting Reduce Motion
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

withAnimation(reduceMotion ? nil : VibeTheme.Animation.standard) {
    // ...
}
```

### Dynamic Type
```swift
// Already using system fonts, but verify scaling
@ScaledMetric var iconSize: CGFloat = 14
```

---

## 13. Build & Test

```bash
# Navigate to project
cd /Users/davidhelmus/Repos/VibeRemote/ios-app/VibeRemote

# Generate Xcode project (if needed)
xcodegen generate

# Open in Xcode
open VibeRemote.xcodeproj

# Build for simulator
# Select iPhone 17 Pro simulator and press Cmd+R
```

### Testing Checklist
- [ ] Dark mode looks polished
- [ ] Light mode is usable (secondary priority)
- [ ] Animations feel smooth, not jarring
- [ ] Text is readable at all Dynamic Type sizes
- [ ] VoiceOver navigation works
- [ ] iPad layout adapts correctly

---

## 14. Success Criteria

The UI work is complete when:

1. **First Impression**: Opening the app feels premium, not "developer project"
2. **Message Flow**: Conversations feel natural and document-like
3. **Thinking Display**: Clearly shows AI reasoning in a collapsible section
4. **Tool Calls**: Expandable cards with smooth animations
5. **Responsiveness**: Every tap has immediate visual feedback
6. **Consistency**: All components follow the design system
7. **Accessibility**: Works with VoiceOver and Dynamic Type

---

## 15. Reference Documents

| Document | Purpose |
|----------|---------|
| `DESIGN_SYSTEM.md` | Complete design system specification |
| `IOS_APP_OBJECTIVE.md` | Product requirements and vision |
| `IOS_APP_HANDOVER.md` | Technical implementation details |
| `AGENTS.md` | Project overview and structure |

---

## 16. Quick Start for Design Session

1. **Read** `DESIGN_SYSTEM.md` for full design specifications
2. **Open** `ios-app/VibeRemote/Sources/Views/Chat/` in Xcode
3. **Start with** `MessageView.swift` - add message animations
4. **Then** improve thinking UI in the `reasoningView` function
5. **Test** frequently in simulator with dark mode

Good luck making VibeRemote beautiful!
