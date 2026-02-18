# Reframed

A powerful macOS screen recorder with built-in video editor. Capture your screen, windows, regions, or iOS devices over USB with webcam overlay — then trim, style, and export.

## Download

Grab the latest `.dmg` from the [Releases](https://github.com/jkuri/reframed/releases) page.

## Features

### Recording

- Menu bar interface with floating capture toolbar
- Record full screen, single window, or custom region
- Record iOS devices (iPhone/iPad) connected via USB
- Region selection with resizable drag handles
- System audio and microphone capture
- Webcam overlay (Picture-in-Picture) during recording, including device mode
- Mouse click visualization with configurable color and size
- Configurable countdown timer before recording
- Pause and resume recordings
- Configurable FPS (24, 30, 40, 50, 60)
- Sound effects for recording actions (start, stop, pause, resume)
- Remember last selection area between recordings
- Light and dark mode support with appearance settings

### Video Editor

- Built-in editor opens automatically after recording
- Timeline with trim handles for precise start/end selection
- Camera fullscreen regions — add time segments where the webcam goes fullscreen (talking head mode)
- Background styles: solid color, gradient presets, or none
- Adjustable padding and video corner radius
- Webcam PiP positioning (corner presets or drag to reposition)
- Webcam PiP customizable size, corner radius, and border
- Cursor overlay with multiple styles, adjustable size, and click highlights
- Zoom & pan with manual keyframes or auto-detection based on cursor dwell time
- Audio region editing for system audio and microphone tracks
- Microphone noise reduction powered by [RNNoise](https://github.com/xiph/rnnoise) (neural network spectral denoiser) with adjustable intensity
- Transport bar with precise timestamp display (centisecond accuracy)
- Preview mode — fullscreen canvas view toggled via button or Escape key
- Recording info panel showing resolution, FPS, duration, and track details
- Live preview of all effects before exporting
- Multiple editor windows can be open simultaneously

### Export

- Export to MP4 or MOV format
- H.264, H.265 (HEVC), ProRes 422, and ProRes 4444 codec options
- Configurable export FPS (24, 30, 40, 50, 60, or original)
- Resolution options: Original, 4K, 1080p, 720p
- Camera fullscreen regions rendered in export (webcam fills canvas during marked segments)
- Progress bar in the top bar during export

### Project Management

- `.frm` project bundles preserve source recordings and editor state
- Reopen and re-edit previous recordings
- Rename projects from the properties panel
- Configurable project and export output folders

### Settings

- Tabbed settings panel (General, Recording, Devices)
- Configurable output and project folders
- Camera maximum resolution selection (720p, 1080p, 4K)
- Mouse click monitor with color picker and size slider
- Appearance preference (System, Light, Dark)

## Requirements

- macOS 15.0 or later
- Screen Recording permission
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
