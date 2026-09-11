<p align="center">
  <img width="64" alt="Reframed AppIcon" src="https://github.com/user-attachments/assets/ab90875f-4092-4ca9-b475-9a60b9c6445a" />
</p>

# <p align="center">Reframed</p>

> Open-source macOS screen recorder and capture editor. A free alternative to Screen Studio - capture your screen, windows, or iOS devices with a webcam overlay, then edit on a timeline with auto-captions and smooth cursor zooms.

<p align="center">
  <img width="100%" alt="Reframed Editor" src="https://github.com/user-attachments/assets/ea3d9554-8695-4d98-846f-90c422b25550" />
</p>

## The idea

Screen recorders give you a raw .mp4. Getting cursor-tracking zoom effects, auto-captions, or webcam overlays on top of that usually means paying for a proprietary app. Reframed is the open-source alternative - record, edit and export in one app.

### Core features

- **Capture and edit in one place.** Record your screen, window, or region, then go straight into the built-in editor. No round-tripping through other tools.
- **Zoom and pan that follow your cursor.** Auto-zoom detects where you click and generates keyframes. You can also place them manually or lock the viewport to your cursor.
- **Noise reduction built in.** Microphone audio runs through RNNoise, so you don't need a separate audio chain to clean up background noise.
- **Webcam overlay and fullscreen sections.** Drop your camera feed in as a PiP or switch to fullscreen webcam for specific segments on the timeline.
- **Export exactly what you need.** Pick your codec, resolution, and FPS. Platform presets handle the rest for YouTube, Twitter/X, TikTok, and others.

## Install

Via `homebrew` (recommended):

```bash
brew install --cask jkuri/reframed/reframed
```

Or grab the `.dmg` from [Releases](https://github.com/jkuri/reframed/releases).

## Features

### Recording

- **Four capture modes:** entire screen, single window, custom region, or iOS device via USB. Multi-display support included.
- **System audio and microphone** capture with real-time level indicators
- **Webcam overlay** (Picture-in-Picture) that can be hidden while recording
- **120 Hz cursor tracking** records position and click data independently from video frame rate
- **`.frm` project bundles** preserve all source recordings and editor state for re-editing

### Video editor

- **Timeline trimming** with independent trim ranges for video, system audio, and microphone
- **Audio region editing** with per-track volume and mute controls
- **Noise reduction** powered by [RNNoise](https://github.com/xiph/rnnoise) at adjustable intensity
- **Background styles:** solid color, gradient presets, or custom image (multiple fill modes)
- **Canvas aspect ratios** (original, 16:9, 1:1, 4:3, 9:16) plus adjustable padding and corner radius
- **Webcam PiP** with draggable positioning, corner presets, size/radius/border/shadow/mirror
- **Webcam background replacement** via person segmentation (blur, solid color, gradient, or custom image)
- **Camera regions** set webcam visibility per-segment on the timeline (fullscreen, hidden, or custom position) with entry/exit transitions
- **Video regions** for cutting segments from the timeline
- **Time-lapse speed** (1x-16x) that shortens the export by the same factor
- **Undo/redo history** and fullscreen preview with scrub

### Cursor

- **Custom cursor styles** with SVG-based designs, adjustable primary and outline colors
- **Click highlights** and **click sounds** (30 built-in samples across five categories)
- **Cursor effects:** click bounce, directional sway, and motion blur with adjustable intensity
- **Movement smoothing** using spring physics-based interpolation and speed presets
- **Spotlight effect** dims everything outside a radius around the cursor. Timeline regions control when it's active.

### Zoom & pan

- **Manual keyframes** on the timeline to set zoom level and center point, eased with Hermite interpolation
- **Auto-zoom** detects cursor click clusters and generates keyframes from dwell time
- **Cursor-follow mode** keeps the viewport locked to cursor position in real time

### Captions

- **On-device speech-to-text** using [WhisperKit](https://github.com/argmaxinc/WhisperKit) (Apple Silicon) with four model sizes downloaded on first use
- **Word-level timestamps** with automatic short-segment merging from microphone or system audio
- **Language selection** with auto-detect option
- **Caption styling:** font size, weight, position, text/background colors, opacity, words per line
- **Export as burned-in captions** or SRT/VTT sidecar files

### Export

- **MP4, MOV, or GIF** with H.264, H.265, ProRes 422, and ProRes 4444 codecs
- **Platform presets** for YouTube, Twitter/X, TikTok, Instagram, Discord, ProRes, and GIF
- **GIF export** powered by [gifski](https://gif.ski) with quality presets
- **Configurable FPS and resolution** (Original, 4K, 1080p, 720p)
- **Parallel multi-core rendering** for faster exports with progress bar and ETA

## Requirements

- macOS 15.0 or later
- Screen Recording permission
- Accessibility permission (for cursor and keystroke capture)
- Microphone permission (optional, for mic capture)
- Camera permission (optional, for webcam overlay)

## License

MIT
