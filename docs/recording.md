# Recording pipeline

This covers how Reframed captures screen content, audio, webcam, and cursor data, and how everything ends up synchronized in the output files.

## Capture modes

Reframed has four ways to start a recording:

**Entire screen** -- captures the full display. The user clicks a screen in the overlay to select it, then a countdown starts.

**Selected window** -- highlights the window under the cursor as you move the mouse. WindowSelectionCoordinator queries the SCWindow list every 2 seconds and uses coordinate flipping (AppKit bottom-left to ScreenCaptureKit top-left) to match mouse position to windows.

**Selected area** -- shows a full-screen transparent overlay with a crosshair cursor. Drag to draw a rectangle, then adjust with 8 resize handles at corners and midpoints. If "remember last selection" is enabled, the previous rect is restored.

**iOS device** -- captures a connected iPhone or iPad through AVCaptureDevice. Shows a device preview window with a countdown overlay.

## How a recording starts

1. User picks a mode. SessionState transitions to `.selecting`.
2. Selection overlays appear (one per display for area/screen modes).
3. User confirms a target. SessionState transitions to `.countdown(remaining:)`.
4. Countdown runs (0, 3, 5, or 10 seconds, configurable). Overlays hide, recording border appears.
5. SessionState creates a `RecordingCoordinator` actor and calls `startRecording()`.
6. The coordinator sets up ScreenCaptureSession, track writers, and optional captures (webcam, mic, system audio, cursor metadata).
7. State transitions to `.recording(startedAt:)`.

## ScreenCaptureSession

Wraps SCStream. Configures the stream with:

- Source rect matching the selected region (adjusted for display scale)
- Output dimensions doubled for Retina if enabled
- Minimum frame interval set 20% higher than target FPS to avoid drops
- Pixel format: 10-bit YCbCr for standard quality, 32-bit BGRA for ProRes
- `showsCursor = false` when cursor metadata recording is on (cursor is rendered in the compositor instead)
- Queue depth of 8 frames

For region capture, uses `SCContentFilter(display:excludingApplications:exceptingWindows:)`. For window capture, uses `SCContentFilter(desktopIndependentWindow:)`.

### Idle frame handling

When nothing changes on screen, ScreenCaptureKit sends `.idle` status frames instead of new pixel data. The session duplicates the last CVPixelBuffer with a new presentation timestamp to keep the frame rate steady. Without this, the output video would have variable frame timing.

## Track writers

**VideoTrackWriter** (actor) wraps an AVAssetWriter with a single video input. Runs on a dedicated high-priority DispatchQueue. On the first sample, it registers with SharedRecordingClock, starts the asset writer session, and begins appending buffers. Tracks dropped frames when the input isn't ready.

**AudioTrackWriter** (actor) same pattern but for audio. Uses Apple Lossless (ALAC) at 48kHz. Implements drift correction -- every 100 buffers, it checks the audio PTS against the video PTS and corrects if drift exceeds 5ms. Also computes peak audio level in real time for the UI meters.

### Encoding settings

Three capture quality levels:

| Quality | Codec | Container | Bitrate (screen) |
| ------- | ----- | --------- | ----------------- |
| Standard | HEVC Main10 | MP4 | width * height * 5 |
| High | ProRes 422 | MOV | frame-based |
| Very High | ProRes 4444 | MOV | frame-based |

Webcam uses the same codec at a lower bitrate multiplier (* 2 instead of * 5).

Audio is always ALAC lossless at 48kHz, regardless of quality setting.

## Clock synchronization

Different capture sources (screen, webcam, mic, system audio) start producing samples at different times. SharedRecordingClock solves this.

It's initialized with the number of expected streams. Each track writer calls `registerStream(firstPTS:)` when it receives its first sample. Once all streams have registered, the clock sets a reference time equal to the maximum of all first PTS values. From then on:

```
adjustedPTS = rawPTS - referenceTime - pauseOffset
```

Only samples with adjustedPTS >= 0 get written. This means all tracks start at time zero in the output file, regardless of which hardware source started producing data first.

## Webcam capture

Uses AVCaptureSession with a video data output. Format selection picks the highest resolution that fits under the configured maximum (720p/1080p/4K) and supports the target FPS. Pixel format is 8-bit YCbCr biplanar.

The webcam session can be reused across recordings without restarting the hardware.

## Microphone capture

Also uses AVCaptureSession with an audio data output. If the device's native sample rate isn't 48kHz, resampling is applied. Verifies the device by waiting for the first sample (5 second timeout).

## System audio capture

Uses a separate ScreenCaptureKit stream configured for audio only. The trick: it still needs a minimal video configuration (2x2 pixels at 1 FPS), but the dummy video frames are discarded on a background queue. The stream captures all system audio except the app's own output (`excludesCurrentProcessAudio = true`).

Output is 48kHz stereo.

## Cursor metadata

CursorMetadataRecorder runs a DispatchSourceTimer at 8ms intervals (~120Hz after scheduling jitter). Each tick reads `NSEvent.mouseLocation` and `NSEvent.pressedMouseButtons`, converts screen coordinates to normalized 0.0-1.0 values within the capture region, and stores the sample.

MouseClickMonitor adds global event monitors for left/right mouse clicks and keystrokes (keyDown/keyUp with key codes and modifiers). Only records when not paused.

### Timestamp alignment

The cursor recorder starts its own clock when recording begins. After recording stops, the video clock's reference time is used to calculate an offset:

```
offset = cursorStartTime - videoReferenceTime
```

All cursor timestamps get shifted by this offset before writing the JSON file, so cursor data lines up with the video timeline.

### Output format

Saved as `cursor-metadata.json` in the .frm bundle:

```json
{
  "version": 1,
  "captureAreaWidth": 1920.0,
  "captureAreaHeight": 1080.0,
  "displayScale": 2.0,
  "sampleRateHz": 120,
  "samples": [{"t": 0.008, "x": 0.5, "y": 0.3, "p": false}],
  "clicks": [{"t": 1.234, "x": 0.5, "y": 0.3, "button": 0}],
  "keystrokes": [{"t": 2.0, "keyCode": 0, "modifiers": 0, "isDown": true}]
}
```

## Pause and resume

Pausing sets a flag on all writers and capture sources. Queued appends check the flag and skip if paused. The pause start time is recorded.

On resume, the pause duration is calculated and added to a cumulative `pauseOffset` (CMTime). All future PTS adjustments subtract this offset, so the output file has no gaps or black frames from paused periods.

The cursor metadata recorder does the same thing independently with its own `totalPauseOffset`.

## After recording stops

1. All writers finish asynchronously.
2. Cursor metadata timestamps are adjusted and written to a temp JSON file.
3. RecordingCoordinator returns a `RecordingResult` with URLs to all output files plus metadata (screen size, webcam size, FPS, capture quality).
4. SessionState passes the result to `ReframedProject.create()`, which bundles everything into a `.frm` directory.
5. The editor window opens with the project loaded.

## Audio level monitoring

During recording, SessionState polls `RecordingCoordinator.getAudioLevels()` every 100ms in a Task loop. The coordinator reads peak levels from each audio writer. These drive the real-time level meters in the toolbar UI.
