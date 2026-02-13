import AVFoundation
import AppKit
import CoreMedia
import Foundation
import Logging

@MainActor
@Observable
final class EditorState {
  private(set) var result: RecordingResult
  private(set) var project: ReframedProject?
  var playerController: SyncedPlayerController
  var pipLayout = PiPLayout()
  var trimStart: CMTime = .zero
  var trimEnd: CMTime = .zero
  var systemAudioTrimStart: CMTime = .zero
  var systemAudioTrimEnd: CMTime = .zero
  var micAudioTrimStart: CMTime = .zero
  var micAudioTrimEnd: CMTime = .zero
  var isExporting = false
  var exportProgress: Double = 0

  var backgroundStyle: BackgroundStyle = .none
  var padding: CGFloat = 0
  var videoCornerRadius: CGFloat = 0
  var pipCornerRadius: CGFloat = 8
  var pipBorderWidth: CGFloat = 0
  var projectName: String = ""
  var showExportSheet = false
  var showDeleteConfirmation = false
  var showExportResult = false
  var exportResultMessage = ""
  var exportResultIsError = false
  var lastExportedURL: URL?

  var cursorMetadataProvider: CursorMetadataProvider?
  var showCursor: Bool = true
  var cursorStyle: CursorStyle = .defaultArrow
  var cursorSize: CGFloat = 24
  var cursorSmoothing: CursorSmoothing = .standard

  var showClickHighlights: Bool = true
  var clickHighlightColor: CodableColor = CodableColor(r: 0.2, g: 0.5, b: 1.0, a: 1.0)
  var clickHighlightSize: CGFloat = 36

  var zoomTimeline: ZoomTimeline?
  var autoZoomEnabled: Bool = false
  var zoomFollowCursor: Bool = true
  var zoomLevel: Double = 2.0
  var zoomTransitionSpeed: Double = 0.4
  var zoomDwellThreshold: Double = 0.5

  private let logger = Logger(label: "eu.jankuri.reframed.editor-state")

  var isPlaying: Bool { playerController.isPlaying }
  var currentTime: CMTime { playerController.currentTime }
  var duration: CMTime { playerController.duration }
  var hasWebcam: Bool { result.webcamVideoURL != nil }

  init(project: ReframedProject) {
    self.project = project
    self.result = project.recordingResult
    self.playerController = SyncedPlayerController(result: project.recordingResult)
    self.projectName = project.name

    if let saved = project.metadata.editorState {
      self.backgroundStyle = saved.backgroundStyle
      self.padding = saved.padding
      self.videoCornerRadius = saved.videoCornerRadius
      self.pipCornerRadius = saved.pipCornerRadius
      self.pipBorderWidth = saved.pipBorderWidth
      self.pipLayout = saved.pipLayout
    }
  }

  init(result: RecordingResult) {
    self.project = nil
    self.result = result
    self.playerController = SyncedPlayerController(result: result)
    self.projectName = result.screenVideoURL.deletingPathExtension().lastPathComponent
  }

  func setup() async {
    await playerController.loadDuration()
    trimEnd = playerController.duration
    systemAudioTrimEnd = playerController.duration
    micAudioTrimEnd = playerController.duration
    playerController.trimEnd = trimEnd
    playerController.systemAudioTrimEnd = systemAudioTrimEnd
    playerController.micAudioTrimEnd = micAudioTrimEnd
    playerController.setupTimeObserver()

    if let cursorURL = project?.cursorMetadataURL ?? result.cursorMetadataURL {
      cursorMetadataProvider = try? CursorMetadataProvider.load(from: cursorURL)
    }

    if let saved = project?.metadata.editorState {
      let start = CMTime(seconds: saved.trimStartSeconds, preferredTimescale: 600)
      let end = CMTime(seconds: saved.trimEndSeconds, preferredTimescale: 600)
      if CMTimeCompare(start, .zero) >= 0 && CMTimeCompare(end, start) > 0 {
        trimStart = start
        trimEnd = CMTimeMinimum(end, playerController.duration)
        playerController.trimEnd = trimEnd
      }
      if let cursorSettings = saved.cursorSettings {
        showCursor = cursorSettings.showCursor
        cursorStyle = CursorStyle(rawValue: cursorSettings.cursorStyleRaw) ?? .defaultArrow
        cursorSize = cursorSettings.cursorSize
        cursorSmoothing = CursorSmoothing(rawValue: cursorSettings.cursorSmoothingRaw) ?? .standard
        showClickHighlights = cursorSettings.showClickHighlights
        if let savedColor = cursorSettings.clickHighlightColor {
          clickHighlightColor = savedColor
        }
        clickHighlightSize = cursorSettings.clickHighlightSize
      }
      if let zoomSettings = saved.zoomSettings {
        autoZoomEnabled = zoomSettings.autoZoomEnabled
        zoomFollowCursor = zoomSettings.zoomFollowCursor
        zoomLevel = zoomSettings.zoomLevel
        zoomTransitionSpeed = zoomSettings.transitionDuration
        zoomDwellThreshold = zoomSettings.dwellThreshold
        if !zoomSettings.keyframes.isEmpty {
          zoomTimeline = ZoomTimeline(keyframes: zoomSettings.keyframes)
        }
      }
    } else if hasWebcam {
      setPipCorner(.bottomRight)
    }
  }

