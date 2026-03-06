# .frm project format

Reframed saves recordings as `.frm` bundles -- directories that macOS treats as opaque files. The UTI is `eu.jkuri.reframed.project`.

## Bundle structure

```
recording-2024-12-06-143022.frm/
├── project.json
├── screen.mp4            (or screen.mov for ProRes)
├── webcam.mp4            (optional)
├── system-audio.m4a      (optional)
├── mic-audio.m4a         (optional)
├── denoised-mic.m4a      (optional, cached noise-reduced mic)
├── cursor-metadata.json  (optional)
└── history.json          (undo/redo snapshots)
```

The screen recording is always present. Everything else depends on what was enabled during capture.

## project.json

Contains `ProjectMetadata` with two sections: recording info and editor state.

### Recording info

```json
{
  "version": 1,
  "name": "recording-2024-12-06-143022",
  "createdAt": "2024-12-06T14:30:22Z",
  "fps": 60,
  "screenSize": {"width": 1920, "height": 1080},
  "webcamSize": {"width": 1280, "height": 720},
  "hasSystemAudio": true,
  "hasMicrophoneAudio": true,
  "hasCursorMetadata": true,
  "hasWebcam": true,
  "captureMode": "selectedArea",
  "captureQuality": "standard"
}
```

### Editor state

The `editorState` field holds the full `EditorStateData` snapshot:

- **Trim**: `trimStartSeconds`, `trimEndSeconds`
- **Canvas**: aspect ratio, padding, video corner radius, video shadow
- **Background**: style (none/gradient/solid/image), image fill mode, image filename
- **Camera layout**: position, size, corner radius, border, shadow, mirror, aspect
- **Camera background**: style, blur radius, image filename
- **Camera fullscreen**: fill mode, aspect
- **Camera regions**: array of `{id, start, end, type, customLayout, transitions}`
- **Audio regions**: system and mic arrays of `{id, start, end}`
- **Video regions**: array of `{id, start, end}`
- **Spotlight regions**: array of `{id, start, end, radius, dimOpacity, edgeSoftness}`
- **Cursor settings**: style, size, colors, click highlights, click sounds, spotlight params
- **Zoom settings**: enabled, auto-enabled, follow-cursor, level, transition speed, dwell threshold, keyframes array
- **Cursor movement**: enabled, speed preset
- **Audio settings**: volumes, mute flags, noise reduction enabled/intensity
- **Caption settings**: enabled, font size/weight, colors, position, words per line, model, language, audio source
- **Caption segments**: array of `{id, start, end, text, words}`

All optional sections only appear if their corresponding data exists. The JSON decoder uses lenient defaults, so older projects missing newer fields still load fine.

## cursor-metadata.json

120Hz cursor position data, click events, and keystroke events. See [recording.md](recording.md#output-format) for the full format.

Coordinates are normalized to 0.0-1.0 within the capture area. Timestamps are aligned to the video timeline (offset-corrected after recording).

## history.json

Array of editor state snapshots for undo/redo, up to 50 entries. Each entry has a timestamp. Restoring a project also restores the edit history so you can keep undoing/redoing from where you left off.

## Storage location

Projects are saved to the configured project folder (default: `~/Reframed`). The folder is set in ConfigService and can be changed in settings.

## Reopening projects

Double-clicking a .frm bundle (or opening from the menu bar's recent projects list) loads the project metadata, reconstructs EditorState from the saved snapshot, loads cursor metadata if present, and opens the editor window. The recording files are read directly from the bundle during preview and export.
