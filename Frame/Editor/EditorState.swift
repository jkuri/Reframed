import AppKit
import AVFoundation
import CoreMedia
import Foundation
import Logging

@MainActor
@Observable
final class EditorState {
  private(set) var result: RecordingResult
  private(set) var project: FrameProject?
  var playerController: SyncedPlayerController
  var pipLayout = PiPLayout()
  var trimStart: CMTime = .zero
  var trimEnd: CMTime = .zero
  var isExporting = false
  var exportProgress: Double = 0

  var backgroundStyle: BackgroundStyle = .none
  var padding: CGFloat = 0
  var videoCornerRadius: CGFloat = 0
  var pipCornerRadius: CGFloat = 12
  var pipBorderWidth: CGFloat = 0
  var projectName: String = ""
  var showExportSheet = false
  var showDeleteConfirmation = false
  var showExportResult = false
  var exportResultMessage = ""
  var exportResultIsError = false
  var lastExportedURL: URL?

  private let logger = Logger(label: "eu.jankuri.frame.editor-state")

  var isPlaying: Bool { playerController.isPlaying }
  var currentTime: CMTime { playerController.currentTime }
  var duration: CMTime { playerController.duration }
  var hasWebcam: Bool { result.webcamVideoURL != nil }

  init(project: FrameProject) {
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
    playerController.trimEnd = trimEnd
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

  func setPipCorner(_ corner: PiPCorner) {
    let margin: CGFloat = 0.02
    let w = pipLayout.relativeWidth
    let aspect: CGFloat = {
      guard let ws = result.webcamSize else { return 0.75 }
      return ws.height / max(ws.width, 1)
    }()
    let h = w * aspect * (result.screenSize.width / max(result.screenSize.height, 1))

    switch corner {
    case .topLeft:
      pipLayout.relativeX = margin
      pipLayout.relativeY = margin
    case .topRight:
      pipLayout.relativeX = 1.0 - w - margin
      pipLayout.relativeY = margin
    case .bottomLeft:
      pipLayout.relativeX = margin
      pipLayout.relativeY = 1.0 - h - margin
    case .bottomRight:
      pipLayout.relativeX = 1.0 - w - margin
      pipLayout.relativeY = 1.0 - h - margin
    }
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

  func openExportFolder() {
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