  func play() { playerController.play() }
  func pause() { playerController.pause() }

  func seek(to time: CMTime) {
    playerController.seek(to: time)
  }

  func updateTrimStart(_ time: CMTime) {
    trimStart = time
  }

  func updateTrimEnd(_ time: CMTime) {
    trimEnd = time
    playerController.trimEnd = time
  }

  func updateSystemAudioTrimStart(_ time: CMTime) {
    systemAudioTrimStart = time
    playerController.systemAudioTrimStart = time
  }

  func updateSystemAudioTrimEnd(_ time: CMTime) {
    systemAudioTrimEnd = time
    playerController.systemAudioTrimEnd = time
  }

  func updateMicAudioTrimStart(_ time: CMTime) {
    micAudioTrimStart = time
    playerController.micAudioTrimStart = time
  }

  func updateMicAudioTrimEnd(_ time: CMTime) {
    micAudioTrimEnd = time
    playerController.micAudioTrimEnd = time
  }

  func setPipCorner(_ corner: PiPCorner) {
    let margin: CGFloat = 0.02
    let relH = pipRelativeHeight

    switch corner {
    case .topLeft:
      pipLayout.relativeX = margin
      pipLayout.relativeY = margin
    case .topRight:
      pipLayout.relativeX = 1.0 - pipLayout.relativeWidth - margin
      pipLayout.relativeY = margin
    case .bottomLeft:
      pipLayout.relativeX = margin
      pipLayout.relativeY = 1.0 - relH - margin
    case .bottomRight:
      pipLayout.relativeX = 1.0 - pipLayout.relativeWidth - margin
      pipLayout.relativeY = 1.0 - relH - margin
    }
  }

  func clampPipPosition() {
    let relH = pipRelativeHeight
    pipLayout.relativeX = max(0, min(1 - pipLayout.relativeWidth, pipLayout.relativeX))
    pipLayout.relativeY = max(0, min(1 - relH, pipLayout.relativeY))
  }

  private var pipRelativeHeight: CGFloat {
    guard let ws = result.webcamSize else { return pipLayout.relativeWidth * 0.75 }
    let canvas = canvasSize(for: result.screenSize)
    let aspect = ws.height / max(ws.width, 1)
    return pipLayout.relativeWidth * aspect * (canvas.width / max(canvas.height, 1))
  }

  func canvasSize(for screenSize: CGSize) -> CGSize {
    if padding > 0 {
      let scale = 1.0 + 2.0 * padding
      return CGSize(width: screenSize.width * scale, height: screenSize.height * scale)
    }
    return screenSize
  }

  func export(settings: ExportSettings) async throws -> URL {
    isExporting = true
    exportProgress = 0
    defer { isExporting = false }

    let cursorSnapshot = showCursor ? cursorMetadataProvider?.makeSnapshot() : nil

    let state = self
    let url = try await VideoCompositor.export(
      result: result,
      pipLayout: pipLayout,
      trimRange: CMTimeRange(start: trimStart, end: trimEnd),
      systemAudioTrimRange: CMTimeRange(start: systemAudioTrimStart, end: systemAudioTrimEnd),
      micAudioTrimRange: CMTimeRange(start: micAudioTrimStart, end: micAudioTrimEnd),
      backgroundStyle: backgroundStyle,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      pipCornerRadius: pipCornerRadius,
      pipBorderWidth: pipBorderWidth,
      exportSettings: settings,
      cursorSnapshot: cursorSnapshot,
      cursorStyle: cursorStyle,
      cursorSize: cursorSize,
      cursorSmoothing: cursorSmoothing,
      showClickHighlights: showClickHighlights,
      clickHighlightColor: clickHighlightColor.cgColor,
      clickHighlightSize: clickHighlightSize,
      zoomFollowCursor: zoomFollowCursor,
      zoomTimeline: zoomTimeline,
      progressHandler: { progress in
        state.exportProgress = progress
      }
    )
    exportProgress = 1.0
    lastExportedURL = url
    logger.info("Export finished: \(url.path)")
    return url
  }

