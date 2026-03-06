# Export pipeline

Export turns a .frm project into a final video file. The whole process runs through `VideoCompositor`, a static enum that orchestrates composition setup, per-frame rendering, audio mixing, and file output.

## Entry point

`VideoCompositor.export()` takes 40+ parameters -- the recording result, trim range, all editor settings, all regions, cursor/zoom snapshots, caption segments, export settings, and a progress callback. It returns the URL of the finished file.

## Decision: compositor or passthrough

Not every export needs per-frame rendering. If the recording has no visual effects (no background, no webcam, no cursor overlay, no zoom, no captions, no padding, no corner radius, and the codec matches), the export can skip the compositor and just do audio mixing with a trim. This is faster.

Otherwise, the compositor renders every frame through `CameraVideoCompositor`.

## Composition setup

1. Create an AVMutableComposition.
2. Load the screen video track, get natural size and time range.
3. Clamp the trim range to valid bounds.
4. If video regions exist, build a segment map from source time to composition time. Insert segments into the composition track. Otherwise, use the full trim range as a single segment.

## Preprocessing

Before rendering starts, two optional steps happen:

**Noise reduction** -- if enabled and mic audio exists, run the mic through RNNoiseProcessor. This converts to 48kHz mono, processes 480-sample frames through rnnoise, blends dry/wet based on intensity (0-0.5 = single pass partial wet, 0.5-1.0 = double pass full wet), and writes the result as AAC. Cached in the project bundle as `denoised-mic.m4a` to avoid reprocessing.

**Click sounds** -- if enabled and cursor data exists, filter clicks that fall within active audio regions, remap to composition timeline if video regions changed the timing, and generate an audio file with ClickSoundGenerator.

## Canvas sizing

1. Apply the canvas aspect ratio (or keep the recording's native ratio).
2. Add padding (scales both dimensions proportionally).
3. Fit to the export resolution (4K, 1080p, 720p, or original).
4. Calculate the camera PiP rect with proper scaling.

## Per-frame rendering

`CameraVideoCompositor` implements the AVVideoCompositing protocol. For each frame, it gets a `CompositionInstruction` containing all rendering parameters and runs this pipeline:

1. **Background** -- fill the canvas with solid color, gradient, or image (respecting fill mode).
2. **Screen video** -- draw the recording into the padded area with aspect fitting. Apply corner radius clipping and shadow. Handle screen transition effects if video regions define them.
3. **Zoom** -- if active, query ZoomTimeline for the zoom rect at current time. If cursor-follow is on, adjust pan to center on cursor. Crop and scale the screen content.
4. **Webcam** -- check camera regions for the current time. If hidden, skip. If fullscreen, render the webcam filling the canvas. Otherwise, render as PiP with the active layout and styling. Apply entry/exit transitions (fade/scale/slide with interpolated progress). Run person segmentation if background replacement is configured.
5. **Cursor** -- look up cursor position from the metadata snapshot. Draw the selected style with fill/stroke colors at the configured size. Render click highlights (fading rings) for any clicks within a 0.4s window.
6. **Spotlight** -- if active at current time, create a circular mask centered on cursor with feathered edges. Dim everything outside.
7. **Captions** -- find the caption segment at current time. Word-wrap per max words per line, render 2 lines, scroll through longer segments. Draw background box if enabled.

All rendering uses CoreGraphics with 16-bit float pixel buffers for precision.

## Audio mixing

`VideoCompositor+Audio` collects audio sources:

- System audio (if present and volume > 0)
- Mic audio, or its noise-reduced version (if present and volume > 0)
- Click sound track (if generated)

For each source, it creates a composition audio track and inserts time ranges matching the audio regions. Volume is applied per-track through AVAudioMixInputParameters.

## Export modes

**Parallel** (`VideoCompositor+ParallelExport`) -- splits the timeline into chunks and renders frames across multiple CPU cores. Faster on modern hardware with many cores.

**Normal/Manual** (`VideoCompositor+ManualExport`) -- traditional single-threaded export using AVAssetExportSession with the custom video compositor.

Both modes report progress (0.0-1.0) and estimated time remaining through the callback.

## GIF export

`VideoCompositor+GIFExport` uses the gifski C library (static build in `Libraries/gifski/`). Renders frames at the configured FPS and resolution, feeds them to gifski frame-by-frame, and writes the output file. Quality presets: low (50), medium (70), high (90), maximum (100).

## Formats and codecs

| Format | Codecs |
| ------ | ------ |
| MP4 | H.264, H.265 (HEVC) |
| MOV | H.264, H.265, ProRes 422, ProRes 4444 |
| GIF | gifski |

Resolution options: original, 4K (3840px), 1080p (1920px), 720p (1280px).

FPS options: original, 24, 30, 40, 50, 60.

Audio bitrate: 128, 192, 256, 320 kbps.

## Platform presets

Presets configure format, FPS, resolution, codec, and audio bitrate in one click:

- **YouTube**: MP4, original FPS, 1080p, H.265, 320kbps
- **Twitter/X**: MP4, 30fps, 1080p, H.264, 256kbps
- **TikTok**: MP4, 30fps, 1080p, H.264, 256kbps
- **Instagram**: MP4, 30fps, 1080p, H.264, 256kbps
- **Discord**: MP4, 30fps, 720p, H.264, 192kbps
- **ProRes**: MOV, original FPS, original resolution, ProRes 422, 320kbps
- **GIF**: GIF, 24fps, 720p

## Caption export

Three options:

- **Burn-in** -- rendered directly into the video frames by the compositor
- **SRT** -- SubRip subtitle file alongside the video
- **VTT** -- WebVTT subtitle file alongside the video

When video regions compress the timeline, caption timestamps are remapped to match.
