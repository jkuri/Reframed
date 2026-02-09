# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
# Debug build
xcodebuild -scheme Frame -configuration Debug build CODE_SIGNING_ALLOWED=NO

# Release build
xcodebuild -scheme Frame -configuration Release build CODE_SIGNING_ALLOWED=NO
```

No test target exists yet. No linter is configured.

## Architecture

Frame is a macOS menu-bar-only screen recording app (macOS 15+, Swift 6 strict concurrency).

### Concurrency model

Everything is actor-isolated. The core pattern:

- **`CaptureCoordinator`** (actor) — central state machine that owns the recording and selection coordinators
- **`StateProjection`** (@MainActor, @Observable) — SwiftUI-bindable projection of coordinator state; held as `@MainActor let ui` on the coordinator
- **`RecordingCoordinator`** (actor) — owns `VideoWriter` + `ScreenCaptureSession`, drives the capture pipeline
- **`VideoWriter`** (actor) — AVAssetWriter wrapper (H.264 MP4, 30fps)
- **`ScreenCaptureSession`** (class, `@unchecked Sendable`) — SCStream wrapper; unchecked because SCStream isn't Sendable yet
- **`SelectionCoordinator`** (@MainActor) — manages the full-screen overlay window for region selection

### State machine

```
idle → selecting → recording ⇄ paused → processing → idle
```

### Recording flow

1. Full-screen transparent overlay with crosshair cursor
2. Drag to select region (8 resize handles for adjustment)
3. Confirm → ScreenCaptureKit captures the region
4. CVPixelBuffers flow through VideoWriter to `/tmp/Frame/frame-{timestamp}.mp4`
5. Stop → finalize → move to `~/Frame/`

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
- `LSUIElement = true` (no Dock icon)
- App sandbox disabled (required for ScreenCaptureKit)
- Use `CODE_SIGNING_ALLOWED=NO` for command-line builds without a signing team
- SPM PBXBuildFile entries need `productRef` only (no `fileRef`)
