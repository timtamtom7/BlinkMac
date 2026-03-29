# Blink — iOS App Spec

## Concept

Blink is a one-tap video journal. You open it, you hit record, you talk for up to 30 seconds. It saves. That's it. No editing, no filters, no captions, no social, no accounts. One video per day, timestamped. At the end of the year you have a 365-clip video diary of your life. The opposite of TikTok.

**Core mechanic:** Open → Record (max 30s) → Saved. One video per day.

---

## Brand Identity

**Name:** Blink  
**Tagline:** "Your year, one moment at a time."  
**Vibe:** Instant, intimate, private. Like a written diary but with your actual voice and face. The design should feel like a high-quality camera viewfinder — precise, focused, intentional.

**Aesthetic direction:** Camera viewfinder meets personal archive. Dark, minimal, the video is the UI. The recording frame is the design. When not recording: elegant dark glass with a single record button. When recording: full-screen focus.

**Reference:** A Leica M11 viewfinder. VHS home video but pristine. iOS 26 camera app minimalism.

**Colors:**
- Background: `#0a0a0a`
- Surface: `#141414`
- Recording red: `#ff3b30` (iOS native red)
- Text primary: `#f5f5f5`
- Text secondary: `#8a8a8a`
- Progress ring: `#ff3b30` (same as recording red)

**Typography:**
- SF Pro
- Timestamp: SF Mono, 12pt
- UI labels: SF Pro, 13pt

---

## App Structure

### Home Screen — Record
```
┌─────────────────────────────┐
│  Blink     [Calendar] [⚙️]  │
│                             │
│                             │
│    ┌───────────────────┐    │
│    │                   │    │
│    │                   │    │
│    │      ● REC        │    │  ← Large circular record button
│    │    00:17 / 00:30  │    │     in viewfinder frame
│    │                   │    │
│    │                   │    │
│    └───────────────────┘    │
│                             │
│  Last clip: Mar 24, 9:02am │  ← Shows timestamp of today's clip
│                             │
│  ┌─────────────────────┐    │
│  │ This year: 83 clips │    │  ← Running count
│  └─────────────────────┘    │
│                             │
└─────────────────────────────┘
```

### Calendar Screen
Grid of the year. Each day = a small thumbnail of the clip (or empty circle if no clip). Tap any day to play that clip. Scroll through your year.

### Recording
- Circular record button — tap to start, tap to stop (max 30s)
- Circular progress ring around the button fills as time runs out
- Timer shows elapsed time
- Brief countdown from 3 before recording starts (to get ready)
- When recording: subtle red glow on outer ring
- When stopped: brief "Saved" animation → returns to home

### Settings
- Reminder notification (daily at 8pm: "Blink today?")
- Recording quality (high/medium — high is default)
- About / privacy

---

## Key Interaction Design

### The Record Button
- Large (80pt), centered in a viewfinder-style frame
- Idle: white circle with thin border
- Tapped: starts 3-2-1 countdown overlay
- Recording: circle fills red from bottom (like a progress fill), timer counts up
- Max 30s reached: auto-stops, saves
- Tap again while recording: stops and saves

### Saving
- Brief flash animation on save
- "Saved" text with date/time
- Clip immediately appears in Calendar

### Calendar View
- Full-screen grid of the year
- Thumbnails are small (48pt squares) with rounded corners
- Days with clips: thumbnail preview
- Days without clips: empty circle with date number
- Tap a day: full-screen playback of that day's clip
- After playing: "This moment was X days ago"

### Privacy
- All clips stored locally on device only
- No iCloud sync (unless user opts in)
- No sharing, no social, no accounts
- Delete any clip: swipe on calendar or in detail view

---

## Technical Approach

**Framework:** SwiftUI (iOS 26)  
**Camera:** `AVCaptureSession` with video recording (`AVCaptureMovieFileOutput`)  
**Storage:** Local only — save to app's Documents directory. Use `FileManager`.  
**Thumbnail generation:** `AVAssetImageGenerator` to generate thumbnail from video  
**Notifications:** `UserNotifications` for daily reminder  
**Video compression:** Use `AVAssetExportSession` to compress to ~720p for storage efficiency  

**Dependencies:** None (all native AVFoundation)

**Architecture:**
- `RecordView` — main screen with viewfinder
- `CameraPreview` — `UIViewRepresentable` wrapping `AVCaptureSession`
- `CalendarView` — yearly grid of clips
- `PlaybackView` — full-screen video playback
- `SettingsView`
- `VideoStore` — local file management service

---

## Human Inputs Needed
- [ ] App Store developer account ($99/year)
- [ ] App icon (camera lens / eye motif)
- [ ] App name "Blink" availability check on App Store
- [ ] Privacy policy text (since app records video)
