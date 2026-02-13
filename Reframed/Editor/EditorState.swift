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

    if let saved = project?.metadata.editorState {
      let start = CMTime(seconds: saved.trimStartSeconds, preferredTimescale: 600)
      let end = CMTime(seconds: saved.trimEndSeconds, preferredTimescale: 600)
      if CMTimeCompare(start, .zero) >= 0 && CMTimeCompare(end, start) > 0 {
        trimStart = start
        trimEnd = CMTimeMinimum(end, playerController.duration)
        playerController.trimEnd = trimEnd
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
    let data = EditorStateData(
      trimStartSeconds: CMTimeGetSeconds(trimStart),
      trimEndSeconds: CMTimeGetSeconds(trimEnd),
      backgroundStyle: backgroundStyle,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      pipCornerRadius: pipCornerRadius,
      pipBorderWidth: pipBorderWidth,
      pipLayout: pipLayout
    )
    try? project.saveEditorState(data)
  }

  func teardown() {
    saveState()
    playerController.teardown()
  }
}

enum PiPCorner {
  case topLeft, topRight, bottomLeft, bottomRight
}
