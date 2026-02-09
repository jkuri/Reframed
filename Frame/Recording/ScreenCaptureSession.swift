import Foundation
import Logging
@preconcurrency import ScreenCaptureKit

final class ScreenCaptureSession: NSObject, SCStreamDelegate, SCStreamOutput, @unchecked Sendable {
  private var stream: SCStream?
  private let videoWriter: VideoWriter
  private let logger = Logger(label: "com.frame.capture-session")

  init(videoWriter: VideoWriter) {
    self.videoWriter = videoWriter
    super.init()
  }

  func start(selection: SelectionRect, fps: Int = 30) async throws {
    let content = try await Permissions.fetchShareableContent()

    guard let display = content.displays.first(where: { $0.displayID == selection.displayID }) else {
      throw CaptureError.displayNotFound
    }

    let filter = SCContentFilter(display: display, excludingWindows: [])

    let config = SCStreamConfiguration()
    config.sourceRect = selection.screenCaptureKitRect
    config.width = selection.pixelWidth
    config.height = selection.pixelHeight
    config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.showsCursor = true
    config.capturesAudio = false

    let stream = SCStream(filter: filter, configuration: config, delegate: self)
    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
    try await stream.startCapture()

    self.stream = stream

    logger.info(
      "Capture started",
      metadata: [
        "region": "\(selection.rect)",
        "fps": "\(fps)",
        "output_size": "\(config.width)x\(config.height)",
      ]
    )
  }

  func stop() async throws {
    try await stream?.stopCapture()
    stream = nil
    logger.info("Capture stopped")
  }

  // MARK: - SCStreamOutput

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .screen, sampleBuffer.isValid else { return }

    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
      let statusValue = attachments.first?[.status] as? Int,
      let status = SCFrameStatus(rawValue: statusValue),
      status == .complete
    else {
      return
    }

    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

    // CVPixelBuffer is thread-safe (backed by IOSurface); safe to send across isolation.
    let writer = videoWriter
    nonisolated(unsafe) let buffer = pixelBuffer
    let ts = timestamp
    Task { @Sendable in
      await writer.appendPixelBuffer(buffer, at: ts)
    }
  }

  // MARK: - SCStreamDelegate

  func stream(_ stream: SCStream, didStopWithError error: any Error) {
    logger.error("Stream error: \(error.localizedDescription)")
  }
}
