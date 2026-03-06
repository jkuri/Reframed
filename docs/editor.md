# Video editor

After recording, Reframed opens a built-in editor. Everything lives in `EditorState` (`@MainActor`, `@Observable`), which owns the player, all editing parameters, and the undo history.

## Timeline trimming

The video has a single trim range (`trimStart`, `trimEnd`) that defines the playback window. Audio tracks have independent trim systems -- each track gets its own array of `AudioRegionData` regions with start/end times. Gaps between regions are silence.

Video regions (`VideoRegionData`) work differently. They define segments to cut out of the timeline entirely. When video regions exist, the compositor remaps all other regions (camera, captions, spotlight) to the resulting compressed timeline.

## Audio regions

Each audio track (system audio, microphone) has an independent list of regions. Regions can't overlap. Operations:

- Adjust start/end with overlap prevention against neighbors
- Move a region while keeping its duration
- Add/remove regions with automatic gap detection
- Sync to the player controller for live preview

Volume and mute are per-track, not per-region. The player and compositor both respect the region boundaries.

## Camera regions

Camera regions control webcam visibility over time. Each region has a type:

- **Fullscreen** -- webcam fills the entire canvas
- **Hidden** -- webcam disappears completely
- **Custom** -- webcam shows as PiP with its own layout, aspect ratio, corner radius, border, and shadow settings

Regions also have entry and exit transitions (none, fade, scale, slide) with configurable duration. The compositor interpolates these transitions per-frame during export.

At any point on the timeline, `effectiveCameraLayout(at:)` returns the active camera configuration -- either from a matching region or the global defaults.

## Zoom and pan

Three modes that can work together:

**Manual keyframes** -- placed on the timeline. Each keyframe stores a time, zoom level, and center point. `ZoomTimeline` interpolates between keyframes with cubic ease-in-out. A single "zoom region" is actually 4 keyframes: zoom-in, hold start, hold end, zoom-out.

**Auto-zoom** -- `ZoomDetector` analyzes cursor click metadata. It groups clicks into clusters based on dwell time, then generates 4-keyframe regions for each cluster. Auto-generated keyframes are flagged (`isAuto: true`) so they can be cleared without losing manual ones.

**Cursor-follow** -- locks the viewport to cursor position in real time. `ZoomTimeline.followCursor()` adjusts the pan to keep the cursor centered within the zoomed view.

All three feed into the same `ZoomTimeline`, which the compositor queries per-frame to get the active zoom rect.

## Cursor overlay

Instead of baking the system cursor into the screen recording, Reframed hides it during capture and renders it from metadata at export time. This means you can change cursor appearance after recording.

**Styles** -- multiple SVG-based designs (center default, crosshair, outline, etc.) with configurable primary fill and outline stroke colors, plus size scaling.

**Click highlights** -- animated rings that appear on click and fade over 0.4 seconds. Configurable color and size.

**Spotlight** -- dims everything outside a circular radius around the cursor. Configurable radius, dim opacity, and edge softness (feather). Controlled by spotlight regions on the timeline, so it can be active for specific segments only.

**Click sounds** -- 30 built-in audio samples across five categories, mixed into the export audio. Volume is configurable.

## Cursor smoothing

Raw cursor data at 120Hz can look jittery, especially during precise movements. The smoothing system applies spring physics to interpolate positions.

Four speed presets (slow, medium, fast, rapid), each with different tension, friction, and mass values. The algorithm:

1. For each cursor sample, compute spring force: `F = tension * displacement - friction * velocity`
2. Integrate with 1ms timesteps
3. During typing intervals (3+ keystrokes within 0.5s gaps), increase tension and friction so the cursor doesn't lag behind text input
4. During zoom regions, boost tension/friction proportionally (up to 4x) so the cursor stays accurate when zoomed in
5. Before clicks, blend toward the click position over a convergence window, then snap to the exact location on click

The smoothed data replaces the raw data for preview and export. Toggling smoothing off reverts to the original samples.

## Background styles

Four options:

- **None** -- transparent (or black in non-alpha formats)
- **Solid color** -- single RGBA fill
- **Gradient** -- 86 named presets with 2-3 color stops and configurable direction
- **Image** -- loaded from a file, with fill (aspect-fill, crops) or fit (aspect-fit, letterboxes) modes

Backgrounds are visible when padding > 0 or when the canvas aspect ratio doesn't match the recording's native ratio.

## Canvas and video styling

- **Aspect ratios**: original, 16:9, 1:1, 4:3, 9:16
- **Padding**: scales both dimensions, creating space for the background
- **Video corner radius**: rounds the screen recording's corners
- **Video shadow**: drop shadow behind the screen recording

## Webcam PiP

When a webcam recording exists:

- Draggable positioning with 4-corner presets (top-left, top-right, bottom-left, bottom-right)
- Configurable size, corner radius, border (width + color), shadow
- Mirror toggle
- Aspect ratio (original, 1:1, 4:3, 16:9)
- Background replacement via person segmentation (blur, solid, gradient, or image behind the person)

## Captions

On-device speech-to-text using WhisperKit (Apple Silicon). Four model sizes, downloaded on first use. Works with either microphone or system audio as source.

Output is word-level timestamps with automatic merging of short segments. Non-speech segments (music markers, silence) are filtered out.

Styling: font size, weight, position (top/center/bottom), text color, background color with opacity, max words per line for wrapping. The renderer shows 2 lines at a time and scrolls through longer segments.

Export options: burned into the video, or as SRT/VTT sidecar files.

## Undo/redo

50-snapshot system. Each snapshot captures the full `EditorStateData` -- every setting, every region, every keyframe. Snapshots are diffed to generate human-readable change descriptions like "Trim range 0:00-1:23 to 0:05-1:20" or "Camera region added".

Operations: push (truncates redo stack), undo, redo, jump to specific entry. History persists in the .frm project bundle as `history.json`, so reopening a project restores the full edit history.

## Auto-save

EditorState debounces saves with a 1-second delay. Every change schedules a save, but only the last one within any 1-second window actually writes to disk. The full editor state (including history) goes into `project.json` inside the .frm bundle.
