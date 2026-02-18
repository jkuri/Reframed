import Foundation

struct HistoryEntry: Codable, Sendable {
  var snapshot: EditorStateData
  var timestamp: Date
}

struct HistoryData: Codable, Sendable {
  var entries: [HistoryEntry]
  var currentIndex: Int
}

@MainActor
@Observable
final class History {
  private(set) var entries: [HistoryEntry] = []
  private(set) var currentIndex: Int = -1

  private let maxSnapshots = 50

  var canUndo: Bool { currentIndex > 0 }
  var canRedo: Bool { currentIndex < entries.count - 1 }

  func pushSnapshot(_ snapshot: EditorStateData) {
    if currentIndex < entries.count - 1 {
      entries.removeSubrange((currentIndex + 1)...)
    }
    entries.append(HistoryEntry(snapshot: snapshot, timestamp: Date()))
    currentIndex = entries.count - 1
    if entries.count > maxSnapshots {
      let excess = entries.count - maxSnapshots
      entries.removeFirst(excess)
      currentIndex -= excess
    }
  }

  func undo() -> EditorStateData? {
    guard canUndo else { return nil }
    currentIndex -= 1
    return entries[currentIndex].snapshot
  }

  func redo() -> EditorStateData? {
    guard canRedo else { return nil }
    currentIndex += 1
    return entries[currentIndex].snapshot
  }

  func jumpTo(index: Int) -> EditorStateData? {
    guard index >= 0 && index < entries.count else { return nil }
    currentIndex = index
    return entries[index].snapshot
  }

  func load(from data: HistoryData) {
    entries = data.entries
    currentIndex = min(data.currentIndex, entries.count - 1)
    if entries.count > maxSnapshots {
      let excess = entries.count - maxSnapshots
      entries.removeFirst(excess)
      currentIndex -= excess
    }
    if currentIndex < 0 && !entries.isEmpty {
      currentIndex = 0
    }
  }

  func toData() -> HistoryData {
    HistoryData(entries: entries, currentIndex: currentIndex)
  }

