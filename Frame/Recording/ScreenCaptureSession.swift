import CoreGraphics
import Foundation
import Logging
@preconcurrency import ScreenCaptureKit

final class ScreenCaptureSession: NSObject, SCStreamDelegate, SCStreamOutput, @unchecked Sendable {
  private var stream: SCStream?
  private let videoWriter: VideoWriter
  private let logger = Logger(label: "eu.jankuri.frame.capture-session")
  private var totalCallbacks = 0
  private var completeFrames = 0
  private var lastLogTime: CFAbsoluteTime = 0

  init(videoWriter: VideoWriter) {
    self.videoWriter = videoWriter
    super.init()
  }

  func start(selection: SelectionRect, display: SCDisplay, displayScale: CGFloat, fps: Int = 60) async throws {
    let content = try await Permissions.fetchShareableContent()

    let selfApp = content.applications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
    let excludedApps = [selfApp].compactMap { $0 }
    let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

    let sourceRect = selection.screenCaptureKitRect
    let pixelW = Int(sourceRect.width * displayScale) & ~1
    let pixelH = Int(sourceRect.height * displayScale) & ~1

    let config = SCStreamConfiguration()
    config.sourceRect = sourceRect
    config.width = pixelW
    config.height = pixelH
    config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
    config.pixelFormat = kCVPixelFormatType_32BGRA
    config.showsCursor = true
    config.capturesAudio = false
    config.queueDepth = 3
    config.scalesToFit = false
    config.colorSpaceName = CGColorSpace.sRGB as CFString

    let stream = SCStream(filter: filter, configuration: config, delegate: self)
    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoWriter.queue)
    try await stream.startCapture()

    self.stream = stream

    logger.info(
      "Capture started",
      metadata: [
        "sourceRect": "\(sourceRect)",
        "displayScale": "\(displayScale)",
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

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    totalCallbacks += 1
    guard type == .screen, sampleBuffer.isValid else { return }

    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
      let statusValue = attachments.first?[.status] as? Int,
      let status = SCFrameStatus(rawValue: statusValue),
      status == .complete
    else {
      return
    }

    completeFrames += 1

    let now = CFAbsoluteTimeGetCurrent()
    if now - lastLogTime >= 2.0 {
      logger.info(
        "Frame stats: \(totalCallbacks) callbacks, \(completeFrames) complete, \(videoWriter.writtenFrames) written, \(videoWriter.droppedFrames) dropped"
      )
      totalCallbacks = 0
      completeFrames = 0
      videoWriter.resetStats()
      lastLogTime = now
    }

    videoWriter.appendSampleBuffer(sampleBuffer)
  }

  func stream(_ stream: SCStream, didStopWithError error: any Error) {
    logger.error("Stream error: \(error.localizedDescription)")
  }
}
