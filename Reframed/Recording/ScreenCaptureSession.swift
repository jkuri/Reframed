import CoreGraphics
import CoreMedia
import Foundation
import Logging
@preconcurrency import ScreenCaptureKit

final class ScreenCaptureSession: NSObject, SCStreamDelegate, SCStreamOutput, @unchecked Sendable {
  private var stream: SCStream?
  private let videoWriter: VideoTrackWriter
  private let logger = Logger(label: "eu.jankuri.reframed.capture-session")
  private var totalCallbacks = 0
  private var completeFrames = 0
  private var idleFrames = 0
  private var lastLogTime: CFAbsoluteTime = 0
  private var isPaused = false
  private var lastPixelBuffer: CVPixelBuffer?
  private let captureQuality: CaptureQuality

  init(videoWriter: VideoTrackWriter, captureQuality: CaptureQuality = .standard) {
    self.videoWriter = videoWriter
    self.captureQuality = captureQuality
    super.init()
  }

  func start(
    target: CaptureTarget,
    display: SCDisplay,
    displayScale: CGFloat,
    fps: Int = 60,
    hideCursor: Bool = false,
    retinaCapture: Bool = false
  ) async throws {
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

    let baseW = Int(sourceRect.width * displayScale) & ~1
    let baseH = Int(sourceRect.height * displayScale) & ~1
    let pixelW: Int
    let pixelH: Int
    if retinaCapture {
      pixelW = (baseW * 2) & ~1
      pixelH = (baseH * 2) & ~1
    } else {
      pixelW = baseW
      pixelH = baseH
    }

    let captureFps = Int(round(Double(fps) * 1.2))

    let config = SCStreamConfiguration()
    config.sourceRect = sourceRect
    config.width = pixelW
    config.height = pixelH
    config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(captureFps))
    config.pixelFormat = captureQuality.isProRes ? kCVPixelFormatType_32BGRA : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    config.showsCursor = !hideCursor
    config.capturesAudio = false
    config.queueDepth = 8
    config.scalesToFit = retinaCapture
    config.colorSpaceName = CGColorSpace.sRGB as CFString

    lastPixelBuffer = nil

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
    }
  }

  func stop() async throws {
    try await stream?.stopCapture()
    stream = nil
    lastPixelBuffer = nil
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
      let status = SCFrameStatus(rawValue: statusValue)
    else { return }

    if isPaused { return }

    if status == .complete {
      completeFrames += 1
      if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
        lastPixelBuffer = imageBuffer
      }
      videoWriter.appendSampleBuffer(sampleBuffer)
    } else if status == .idle {
      idleFrames += 1
      guard let pixelBuffer = lastPixelBuffer else { return }
      let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      if let duplicatedSampleBuffer = createSampleBuffer(from: pixelBuffer, pts: pts) {
        videoWriter.appendSampleBuffer(duplicatedSampleBuffer)
      }
    }

    let now = CFAbsoluteTimeGetCurrent()
    if now - lastLogTime >= 2.0 {
      logger.info(
        "Frame stats: \(totalCallbacks) callbacks, \(completeFrames) complete, \(idleFrames) idle duplicated, \(videoWriter.writtenFrames) written, \(videoWriter.droppedFrames) dropped"
      )
      totalCallbacks = 0
      completeFrames = 0
      idleFrames = 0
      videoWriter.resetStats()
      lastLogTime = now
    }
  }

  private func createSampleBuffer(from pixelBuffer: CVPixelBuffer, pts: CMTime) -> CMSampleBuffer? {
    var formatDesc: CMVideoFormatDescription?
    guard
      CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &formatDesc
      ) == noErr,
      let formatDescription = formatDesc
    else {
      return nil
    }

    var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: pts, decodeTimeStamp: .invalid)
    var newSampleBuffer: CMSampleBuffer?

    guard
      CMSampleBufferCreateReadyWithImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescription: formatDescription,
        sampleTiming: &timingInfo,
        sampleBufferOut: &newSampleBuffer
      ) == noErr
    else {
      return nil
    }

    return newSampleBuffer
  }

  func stream(_ stream: SCStream, didStopWithError error: any Error) {
    logger.error("Stream error: \(error.localizedDescription)")
  }
}
