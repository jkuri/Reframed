import CoreGraphics
import Foundation
import Logging
@preconcurrency import ScreenCaptureKit

final class ScreenCaptureSession: NSObject, SCStreamDelegate, SCStreamOutput, @unchecked Sendable {
  private var stream: SCStream?
  private let videoWriter: VideoTrackWriter
  private let logger = Logger(label: "eu.jankuri.reframed.capture-session")
  private var totalCallbacks = 0
  private var completeFrames = 0
  private var acceptedFrames = 0
  private var lastLogTime: CFAbsoluteTime = 0
  private var nextTargetPTS: CMTime = .invalid
  private var targetFrameInterval: CMTime = .invalid
  private var isPaused = false

  init(videoWriter: VideoTrackWriter) {
    self.videoWriter = videoWriter
    super.init()
  }

  func start(target: CaptureTarget, display: SCDisplay, displayScale: CGFloat, fps: Int = 60, hideCursor: Bool = false) async throws {
    let filter: SCContentFilter
    let sourceRect: CGRect

    switch target {
    case .region(let selection):
      filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
      sourceRect = selection.screenCaptureKitRect

    case .window(let window):
      filter = SCContentFilter(desktopIndependentWindow: window)
      sourceRect = CGRect(origin: .zero, size: CGSize(width: CGFloat(window.frame.width), height: CGFloat(window.frame.height)))

    case .screen:
      filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
      sourceRect = CGRect(origin: .zero, size: display.frame.size)
    }
    let pixelW = Int(sourceRect.width * displayScale) & ~1
    let pixelH = Int(sourceRect.height * displayScale) & ~1

    let captureFps = Int(round(Double(fps) * 1.2))
    targetFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
    nextTargetPTS = .invalid

    let config = SCStreamConfiguration()
    config.sourceRect = sourceRect
    config.width = pixelW
    config.height = pixelH
    config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(captureFps))
    config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    config.showsCursor = !hideCursor
    config.capturesAudio = false
    config.queueDepth = 8
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
        "targetFps": "\(fps)",
        "captureFps": "\(captureFps)",
        "output_size": "\(config.width)x\(config.height)",
      ]
    )
  }

  func pause() {
    videoWriter.queue.async {
      self.isPaused = true
    }
  }

  func resume() {
    videoWriter.queue.async {
      self.isPaused = false
      self.nextTargetPTS = .invalid
    }
  }

  func stop() async throws {
    try await stream?.stopCapture()
    stream = nil
    nextTargetPTS = .invalid
    logger.info("Capture stopped")
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard sampleBuffer.isValid, type == .screen else { return }
    handleVideoSample(sampleBuffer)
  }

  private func handleVideoSample(_ sampleBuffer: CMSampleBuffer) {
    totalCallbacks += 1

    guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
      let statusValue = attachments.first?[.status] as? Int,
      let status = SCFrameStatus(rawValue: statusValue),
      status == .complete
    else {
      return
    }

    completeFrames += 1

    if isPaused { return }

    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    if nextTargetPTS.isValid {
      if CMTimeCompare(pts, nextTargetPTS) < 0 {
        return
      }
      nextTargetPTS = CMTimeAdd(nextTargetPTS, targetFrameInterval)
    } else {
      nextTargetPTS = CMTimeAdd(pts, targetFrameInterval)
    }

    acceptedFrames += 1

    let now = CFAbsoluteTimeGetCurrent()
    if now - lastLogTime >= 2.0 {
      logger.info(
        "Frame stats: \(totalCallbacks) callbacks, \(completeFrames) complete, \(acceptedFrames) accepted, \(videoWriter.writtenFrames) written, \(videoWriter.droppedFrames) dropped"
      )
      totalCallbacks = 0
      completeFrames = 0
      acceptedFrames = 0
      videoWriter.resetStats()
      lastLogTime = now
    }

    videoWriter.appendSampleBuffer(sampleBuffer)
  }

  func stream(_ stream: SCStream, didStopWithError error: any Error) {
    logger.error("Stream error: \(error.localizedDescription)")
  }
}
