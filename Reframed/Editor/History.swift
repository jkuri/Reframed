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

  private typealias ChangeRule = (EditorStateData, EditorStateData) -> [String]

  private static func prop<V: Equatable>(
    _ keyPath: KeyPath<EditorStateData, V>,
    _ describe: @escaping (V) -> String
  ) -> ChangeRule {
    { old, new in
      guard old[keyPath: keyPath] != new[keyPath: keyPath] else { return [] }
      return [describe(new[keyPath: keyPath])]
    }
  }

  private static func toggle(
    _ keyPath: KeyPath<EditorStateData, Bool?>,
    default defaultValue: Bool,
    on: String,
    off: String
  ) -> ChangeRule {
    { old, new in
      guard old[keyPath: keyPath] != new[keyPath: keyPath] else { return [] }
      return [(new[keyPath: keyPath] ?? defaultValue) ? on : off]
    }
  }

  private static func sub<S, V: Equatable>(
    _ parentPath: KeyPath<EditorStateData, S?>,
    _ childPath: KeyPath<S, V>,
    default defaultValue: V,
    _ describe: @escaping (V) -> String
  ) -> ChangeRule {
    { old, new in
      let oldVal: V
      let newVal: V
      if let parent = old[keyPath: parentPath] {
        oldVal = parent[keyPath: childPath]
      } else {
        oldVal = defaultValue
      }
      if let parent = new[keyPath: parentPath] {
        newVal = parent[keyPath: childPath]
      } else {
        newVal = defaultValue
      }
      guard oldVal != newVal else { return [] }
      return [describe(newVal)]
    }
  }

  private static func subToggle<S>(
    _ parentPath: KeyPath<EditorStateData, S?>,
    _ childPath: KeyPath<S, Bool>,
    default defaultValue: Bool,
    on: String,
    off: String
  ) -> ChangeRule {
    { old, new in
      let oldVal: Bool
      let newVal: Bool
      if let parent = old[keyPath: parentPath] {
        oldVal = parent[keyPath: childPath]
      } else {
        oldVal = defaultValue
      }
      if let parent = new[keyPath: parentPath] {
        newVal = parent[keyPath: childPath]
      } else {
        newVal = defaultValue
      }
      guard oldVal != newVal else { return [] }
      return [newVal ? on : off]
    }
  }

  private static func regions<R: Equatable>(
    _ keyPath: KeyPath<EditorStateData, [R]?>,
    added: String,
    removed: String,
    adjusted: String
  ) -> ChangeRule {
    { old, new in
      let o = old[keyPath: keyPath]
      let n = new[keyPath: keyPath]
      guard o != n else { return [] }
      let oldCount = o?.count ?? 0
      let newCount = n?.count ?? 0
      if newCount > oldCount { return [added] }
      if newCount < oldCount { return [removed] }
      return [adjusted]
    }
  }

  private static let rules: [ChangeRule] = [
    { old, new in
      guard old.trimStartSeconds != new.trimStartSeconds || old.trimEndSeconds != new.trimEndSeconds
      else { return [] }
      return [
        "Trim range \(formatCompactTime(seconds: old.trimStartSeconds))–\(formatCompactTime(seconds: old.trimEndSeconds)) → \(formatCompactTime(seconds: new.trimStartSeconds))–\(formatCompactTime(seconds: new.trimEndSeconds))"
      ]
    },

    prop(\.backgroundStyle) { "Background set to \(describeBackground($0))" },
    prop(\.backgroundImageFillMode) {
      "Background image fill mode set to \(($0 ?? .fill).label.lowercased())"
    },

    prop(\.canvasAspect) { "Canvas aspect ratio set to \(($0 ?? .original).label)" },
    prop(\.padding) { "Padding set to \(Int($0 * 100))%" },

    prop(\.videoCornerRadius) { "Video corner radius set to \(Int($0))px" },
    prop(\.videoShadow) {
      let val = Int($0 ?? 0)
      return val == 0 ? "Video shadow removed" : "Video shadow set to \(val)"
    },

    prop(\.cameraAspect) { "Camera aspect ratio set to \(($0 ?? .original).label)" },
    prop(\.cameraCornerRadius) { "Camera corner radius set to \(Int($0))px" },
    prop(\.cameraBorderWidth) { "Camera border width set to \(String(format: "%.1f", $0))px" },
    prop(\.cameraBorderColor) { _ in "Camera border color updated" },
    prop(\.cameraShadow) {
      let val = Int($0 ?? 0)
      return val == 0 ? "Camera shadow removed" : "Camera shadow set to \(val)"
    },
    toggle(\.cameraMirrored, default: false, on: "Camera mirror enabled", off: "Camera mirror disabled"),
    prop(\.cameraFullscreenFillMode) {
      "Camera fullscreen fill mode set to \(($0 ?? .fit).label.lowercased())"
    },
    prop(\.cameraFullscreenAspect) {
      "Camera fullscreen aspect ratio set to \(($0 ?? .original).label)"
    },
    prop(\.cameraLayout) { _ in "Camera repositioned" },
    toggle(\.webcamEnabled, default: true, on: "Webcam enabled", off: "Webcam disabled"),
    prop(\.cameraBackgroundStyle) { "Camera background set to \(describeCameraBackground($0))" },

    { old, new in
      guard old.cursorSettings != new.cursorSettings else { return [] }
      let oldShow = old.cursorSettings?.showCursor ?? true
      let newShow = new.cursorSettings?.showCursor ?? true
      if oldShow != newShow {
        return [newShow ? "Cursor enabled" : "Cursor disabled"]
      }
      let subRules: [ChangeRule] = [
        sub(\.cursorSettings, \.cursorStyleRaw, default: 0) {
          let style = CursorStyle(rawValue: $0) ?? .centerDefault
          return "Cursor style set to \(style.label)"
        },
        sub(\.cursorSettings, \.cursorSize, default: CGFloat(24)) { "Cursor size set to \(Int($0))px" },
        subToggle(
          \.cursorSettings,
          \.showClickHighlights,
          default: true,
          on: "Click highlights enabled",
          off: "Click highlights disabled"
        ),
        { old, new in
          guard
            (old.cursorSettings?.showClickHighlights ?? true)
              == (new.cursorSettings?.showClickHighlights ?? true)
          else { return [] }
          var results: [String] = []
          if old.cursorSettings?.clickHighlightColor != new.cursorSettings?.clickHighlightColor {
            results.append("Click highlight color updated")
          }
          if old.cursorSettings?.clickHighlightSize != new.cursorSettings?.clickHighlightSize {
            results.append(
              "Click highlight size set to \(Int(new.cursorSettings?.clickHighlightSize ?? 36))px"
            )
          }
          return results
        },
        sub(\.cursorSettings, \.cursorFillColor, default: nil as CodableColor?) { _ in
          "Cursor fill color updated"
        },
        sub(\.cursorSettings, \.cursorStrokeColor, default: nil as CodableColor?) { _ in
          "Cursor stroke color updated"
        },
        subToggle(
          \.cursorSettings,
          \.spotlightEnabled,
          default: false,
          on: "Spotlight enabled",
          off: "Spotlight disabled"
        ),
        sub(\.cursorSettings, \.spotlightRadius, default: CGFloat(200)) {
          "Spotlight radius set to \(Int($0))px"
        },
        sub(\.cursorSettings, \.spotlightDimOpacity, default: CGFloat(0.6)) {
          "Spotlight dim opacity set to \(Int($0 * 100))%"
        },
        sub(\.cursorSettings, \.spotlightEdgeSoftness, default: CGFloat(50)) {
          "Spotlight edge softness set to \(Int($0))px"
        },
        subToggle(
          \.cursorSettings,
          \.clickSoundEnabled,
          default: false,
          on: "Click sound enabled",
          off: "Click sound disabled"
        ),
        sub(\.cursorSettings, \.clickSoundVolume, default: Float(0.5)) {
          "Click sound volume set to \(Int($0 * 100))%"
        },
        sub(\.cursorSettings, \.clickSoundStyleRaw, default: 0) {
          let style = ClickSoundStyle(rawValue: $0) ?? .click
          return "Click sound style set to \(style.label)"
        },
      ]
      return subRules.flatMap { $0(old, new) }
    },

    { old, new in
      guard old.zoomSettings != new.zoomSettings else { return [] }
      let subRules: [ChangeRule] = [
        subToggle(\.zoomSettings, \.zoomEnabled, default: false, on: "Zoom enabled", off: "Zoom disabled"),
        subToggle(
          \.zoomSettings,
          \.autoZoomEnabled,
          default: false,
          on: "Auto zoom enabled",
          off: "Auto zoom disabled"
        ),
        subToggle(
          \.zoomSettings,
          \.zoomFollowCursor,
          default: true,
          on: "Zoom follow cursor enabled",
          off: "Zoom follow cursor disabled"
        ),
        sub(\.zoomSettings, \.zoomLevel, default: 2.0) {
          "Zoom level set to \(String(format: "%.1f", $0))x"
        },
        sub(\.zoomSettings, \.transitionDuration, default: 0.3) {
          "Zoom transition speed set to \(String(format: "%.1f", $0))s"
        },
        sub(\.zoomSettings, \.dwellThreshold, default: 0.5) {
          "Zoom dwell threshold set to \(String(format: "%.1f", $0))s"
        },
        { old, new in
          let o = old.zoomSettings?.keyframes
          let n = new.zoomSettings?.keyframes
          guard o != n else { return [] }
          let oldCount = o?.count ?? 0
          let newCount = n?.count ?? 0
          if newCount > oldCount { return ["Zoom keyframe added"] }
          if newCount < oldCount { return ["Zoom keyframe removed"] }
          return ["Zoom keyframe adjusted"]
        },
      ]
      return subRules.flatMap { $0(old, new) }
    },

    { old, new in
      guard old.animationSettings != new.animationSettings else { return [] }
      let subRules: [ChangeRule] = [
        subToggle(
          \.animationSettings,
          \.cursorMovementEnabled,
          default: false,
          on: "Cursor smoothing enabled",
          off: "Cursor smoothing disabled"
        ),
        sub(\.animationSettings, \.cursorMovementSpeed, default: .medium) {
          "Cursor smoothing speed set to \($0.label)"
        },
      ]
      return subRules.flatMap { $0(old, new) }
    },

    { old, new in
      guard old.audioSettings != new.audioSettings else { return [] }
      var results: [String] = []
      let o = old.audioSettings
      let n = new.audioSettings
      if o?.systemAudioVolume != n?.systemAudioVolume || o?.systemAudioMuted != n?.systemAudioMuted {
        if n?.systemAudioMuted == true && o?.systemAudioMuted != true {
          results.append("System audio muted")
        } else if n?.systemAudioMuted != true && o?.systemAudioMuted == true {
          results.append("System audio unmuted")
        } else {
          results.append("System audio volume set to \(Int((n?.systemAudioVolume ?? 1.0) * 100))%")
        }
      }
      if o?.micAudioVolume != n?.micAudioVolume || o?.micAudioMuted != n?.micAudioMuted {
        if n?.micAudioMuted == true && o?.micAudioMuted != true {
          results.append("Mic audio muted")
        } else if n?.micAudioMuted != true && o?.micAudioMuted == true {
          results.append("Mic audio unmuted")
        } else {
          results.append("Mic audio volume set to \(Int((n?.micAudioVolume ?? 1.0) * 100))%")
        }
      }
      let noiseRules: [ChangeRule] = [
        subToggle(
          \.audioSettings,
          \.micNoiseReductionEnabled,
          default: false,
          on: "Noise reduction enabled",
          off: "Noise reduction disabled"
        ),
        sub(\.audioSettings, \.micNoiseReductionIntensity, default: Float(0.5)) {
          "Noise reduction intensity set to \(Int($0 * 100))%"
        },
      ]
      results.append(contentsOf: noiseRules.flatMap { $0(old, new) })
      return results
    },

    regions(
      \.systemAudioRegions,
      added: "System audio region added",
      removed: "System audio region removed",
      adjusted: "System audio region adjusted"
    ),
    regions(
      \.micAudioRegions,
      added: "Mic audio region added",
      removed: "Mic audio region removed",
      adjusted: "Mic audio region adjusted"
    ),
    regions(
      \.cameraFullscreenRegions,
      added: "Camera fullscreen region added",
      removed: "Camera fullscreen region removed",
      adjusted: "Camera fullscreen region adjusted"
    ),
    regions(
      \.cameraRegions,
      added: "Camera region added",
      removed: "Camera region removed",
      adjusted: "Camera region adjusted"
    ),
    regions(
      \.videoRegions,
      added: "Video region added",
      removed: "Video region removed",
      adjusted: "Video region adjusted"
    ),

    { old, new in
      guard old.captionSettings != new.captionSettings || old.captionSegments != new.captionSegments
      else { return [] }
      var results: [String] = []
      let oldSegs = old.captionSegments ?? []
      let newSegs = new.captionSegments ?? []
      if oldSegs.isEmpty && !newSegs.isEmpty {
        return ["Captions generated (\(newSegs.count) segments)"]
      }
      if !oldSegs.isEmpty && newSegs.isEmpty {
        return ["Captions cleared"]
      }
      if oldSegs != newSegs && !oldSegs.isEmpty && !newSegs.isEmpty {
        if oldSegs.count != newSegs.count {
          results.append("Caption segments updated (\(newSegs.count) segments)")
        } else {
          results.append("Caption segments edited")
        }
      }
      let subRules: [ChangeRule] = [
        subToggle(
          \.captionSettings,
          \.enabled,
          default: true,
          on: "Captions enabled",
          off: "Captions disabled"
        ),
        sub(\.captionSettings, \.fontSize, default: CGFloat(48)) {
          "Caption font size set to \(Int($0))px"
        },
        sub(\.captionSettings, \.fontWeight, default: .bold) {
          "Caption font weight set to \($0.label)"
        },
        sub(\.captionSettings, \.position, default: .bottom) {
          "Caption position set to \($0.label.lowercased())"
        },
        sub(\.captionSettings, \.textColor, default: CodableColor(r: 1, g: 1, b: 1)) { _ in
          "Caption text color updated"
        },
        sub(
          \.captionSettings,
          \.backgroundColor,
          default: CodableColor(r: 0, g: 0, b: 0, a: 1.0)
        ) { _ in "Caption background color updated" },
        sub(\.captionSettings, \.backgroundOpacity, default: CGFloat(0.6)) {
          "Caption background opacity set to \(Int($0 * 100))%"
        },
        subToggle(
          \.captionSettings,
          \.showBackground,
          default: true,
          on: "Caption background enabled",
          off: "Caption background disabled"
        ),
        sub(\.captionSettings, \.maxWordsPerLine, default: 6) {
          "Caption words per line set to \($0)"
        },
        sub(\.captionSettings, \.model, default: "openai_whisper-base") {
          let modelName = WhisperModel(rawValue: $0)?.shortLabel ?? "unknown"
          return "Caption model set to \(modelName)"
        },
        sub(\.captionSettings, \.language, default: .auto) {
          "Caption language set to \($0.label)"
        },
        sub(\.captionSettings, \.audioSource, default: .microphone) {
          "Caption audio source set to \($0.label)"
        },
      ]
      results.append(contentsOf: subRules.flatMap { $0(old, new) })
      return results
    },
  ]

  static func describeChanges(from old: EditorStateData, to new: EditorStateData) -> [String] {
    var changes = rules.flatMap { $0(old, new) }
    if changes.isEmpty { changes.append("Editor settings updated") }
    return changes
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

  private static func describeCameraBackground(_ style: CameraBackgroundStyle?) -> String {
    guard let style else { return "none" }
    switch style {
    case .none:
      return "none"
    case .blur:
      return "blur"
    case .solidColor:
      return "solid color"
    case .gradient(let id):
      if let preset = GradientPresets.preset(for: id) {
        return "\(preset.name) gradient"
      }
      return "gradient"
    case .image:
      return "image"
    }
  }
}
