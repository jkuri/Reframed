# Architecture

Reframed is a macOS screen recording app targeting macOS 15+, built with Swift 6 strict concurrency. It runs as a menu bar app with a floating capture toolbar, full-screen selection overlays, and a built-in video editor.

## Source layout

```
Reframed/
├── App/              AppDelegate, Permissions, WindowController
├── CaptureModes/     Area/Screen/Window/Device selection + shared overlay components
├── Compositor/       Video composition and export pipeline
├── Editor/           Video editor (timeline, properties, preview, cursor, zoom, camera regions)
├── Libraries/        Native C/C++ dependencies (gifski for GIF encoding)
├── Logging/          LogBootstrap, RotatingFileLogHandler
├── Project/          .frm bundle management
├── Recording/        Capture pipeline (coordinators, writers, devices, cursor metadata)
├── State/            SessionState, CaptureState, ConfigService, StateService, KeyboardShortcutManager
├── UI/               Toolbar, menu bar, popovers, settings, reusable components
├── Utilities/        Extensions, helpers, encoding settings, sound effects
└── ReframedApp.swift Entry point
```

## State machine

The app moves through a linear state machine defined in `CaptureState`:

```
idle -> selecting -> countdown(remaining) -> recording(startedAt) <-> paused(elapsed) -> processing -> editing -> idle
```

`SessionState` owns the current state and drives every transition. SwiftUI binds directly to it.

## Concurrency model

Everything is actor-isolated. There are no shared mutable globals and no manual thread management outside of a few DispatchQueues for hardware callbacks.

**SessionState** (`@MainActor`, `@Observable`) is the central hub. It owns all coordinators, windows, and the current capture state. UI reads from it directly.

**RecordingCoordinator** (actor) owns the capture session and all track writers. SessionState calls into it with `await`. The coordinator never touches the UI -- when it needs to update something visible, it goes through `MainActor.run`.

**VideoTrackWriter** and **AudioTrackWriter** (actors) wrap AVAssetWriter inputs. They receive sample buffers on dedicated high-priority DispatchQueues from their respective capture sources.

**ScreenCaptureSession** is `@unchecked Sendable` because SCStream itself isn't Sendable yet. It's the only place in the codebase that uses this escape hatch for a framework type.

### Crossing actor boundaries

CVPixelBuffer isn't Sendable. The codebase passes them using `nonisolated(unsafe)` with local captures in `@Sendable` closures, scoped so the buffer's lifetime is controlled.

For other non-Sendable types like AVCaptureSession, there's a `SendableBox<T>` utility wrapper in `Utilities/`.

The general pattern: `@MainActor` code calls `await coordinator.method()` to reach actors. Actors call `await MainActor.run { ... }` when they need to push state back to the UI.

## Key coordinators

**SelectionCoordinator** (`@MainActor`) manages full-screen transparent overlays for area selection. One overlay per connected display. Handles the crosshair cursor, drag-to-select, 8 resize handles, and the recording border shown during countdown/recording.

**WindowSelectionCoordinator** (`@MainActor`) manages the window highlight overlay. Queries the SCWindow list every 2 seconds, tracks mouse position, highlights the window under the cursor. Handles the coordinate flip between AppKit (bottom-left origin) and ScreenCaptureKit (top-left origin).

**EditorState** (`@MainActor`, `@Observable`) is the editor's equivalent of SessionState. It owns all editor data -- trim ranges, regions, zoom keyframes, cursor settings, camera layout, captions, audio processing state -- and drives the preview player and export.

## Coordinate system

AppKit uses bottom-left origin. ScreenCaptureKit uses top-left. `SelectionRect.screenCaptureKitRect` does the Y-axis flip:

```
localQuartzY = displayHeight - localAppKitY - height
```

This conversion happens at selection time and when configuring cursor metadata recording.

## Persistence

Two separate files in `~/.reframed/`:

- **ConfigService** reads/writes `reframed.json` -- user preferences like output folder, FPS, capture quality, appearance, keyboard shortcuts, device selections.
- **StateService** reads/writes `state.json` -- transient layout state like last selection rect, window positions for the toolbar and previews, editor window frame.

Both are `@MainActor` singletons. ConfigService merges saved values with defaults on load, so new preferences get their default values without migration code.

## Menu bar

Uses `MenuBarExtra(.window)` with the MenuBarExtraAccess package (1.2.x) to get an `isPresented` binding that stock SwiftUI doesn't expose. The menu bar icon changes based on app state -- idle shows empty brackets, recording shows a filled circle, paused shows pause bars, and so on.

The status item button reference is stored so the app can handle click-to-stop during recording.

## Keyboard shortcuts

`KeyboardShortcutManager` runs two layers of monitoring:

1. A local NSEvent monitor for when the app is focused.
2. A CGEventTap for global shortcuts that work even when the app is in the background.

Global shortcuts (stop, pause/resume, restart) only fire during recording or countdown. Everything else is local-only. Users can rebind all shortcuts through ConfigService.

## Dependencies

- **swift-log 1.9.x** -- structured logging throughout
- **MenuBarExtraAccess 1.2.x** -- menu bar isPresented binding (pinned below 1.3)
- **rnnoise-spm 1.1.x** -- noise reduction for microphone audio
- **gifski** -- static C library in `Libraries/gifski/` for GIF encoding