  static func describeChanges(from old: EditorStateData, to new: EditorStateData) -> [String] {
    var changes: [String] = []

    if old.trimStartSeconds != new.trimStartSeconds || old.trimEndSeconds != new.trimEndSeconds {
      changes.append(
        "Trim range \(formatTime(old.trimStartSeconds))–\(formatTime(old.trimEndSeconds)) → \(formatTime(new.trimStartSeconds))–\(formatTime(new.trimEndSeconds))"
      )
    }

    if old.backgroundStyle != new.backgroundStyle {
      changes.append("Background set to \(describeBackground(new.backgroundStyle))")
    }

    if old.backgroundImageFillMode != new.backgroundImageFillMode {
      let newMode = (new.backgroundImageFillMode ?? .fill).label.lowercased()
      changes.append("Background image fill mode set to \(newMode)")
    }

    if old.canvasAspect != new.canvasAspect {
      let newLabel = (new.canvasAspect ?? .original).label
      changes.append("Canvas aspect ratio set to \(newLabel)")
    }

    if old.padding != new.padding {
      changes.append("Padding set to \(Int(new.padding * 100))%")
    }

    if old.videoCornerRadius != new.videoCornerRadius {
      changes.append("Video corner radius set to \(Int(new.videoCornerRadius))px")
    }

    if old.cameraAspect != new.cameraAspect {
      let newLabel = (new.cameraAspect ?? .original).label
      changes.append("Camera aspect ratio set to \(newLabel)")
    }

    if old.cameraCornerRadius != new.cameraCornerRadius {
      changes.append("Camera corner radius set to \(Int(new.cameraCornerRadius))px")
    }

    if old.cameraBorderWidth != new.cameraBorderWidth {
      changes.append("Camera border width set to \(String(format: "%.1f", new.cameraBorderWidth))px")
    }

    if old.cameraBorderColor != new.cameraBorderColor {
      changes.append("Camera border color updated")
    }

    if old.videoShadow != new.videoShadow {
      let val = Int(new.videoShadow ?? 0)
      changes.append(val == 0 ? "Video shadow removed" : "Video shadow set to \(val)")
    }

    if old.cameraShadow != new.cameraShadow {
      let val = Int(new.cameraShadow ?? 0)
      changes.append(val == 0 ? "Camera shadow removed" : "Camera shadow set to \(val)")
    }

    if old.cameraMirrored != new.cameraMirrored {
      let enabled = (new.cameraMirrored ?? false)
      changes.append(enabled ? "Camera mirror enabled" : "Camera mirror disabled")
    }

    if old.cameraLayout != new.cameraLayout {
      changes.append("Camera repositioned")
    }

    if old.webcamEnabled != new.webcamEnabled {
      let enabled = (new.webcamEnabled ?? true)
      changes.append(enabled ? "Webcam enabled" : "Webcam disabled")
    }

    if old.cursorSettings != new.cursorSettings {
      describeCursorChanges(from: old.cursorSettings, to: new.cursorSettings, into: &changes)
    }

    if old.zoomSettings != new.zoomSettings {
      describeZoomChanges(from: old.zoomSettings, to: new.zoomSettings, into: &changes)
    }

    if old.animationSettings != new.animationSettings {
      describeAnimationChanges(from: old.animationSettings, to: new.animationSettings, into: &changes)
    }

    if old.audioSettings != new.audioSettings {
      describeAudioChanges(from: old.audioSettings, to: new.audioSettings, into: &changes)
    }

    if old.systemAudioRegions != new.systemAudioRegions {
      let oldCount = old.systemAudioRegions?.count ?? 0
      let newCount = new.systemAudioRegions?.count ?? 0
      if newCount > oldCount {
        changes.append("System audio region added")
      } else if newCount < oldCount {
        changes.append("System audio region removed")
      } else {
        changes.append("System audio region adjusted")
      }
    }

    if old.micAudioRegions != new.micAudioRegions {
      let oldCount = old.micAudioRegions?.count ?? 0
      let newCount = new.micAudioRegions?.count ?? 0
      if newCount > oldCount {
        changes.append("Mic audio region added")
      } else if newCount < oldCount {
        changes.append("Mic audio region removed")
      } else {
        changes.append("Mic audio region adjusted")
      }
    }

    if old.cameraFullscreenRegions != new.cameraFullscreenRegions {
      let oldCount = old.cameraFullscreenRegions?.count ?? 0
      let newCount = new.cameraFullscreenRegions?.count ?? 0
      if newCount > oldCount {
        changes.append("Camera fullscreen region added")
      } else if newCount < oldCount {
        changes.append("Camera fullscreen region removed")
      } else {
        changes.append("Camera fullscreen region adjusted")
      }
    }

    return changes
  }

  private static func formatTime(_ seconds: Double) -> String {
    let mins = Int(seconds) / 60
    let secs = seconds - Double(mins * 60)
    if mins > 0 {
      return String(format: "%d:%04.1f", mins, secs)
    }
    return String(format: "%.1fs", secs)
  }

  private static func describeBackground(_ style: BackgroundStyle) -> String {
    switch style {
    case .none:
      return "none"
    case .gradient(let id):
      if let preset = GradientPresets.preset(for: id) {
        return "\(preset.name) gradient"
      }
      return "gradient"
    case .solidColor:
      return "solid color"
    case .image:
      return "image"
    }
  }

  private static func describeCursorChanges(
    from old: CursorSettingsData?,
    to new: CursorSettingsData?,
    into changes: inout [String]
  ) {
    let oldShow = old?.showCursor ?? true
    let newShow = new?.showCursor ?? true
    if oldShow != newShow {
      changes.append(newShow ? "Cursor enabled" : "Cursor disabled")
      return
    }

    if old?.cursorStyleRaw != new?.cursorStyleRaw {
      let style = CursorStyle(rawValue: new?.cursorStyleRaw ?? 0) ?? .defaultArrow
      changes.append("Cursor style set to \(style.label)")
    }
    if old?.cursorSize != new?.cursorSize {
      changes.append("Cursor size set to \(Int(new?.cursorSize ?? 24))px")
    }
    if old?.showClickHighlights != new?.showClickHighlights {
      let enabled = new?.showClickHighlights ?? false
      changes.append(enabled ? "Click highlights enabled" : "Click highlights disabled")
    }
    if old?.clickHighlightColor != new?.clickHighlightColor
      || old?.clickHighlightSize != new?.clickHighlightSize
    {
      if old?.showClickHighlights == new?.showClickHighlights {
        if old?.clickHighlightColor != new?.clickHighlightColor {
          changes.append("Click highlight color updated")
        }
        if old?.clickHighlightSize != new?.clickHighlightSize {
          changes.append(
            "Click highlight size set to \(Int(new?.clickHighlightSize ?? 36))px"
          )
        }
      }
    }
  }

