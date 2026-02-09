import Foundation
import Logging

actor RecordingCoordinator {
  private var captureSession: ScreenCaptureSession?
  private var videoWriter: VideoWriter?
  private let logger = Logger(label: "com.frame.recording-coordinator")

  func startRecording(selection: SelectionRect, fps: Int = 30) async throws -> Date {
    let tempURL = FileManager.default.tempRecordingURL()

    let writer = try VideoWriter(
      outputURL: tempURL,
      width: selection.pixelWidth,
      height: selection.pixelHeight
    )
    let session = ScreenCaptureSession(videoWriter: writer)
    try await session.start(selection: selection, fps: fps)

    self.videoWriter = writer
    self.captureSession = session

    let startedAt = Date()
    logger.info("Recording started")
    return startedAt
  }

  func stopRecording() async throws -> URL? {
    try await captureSession?.stop()
    captureSession = nil

    guard let outputURL = await videoWriter?.finish() else {
      logger.error("Video writer produced no output")
      return nil
    }
    videoWriter = nil

    let destination = FileManager.default.defaultSaveURL(for: outputURL)
    try FileManager.default.moveToFinal(from: outputURL, to: destination)

    logger.info("Recording saved", metadata: ["path": "\(destination.path)"])
    return destination
  }
}
