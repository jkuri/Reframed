@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import Logging

struct VerifiedCamera: Sendable {
  let width: Int
  let height: Int
}

final class WebcamCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
  private(set) var captureSession: AVCaptureSession?
  private var videoWriter: VideoTrackWriter?
  private let logger = Logger(label: "eu.jankuri.frame.webcam-capture")
  private var isPaused = false
  private let verifyQueue = DispatchQueue(label: "eu.jankuri.frame.webcam-verify", qos: .userInteractive)
  private var firstFrameContinuation: CheckedContinuation<VerifiedCamera, any Error>?

  override init() {
    super.init()
  }

  func startAndVerify(
    deviceId: String,
    fps: Int,
    maxWidth: Int,
    maxHeight: Int
  ) async throws -> VerifiedCamera {
    let granted = await AVCaptureDevice.requestAccess(for: .video)
    guard granted else {
      logger.error("Camera permission denied")
      throw CaptureError.permissionDenied
    }

    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .external],
      mediaType: .video,
      position: .unspecified
    )
    guard let device = discovery.devices.first(where: { $0.uniqueID == deviceId }) else {
      logger.error("Camera device not found: \(deviceId)")
      throw CaptureError.cameraNotFound
    }

    let session = AVCaptureSession()

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      throw CaptureError.cameraNotFound
    }
    session.addInput(input)

    guard let bestFormat = Self.bestFormat(for: device, maxWidth: maxWidth, maxHeight: maxHeight, fps: fps) else {
      logger.error("No suitable camera format found for \(maxWidth)x\(maxHeight)@\(fps)fps")
      throw CaptureError.cameraStreamFailed
    }

    let dims = CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription)
    logger.info("Selected camera format: \(dims.width)x\(dims.height)")

    let targetFPS = Double(fps)
    let bestRange = bestFormat.videoSupportedFrameRateRanges
      .sorted { abs($0.maxFrameRate - targetFPS) < abs($1.maxFrameRate - targetFPS) }
      .first
    let frameDuration = bestRange?.minFrameDuration ?? CMTime(value: 1, timescale: CMTimeScale(fps))

    try device.lockForConfiguration()
    device.activeFormat = bestFormat
    device.activeVideoMinFrameDuration = frameDuration
    device.activeVideoMaxFrameDuration = frameDuration
    device.unlockForConfiguration()

    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    output.setSampleBufferDelegate(self, queue: verifyQueue)
    guard session.canAddOutput(output) else {
      throw CaptureError.cameraNotFound
    }
    session.addOutput(output)

    if let connection = output.connection(with: .video) {
      connection.videoRotationAngle = 0
    }

    nonisolated(unsafe) let unsafeSession = session
    let startQueue = DispatchQueue(label: "eu.jankuri.frame.webcam-start")
    startQueue.async {
      unsafeSession.startRunning()
    }
    self.captureSession = session

    let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<VerifiedCamera, any Error>) in
      self.verifyQueue.async {
        self.firstFrameContinuation = continuation
      }
      DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) { [weak self] in
        guard let weakSelf = self else { return }
        nonisolated(unsafe) let sess = session
        weakSelf.verifyQueue.async {
          if let cont = weakSelf.firstFrameContinuation {
            weakSelf.firstFrameContinuation = nil
            sess.stopRunning()
            weakSelf.captureSession = nil
            cont.resume(throwing: CaptureError.cameraStreamFailed)
          }
        }
      }
    }

    logger.info("Webcam verified: \(device.localizedName) at \(result.width)x\(result.height)")
    return result
  }

  func attachWriter(_ writer: VideoTrackWriter) {
    verifyQueue.sync {
      self.videoWriter = writer
    }
    if let output = captureSession?.outputs.first as? AVCaptureVideoDataOutput {
      output.setSampleBufferDelegate(self, queue: writer.queue)
    }
  }

  func detachWriter() {
    verifyQueue.sync {
      self.videoWriter = nil
    }
    if let output = captureSession?.outputs.first as? AVCaptureVideoDataOutput {
      output.setSampleBufferDelegate(self, queue: verifyQueue)
    }
  }

  func pause() {
    guard let writer = videoWriter else { return }
    writer.queue.async {
      self.isPaused = true
    }
  }

  func resume() {
    guard let writer = videoWriter else { return }
    writer.queue.async {
      self.isPaused = false
    }
  }

  func stop() {
    captureSession?.stopRunning()
    captureSession = nil
    logger.info("Webcam capture stopped")
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    if let cont = firstFrameContinuation {
      firstFrameContinuation = nil
      var w = 1280
      var h = 720
      if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
        w = CVPixelBufferGetWidth(imageBuffer)
        h = CVPixelBufferGetHeight(imageBuffer)
      }
      cont.resume(returning: VerifiedCamera(width: w, height: h))
      return
    }
    if isPaused { return }
    videoWriter?.appendSampleBuffer(sampleBuffer)
  }

  static func isDeviceAvailable(deviceId: String) -> Bool {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .external],
      mediaType: .video,
      position: .unspecified
    )
    return discovery.devices.contains { $0.uniqueID == deviceId }
  }

  private static func bestFormat(
    for device: AVCaptureDevice,
    maxWidth: Int,
    maxHeight: Int,
    fps: Int
  ) -> AVCaptureDevice.Format? {
    let validFormats = device.formats.filter { format in
      let mediaType = CMFormatDescriptionGetMediaType(format.formatDescription)
      guard mediaType == kCMMediaType_Video else { return false }
      let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
      let w = Int(dims.width)
      let h = Int(dims.height)
      return w <= maxWidth && h <= maxHeight
    }
    return validFormats.sorted { a, b in
      let da = CMVideoFormatDescriptionGetDimensions(a.formatDescription)
      let db = CMVideoFormatDescriptionGetDimensions(b.formatDescription)
      let areaA = Int(da.width) * Int(da.height)
      let areaB = Int(db.width) * Int(db.height)
      if areaA != areaB { return areaA > areaB }
      let fpsA = a.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
      let fpsB = b.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
      return fpsA > fpsB
    }.first
  }
}