  private static func describeZoomChanges(
    from old: ZoomSettingsData?,
    to new: ZoomSettingsData?,
    into changes: inout [String]
  ) {
    if old?.zoomEnabled != new?.zoomEnabled {
      let enabled = new?.zoomEnabled ?? false
      changes.append(enabled ? "Zoom enabled" : "Zoom disabled")
    }
    if old?.autoZoomEnabled != new?.autoZoomEnabled {
      let enabled = new?.autoZoomEnabled ?? false
      changes.append(enabled ? "Auto zoom enabled" : "Auto zoom disabled")
    }
    if old?.zoomLevel != new?.zoomLevel {
      changes.append(
        "Zoom level set to \(String(format: "%.1f", new?.zoomLevel ?? 2.0))x"
      )
    }
    if old?.keyframes != new?.keyframes {
      let oldCount = old?.keyframes.count ?? 0
      let newCount = new?.keyframes.count ?? 0
      if newCount > oldCount {
        changes.append("Zoom keyframe added")
      } else if newCount < oldCount {
        changes.append("Zoom keyframe removed")
      } else {
        changes.append("Zoom keyframe adjusted")
      }
    }
  }

  private static func describeAnimationChanges(
    from old: AnimationSettingsData?,
    to new: AnimationSettingsData?,
    into changes: inout [String]
  ) {
    if old?.cursorMovementEnabled != new?.cursorMovementEnabled {
      let enabled = new?.cursorMovementEnabled ?? false
      changes.append(enabled ? "Cursor smoothing enabled" : "Cursor smoothing disabled")
    }
    if old?.cursorMovementSpeed != new?.cursorMovementSpeed {
      let speed = new?.cursorMovementSpeed ?? .medium
      changes.append("Cursor smoothing speed set to \(speed.label)")
    }
  }

  private static func describeAudioChanges(
    from old: AudioSettingsData?,
    to new: AudioSettingsData?,
    into changes: inout [String]
  ) {
    if old?.systemAudioVolume != new?.systemAudioVolume
      || old?.systemAudioMuted != new?.systemAudioMuted
    {
      if new?.systemAudioMuted == true && old?.systemAudioMuted != true {
        changes.append("System audio muted")
      } else if new?.systemAudioMuted != true && old?.systemAudioMuted == true {
        changes.append("System audio unmuted")
      } else {
        let newVol = Int((new?.systemAudioVolume ?? 1.0) * 100)
        changes.append("System audio volume set to \(newVol)%")
      }
    }
    if old?.micAudioVolume != new?.micAudioVolume || old?.micAudioMuted != new?.micAudioMuted {
      if new?.micAudioMuted == true && old?.micAudioMuted != true {
        changes.append("Mic audio muted")
      } else if new?.micAudioMuted != true && old?.micAudioMuted == true {
        changes.append("Mic audio unmuted")
      } else {
        let newVol = Int((new?.micAudioVolume ?? 1.0) * 100)
        changes.append("Mic audio volume set to \(newVol)%")
      }
    }
    if old?.micNoiseReductionEnabled != new?.micNoiseReductionEnabled {
      let enabled = new?.micNoiseReductionEnabled ?? false
      changes.append(enabled ? "Noise reduction enabled" : "Noise reduction disabled")
    }
    if old?.micNoiseReductionIntensity != new?.micNoiseReductionIntensity {
      changes.append(
        "Noise reduction intensity set to \(Int((new?.micNoiseReductionIntensity ?? 0.5) * 100))%"
      )
    }
  }
}
