<p align="center">
  <img width="64" alt="AppIcon" src="https://github.com/user-attachments/assets/ab90875f-4092-4ca9-b475-9a60b9c6445a" />
</p>

# <p align="center">Reframed</p>

A powerful macOS screen recorder with built-in video editor. Capture your screen, windows, regions, or iOS devices over USB with webcam overlay — then trim, style, and export.

<p align="center">
  <img src="https://github.com/user-attachments/assets/390b07d9-ea54-41ff-90dc-f284f6a1f103" />
</p>

## Download

Grab the latest `.dmg` from the [Releases](https://github.com/jkuri/reframed/releases) page.

Or install via Homebrew:

```bash
brew install --cask jkuri/reframed/reframed
```

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
- Audio region editing for system audio and microphone tracks
- Microphone noise reduction powered by [RNNoise](https://github.com/xiph/rnnoise) (neural network spectral denoiser) with adjustable intensity
- Transport bar with precise timestamp display (centisecond accuracy)
- Preview mode — fullscreen canvas view toggled via button or Escape key
- Recording info panel showing resolution, FPS, duration, and track details
- Live preview of all effects before exporting
- Multiple editor windows can be open simultaneously

### Cursor Metadata

During recording, cursor position and click data is captured at 120 Hz (8 ms sampling interval) independently from the video frame rate. Each sample stores the normalized cursor position (0.0–1.0 relative to the capture area) and the mouse button state. Click events and keystrokes are recorded separately with precise timestamps. All metadata is saved as `cursor-metadata.json` inside the `.frm` project bundle and can be used in the editor for cursor overlay rendering and zoom automation.

### Zoom & Pan

- **Manual keyframes** — add zoom keyframes on the timeline with configurable zoom level and center point; interpolation uses smooth Hermite easing for natural transitions
- **Auto-detection** — automatically generates zoom keyframes from cursor click clusters; clicks within a configurable dwell threshold are grouped into regions, and zoom-in/zoom-out transitions are created around each cluster
- **Cursor-follow mode** — when enabled, the zoom viewport tracks the cursor position in real time so the area of interest stays centered
- **Configurable parameters** — zoom level (multiplier), transition duration, dwell threshold, and hold duration
- **Full export integration** — zoom is rendered at export time; both cursor overlay and click highlights are correctly scaled within zoomed regions

### Export

- Export to MP4, MOV, or GIF format
- H.264, H.265 (HEVC), ProRes 422, and ProRes 4444 codec options
- GIF export powered by [gifski](https://gif.ski) with quality presets (Low, Medium, High, Maximum) and max 30 FPS
- Configurable export FPS (24, 30, 40, 50, 60, or original)
- Resolution options: Original, 4K, 1080p, 720p
- Normal and parallel (multi-core) rendering modes
- Camera fullscreen regions rendered in export (webcam fills canvas during marked segments)
- Progress bar with ETA in the top bar during export

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
