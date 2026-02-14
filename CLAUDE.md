# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
make build      # Debug build
make release    # Release build
make dev        # Build debug and run
make run        # Build release and run
make dmg        # Create DMG installer
make install    # Install to /Applications
make format     # Format Swift source (swift format)
make clean      # Clean build artifacts
```

No test target exists yet. No linter is configured.

## Architecture

Reframed is a macOS screen recording app with a menu bar interface, floating capture toolbar, built-in video editor, and `.frm` project management (macOS 15+, Swift 6 strict concurrency).

### Source layout

```
Reframed/
├── App/              AppDelegate, Permissions, WindowController
├── CaptureModes/     Area/Screen/Window selection + Common overlay components
├── Editor/           Video editor (timeline, export, compositing, zoom, cursor)
├── Logging/          LogBootstrap, RotatingFileLogHandler
├── Project/          .frm bundle management (ReframedProject, ProjectMetadata)
├── Recording/        Capture pipeline (coordinators, writers, device/webcam/mic/audio)
├── State/            SessionState, CaptureState, CaptureMode, ConfigService, StateService
├── UI/               Toolbar, menu bar, popovers, settings, countdown overlay
├── Utilities/        CGRect/NSScreen extensions, CodableColor, SendableBox, SoundEffect, TimeFormatting
├── ReframedApp.swift Entry point (@main)
└── Info.plist        App configuration
```

### Concurrency model

Everything is actor-isolated. The core pattern:

- **`SessionState`** (@MainActor, @Observable) — central state manager that owns all coordinators, windows, and drives the full recording lifecycle; SwiftUI binds directly to this
- **`RecordingCoordinator`** (actor) — owns `ScreenCaptureSession` + all track writers, drives the capture pipeline
- **`VideoTrackWriter`** / **`AudioTrackWriter`** (actors) — AVAssetWriter track wrappers
- **`ScreenCaptureSession`** (class, `@unchecked Sendable`) — SCStream wrapper; unchecked because SCStream isn't Sendable yet
- **`SelectionCoordinator`** (@MainActor) — manages the full-screen overlay window for area selection and recording borders
- **`WindowSelectionCoordinator`** (@MainActor) — manages window highlight overlay for window selection
- **`EditorState`** (@MainActor, @Observable) — editor state including trim ranges, background, camera layout, cursor, zoom
- **`VideoCompositor`** (enum with static methods) — export-time compositing pipeline
- **`CameraVideoCompositor`** (NSObject, AVVideoCompositing) — custom compositor for rendering background + screen + webcam

### State machine

```
idle → selecting → countdown(remaining) → recording(startedAt) ⇄ paused(elapsed) → processing → editing → idle
```

### Recording flow

Reframed offers four recording modes:

- **Entire screen** — captures the full display
- **Selected window** — window highlight overlay, captures a single application window
- **Selected area** — full-screen transparent overlay with crosshair cursor; drag to select region (8 resize handles)
- **iOS device** — captures connected iPhone/iPad via AVCaptureDevice

Optional features: webcam PiP overlay, microphone audio, system audio capture, configurable countdown timer (3/5/10s), cursor metadata recording with mouse click monitoring.

After selection, ScreenCaptureKit captures the chosen target. CVPixelBuffers flow through `SharedRecordingClock` for timestamp synchronization, then to track writers. On stop, a `.frm` project bundle is created and the editor opens automatically.

### Video editor

Built-in editor with:
- Timeline trimming (independent trim ranges for video, system audio, mic audio)
- Background styles (none, solid color, gradient presets)
- Padding and corner radius (both video and camera)
- Webcam PiP (draggable positioning, 4-corner presets, configurable size/corner radius/border)
- Cursor overlay (multiple styles, smoothing levels, click highlights with configurable color/size)
- Zoom & pan (manual keyframes via `ZoomTimeline`, auto-detection via `ZoomDetector` based on cursor dwell time)
- Export: MP4/MOV with H.264/H.265, configurable FPS and resolution

### Project management

Recordings are saved as `.frm` bundles (UTI: `eu.jankuri.reframed.project`) containing:

```
recording-YYYY-MM-DD-HHmmss.frm/
├── project.json          ProjectMetadata (JSON)
├── screen.mp4            Main screen recording
├── webcam.mp4            Optional webcam overlay
├── system-audio.m4a      Optional system audio
├── mic-audio.m4a         Optional microphone audio
└── cursor-metadata.json  Optional cursor tracking data
```

Projects can be reopened and re-edited. Editor state (trim ranges, camera layout, background, cursor settings, zoom keyframes) is persisted in `project.json`.

### Coordinate system

AppKit uses bottom-left origin; ScreenCaptureKit uses top-left. `SelectionRect.screenCaptureKitRect` performs the Y-axis flip.

### Menu bar

Uses `MenuBarExtra(.window)` + MenuBarExtraAccess (1.2.x) for the `isPresented` binding that stock SwiftUI doesn't expose.

### Persistence

- **`ConfigService`** (@MainActor, singleton) — user preferences stored at `~/.reframed/config.json`
- **`StateService`** (@MainActor, singleton) — session state (last selection rect, window positions) stored at `~/.reframed/state.json`

## Swift 6 patterns used throughout

- **CVPixelBuffer across actors**: `nonisolated(unsafe)` + `@Sendable` closure with local capture of actor ref
- **Actor ↔ MainActor**: `SessionState` lives on MainActor; calls `await coordinator.method()` to reach actors; actors call `await MainActor.run` to update UI
- **@unchecked Sendable**: only for `ScreenCaptureSession` wrapping non-Sendable SCStream
- **SendableBox**: utility wrapper for passing non-Sendable types (e.g. `AVCaptureSession`) across actor boundaries

## Dependencies (SPM via Xcode)

- `swift-log` ≥ 1.6.0 (logging)
- `MenuBarExtraAccess` 1.2.x (max 1.2.2 — do NOT use 1.9.x, it doesn't exist)

## Code style

- Do not add code comments. Generate only code, no inline comments or doc comments.
- Always create reusable views if possible and put them in the `UI/` folder.
- Always reuse functions if possible (e.g. time formatting) and put them in the `Utilities/` folder.
- If a view exceeds 200 lines, break it into separate files using Swift extensions.
- Always run `make format` after changes.
- Always run `make build` after changes and make sure there are no warnings or errors.

## Key constraints

- Bundle ID: `eu.jkuri.reframed`
- `LSUIElement = false` (app shows in Dock with icon)
- App sandbox disabled (required for ScreenCaptureKit)
- Version is managed in `Config.xcconfig` (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`)
- SPM PBXBuildFile entries need `productRef` only (no `fileRef`)
