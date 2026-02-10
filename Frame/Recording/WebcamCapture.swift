import AVFoundation
import Foundation
import Logging

final class WebcamCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
  private(set) var captureSession: AVCaptureSession?
  private let videoWriter: VideoTrackWriter
  private let logger = Logger(label: "eu.jankuri.frame.webcam-capture")
  private var isPaused = false

  init(videoWriter: VideoTrackWriter) {
    self.videoWriter = videoWriter
    super.init()
  }

  func start(deviceId: String, fps: Int) async throws {
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
    session.sessionPreset = .high

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      throw CaptureError.cameraNotFound
    }
    session.addInput(input)

    let output = AVCaptureVideoDataOutput()
    output.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    output.setSampleBufferDelegate(self, queue: videoWriter.queue)
    guard session.canAddOutput(output) else {
      throw CaptureError.cameraNotFound
    }
    session.addOutput(output)

    if let connection = output.connection(with: .video) {
      connection.videoRotationAngle = 0
    }

    session.startRunning()
    self.captureSession = session
    logger.info("Webcam capture started: \(device.localizedName)")
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

  func stop() {
    captureSession?.stopRunning()
    captureSession = nil
    logger.info("Webcam capture stopped")
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    if isPaused { return }
    videoWriter.appendSampleBuffer(sampleBuffer)
  }
}
