<p align="center">
  <img width="64" alt="AppIcon" src="https://github.com/user-attachments/assets/ab90875f-4092-4ca9-b475-9a60b9c6445a" />
</p>

# <p align="center">Reframed</p>

macOS screen recorder with a built-in editor. Capture your screen, windows, regions, or iOS devices over USB with webcam overlay, then edit and export.

## Download

Grab the latest `.dmg` from the [Releases](https://github.com/jkuri/reframed/releases) page.

Or install via Homebrew (recommended):

```bash
brew install --cask jkuri/reframed/reframed
```

## Features

### Recording

- Four capture modes: entire screen, single window, custom region or iOS device via USB
- Multi-display support for screen recording
- System audio and microphone capture with real-time level indicators
- Webcam overlay (Picture-in-Picture) with option to hide preview while recording
- Cursor position and click data captured at 120 Hz independently from video frame rate
- Configurable FPS, countdown timer, and global keyboard shortcuts
- `.frm` project bundles preserve all source recordings and editor state for re-editing

### Video Editor

- Timeline trimming with independent trim ranges for video, system audio, and microphone
- Audio region editing with per-track volume and mute controls
- Microphone noise reduction powered by [RNNoise](https://github.com/xiph/rnnoise) with adjustable intensity
- Background styles: solid color, gradient presets, or custom image with fill modes
- Canvas aspect ratios (original, 16:9, 1:1, 4:3, 9:16) with adjustable padding and corner radius
- Webcam PiP with draggable positioning, corner presets, configurable size/radius/border/shadow/mirror
- Webcam background replacement (blur, solid color, gradient, or custom image) via person segmentation
- Camera regions — timeline-based webcam visibility control (fullscreen, hidden, or custom position) with entry/exit transitions (fade, scale, slide)
- Video regions for cutting segments from the timeline
- Undo/redo history with snapshot rollback
- Fullscreen preview mode with seek and scrub

### Cursor

- Multiple SVG-based cursor styles with adjustable primary and outline colors
- Click highlights with configurable color and size
- Cursor movement smoothing with spring physics-based interpolation and speed presets

### Zoom & Pan

- **Manual keyframes** — add zoom points on the timeline with configurable zoom level and center point using smooth Hermite easing
- **Auto-detection** — generates zoom keyframes from cursor click clusters based on configurable dwell threshold
- **Cursor-follow mode** — zoom viewport tracks cursor position in real time

### Export

- Export to MP4, MOV or GIF
- H.264, H.265 (HEVC), ProRes 422 and ProRes 4444 codecs
- Platform presets for YouTube, Twitter/X, TikTok, Instagram, Discord, ProRes and GIF
- GIF export powered by [gifski](https://gif.ski) with quality presets
- Configurable FPS and resolution (Original, 4K, 1080p, 720p)
- Parallel multi-core rendering for faster exports
- Progress bar with ETA

## Requirements

- macOS 15.0 or later
- Screen Recording permission
- Accessibility permission (for cursor and keystroke capture)
- Microphone permission (optional, for mic capture)
- Camera permission (optional, for webcam overlay)

## Build

```bash
# Debug build
make build

# Release build
make release

# Build and run
make dev

# Create DMG installer
make dmg

# Install to /Applications
make install
```

## License

MIT