  func deleteRecording() {
    if let project {
      try? project.delete()
    } else {
      let fm = FileManager.default
      try? fm.removeItem(at: result.screenVideoURL)
      if let webcamURL = result.webcamVideoURL {
        try? fm.removeItem(at: webcamURL)
      }
      if let sysURL = result.systemAudioURL {
        try? fm.removeItem(at: sysURL)
      }
      if let micURL = result.microphoneAudioURL {
        try? fm.removeItem(at: micURL)
      }
    }
  }

  func openProjectFolder() {
    if let bundleURL = project?.bundleURL {
      NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    } else {
      let dir = FileManager.default.projectSaveDirectory()
      NSWorkspace.shared.open(dir)
    }
  }

  func openExportedFile() {
    if let lastExportedURL {
      NSWorkspace.shared.activateFileViewerSelecting([lastExportedURL])
    } else {
      let dir = FileManager.default.defaultSaveDirectory()
      NSWorkspace.shared.open(dir)
    }
  }

  func renameProject(_ newName: String) {
    guard var proj = project else { return }
    try? proj.rename(to: newName)
    project = proj
    result = proj.recordingResult
    projectName = proj.name
  }

  func saveState() {
    guard let project else { return }
    var cursorSettings: CursorSettingsData?
    if cursorMetadataProvider != nil {
      cursorSettings = CursorSettingsData(
        showCursor: showCursor,
        cursorStyleRaw: cursorStyle.rawValue,
        cursorSize: cursorSize,
        cursorSmoothingRaw: cursorSmoothing.rawValue,
        showClickHighlights: showClickHighlights,
        clickHighlightColor: clickHighlightColor,
        clickHighlightSize: clickHighlightSize
      )
    }
    var zoomSettings: ZoomSettingsData?
    if let zt = zoomTimeline {
      zoomSettings = ZoomSettingsData(
        autoZoomEnabled: autoZoomEnabled,
        zoomFollowCursor: zoomFollowCursor,
        zoomLevel: zoomLevel,
        transitionDuration: zoomTransitionSpeed,
        dwellThreshold: zoomDwellThreshold,
        keyframes: zt.allKeyframes
      )
    }
    let data = EditorStateData(
      trimStartSeconds: CMTimeGetSeconds(trimStart),
      trimEndSeconds: CMTimeGetSeconds(trimEnd),
      backgroundStyle: backgroundStyle,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      pipCornerRadius: pipCornerRadius,
      pipBorderWidth: pipBorderWidth,
      pipLayout: pipLayout,
      cursorSettings: cursorSettings,
      zoomSettings: zoomSettings
    )
    try? project.saveEditorState(data)
  }

  func generateAutoZoom() {
    guard let provider = cursorMetadataProvider else { return }
    let config = ZoomDetectorConfig(
      zoomLevel: zoomLevel,
      dwellThresholdSeconds: zoomDwellThreshold,
      velocityThreshold: 0.05,
      minZoomDuration: 1.0,
      transitionDuration: zoomTransitionSpeed
    )
    let dur = CMTimeGetSeconds(duration)
    var newKeyframes = ZoomDetector.detect(from: provider.metadata, duration: dur, config: config)

    if let existing = zoomTimeline {
      let manualKeyframes = existing.allKeyframes.filter { !$0.isAuto }
      newKeyframes.append(contentsOf: manualKeyframes)
    }

    zoomTimeline = ZoomTimeline(keyframes: newKeyframes)
  }

  func clearAutoZoom() {
    guard let existing = zoomTimeline else { return }
    let manualKeyframes = existing.allKeyframes.filter { !$0.isAuto }
    if manualKeyframes.isEmpty {
      zoomTimeline = nil
    } else {
      zoomTimeline = ZoomTimeline(keyframes: manualKeyframes)
    }
  }

  func addManualZoomKeyframe(at time: Double, center: CGPoint) {
    let kf = ZoomKeyframe(
      t: time,
      zoomLevel: zoomLevel,
      centerX: center.x,
      centerY: center.y,
      isAuto: false
    )
    var existing = zoomTimeline?.allKeyframes ?? []
    existing.append(kf)
    zoomTimeline = ZoomTimeline(keyframes: existing)
  }

  func removeZoomKeyframe(at index: Int) {
    guard let existing = zoomTimeline else { return }
    var kfs = existing.allKeyframes
    guard index >= 0 && index < kfs.count else { return }
    kfs.remove(at: index)
    if kfs.isEmpty {
      zoomTimeline = nil
    } else {
      zoomTimeline = ZoomTimeline(keyframes: kfs)
    }
  }

  func teardown() {
    saveState()
    playerController.teardown()
  }
}

enum PiPCorner {
  case topLeft, topRight, bottomLeft, bottomRight
}
