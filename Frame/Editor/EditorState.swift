import AVFoundation
import CoreMedia
import Foundation
import Logging

@MainActor
@Observable
final class EditorState {
  let result: RecordingResult
  var playerController: SyncedPlayerController
  var pipLayout = PiPLayout()
  var trimStart: CMTime = .zero
  var trimEnd: CMTime = .zero
  var isExporting = false
  var exportProgress: Double = 0

  private let logger = Logger(label: "eu.jankuri.frame.editor-state")

  var isPlaying: Bool { playerController.isPlaying }
  var currentTime: CMTime { playerController.currentTime }
  var duration: CMTime { playerController.duration }
  var hasWebcam: Bool { result.webcamVideoURL != nil }

  init(result: RecordingResult) {
    self.result = result
    self.playerController = SyncedPlayerController(result: result)
  }

  func setup() async {
    await playerController.loadDuration()
    trimEnd = playerController.duration
    playerController.trimEnd = trimEnd
    playerController.setupTimeObserver()
    if hasWebcam {
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

  func export() async throws -> URL {
    isExporting = true
    defer { isExporting = false }

    let url = try await VideoCompositor.export(
      result: result,
      pipLayout: pipLayout,
      trimRange: CMTimeRange(start: trimStart, end: trimEnd)
    )
    logger.info("Export finished: \(url.path)")
    return url
  }

  func teardown() {
    playerController.teardown()
  }
}

enum PiPCorner {
  case topLeft, topRight, bottomLeft, bottomRight
}
