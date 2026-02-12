# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
# Debug build
make build

# Release build
make release

# Build and run (debug)
make dev

# Create DMG installer
make dmg
```

No test target exists yet. No linter is configured.

## Architecture

Frame is a macOS screen recording app with a menu bar interface, floating capture toolbar, built-in video editor, and `.frm` project management (macOS 15+, Swift 6 strict concurrency).

### Concurrency model

Everything is actor-isolated. The core pattern:

- **`CaptureCoordinator`** (actor) — central state machine that owns the recording and selection coordinators
- **`StateProjection`** (@MainActor, @Observable) — SwiftUI-bindable projection of coordinator state; held as `@MainActor let ui` on the coordinator
- **`RecordingCoordinator`** (actor) — owns `VideoWriter` + `ScreenCaptureSession`, drives the capture pipeline
- **`VideoTrackWriter`** / **`AudioTrackWriter`** (actors) — AVAssetWriter track wrappers
- **`ScreenCaptureSession`** (class, `@unchecked Sendable`) — SCStream wrapper; unchecked because SCStream isn't Sendable yet
- **`SelectionCoordinator`** (@MainActor) — manages the full-screen overlay window for region selection
- **`VideoCompositor`** / **`PiPVideoCompositor`** — export-time compositing (background, padding, PiP)

### State machine

```
idle → selecting → recording ⇄ paused → processing → idle
```

### Recording flow

Frame offers three recording options:

- **Record entire screen** — captures the full display
- **Record specific window** — captures a single application window
- **Record selected area** — full-screen transparent overlay with crosshair cursor; drag to select region (8 resize handles for adjustment)

Optional webcam PiP overlay and configurable countdown timer before recording starts.

After selection, ScreenCaptureKit captures the chosen region, window, or screen. CVPixelBuffers flow through the track writers. On stop, the editor window opens automatically.

### Video editor

Built-in editor with timeline trimming, background styles (solid color, gradients), adjustable padding/corner radius, and webcam PiP repositioning. Export supports MP4/MOV with H.264/H.265, configurable FPS and resolution.

### Project management

Recordings are saved as `.frm` bundles (UTI: `eu.jankuri.frame.project`) containing source video, webcam video, and metadata JSON. Projects can be reopened and re-edited.

### Coordinate system

AppKit uses bottom-left origin; ScreenCaptureKit uses top-left. `SelectionRect.screenCaptureKitRect` performs the Y-axis flip accounting for backing scale factor.

### Menu bar

Uses `MenuBarExtra(.window)` + MenuBarExtraAccess (1.2.x) for the `isPresented` binding that stock SwiftUI doesn't expose.

## Swift 6 patterns used throughout

- **CVPixelBuffer across actors**: `nonisolated(unsafe)` + `@Sendable` closure with local capture of actor ref
- **Actor ↔ MainActor**: StateProjection lives on MainActor; coordinator calls `await MainActor.run` to update it
- **@unchecked Sendable**: only for ScreenCaptureSession wrapping non-Sendable SCStream

## Dependencies (SPM via Xcode)

- `swift-log` ≥ 1.6.0 (logging)
- `MenuBarExtraAccess` 1.2.x (max 1.2.2 — do NOT use 1.9.x, it doesn't exist)

## Code style

- Do not add code comments. Generate only code, no inline comments or doc comments.

## Key constraints

- Bundle ID: `eu.jkuri.frame`
- `LSUIElement = false` (app shows in Dock with icon)
- App sandbox disabled (required for ScreenCaptureKit)
- Version is managed in `Config.xcconfig` (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`)
- SPM PBXBuildFile entries need `productRef` only (no `fileRef`)
