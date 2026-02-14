@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import Logging

struct VerifiedDevice: Sendable {
  let width: Int
  let height: Int
}

final class DeviceCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
  AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable
{
  private(set) var captureSession: AVCaptureSession?
  private var videoWriter: VideoTrackWriter?
  private var audioWriter: AudioTrackWriter?
  private let logger = Logger(label: "eu.jankuri.reframed.device-capture")
  private var isPaused = false
  private let verifyQueue = DispatchQueue(label: "eu.jankuri.reframed.device-verify", qos: .userInteractive)
  private let audioQueue = DispatchQueue(label: "eu.jankuri.reframed.device-audio", qos: .userInteractive)
  private var firstFrameContinuation: CheckedContinuation<Void, any Error>?
  private var verifiedDims: (width: Int, height: Int) = (0, 0)

  override init() {
    super.init()
  }

  func startAndVerify(deviceId: String) async throws -> VerifiedDevice {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.external],
      mediaType: .muxed,
      position: .unspecified
    )
    guard let device = discovery.devices.first(where: { $0.uniqueID == deviceId }) else {
      logger.error("Device not found: \(deviceId)")
      throw CaptureError.deviceNotFound
    }

    let session = AVCaptureSession()

    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      throw CaptureError.deviceNotFound
    }
    session.addInput(input)

    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    ]
    videoOutput.setSampleBufferDelegate(self, queue: verifyQueue)
    guard session.canAddOutput(videoOutput) else {
      throw CaptureError.deviceStreamFailed
    }
    session.addOutput(videoOutput)

    let audioOutput = AVCaptureAudioDataOutput()
    audioOutput.setSampleBufferDelegate(self, queue: audioQueue)
    if session.canAddOutput(audioOutput) {
      session.addOutput(audioOutput)
    }

    nonisolated(unsafe) let unsafeSession = session
    let startQueue = DispatchQueue(label: "eu.jankuri.reframed.device-start")
    startQueue.async {
      unsafeSession.startRunning()
    }
    self.captureSession = session

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      self.verifyQueue.async {
        self.firstFrameContinuation = continuation
      }
      DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in
        guard let weakSelf = self else { return }
        nonisolated(unsafe) let sess = session
        weakSelf.verifyQueue.async {
          if let cont = weakSelf.firstFrameContinuation {
            weakSelf.firstFrameContinuation = nil
            sess.stopRunning()
            weakSelf.captureSession = nil
            cont.resume(throwing: CaptureError.deviceStreamFailed)
          }
        }
      }
    }

    let verified = VerifiedDevice(width: verifiedDims.width, height: verifiedDims.height)
    logger.info("Device verified: \(device.localizedName) at \(verified.width)x\(verified.height)")
    return verified
  }

  func attachVideoWriter(_ writer: VideoTrackWriter) {
    verifyQueue.sync {
      self.videoWriter = writer
    }
    if let output = captureSession?.outputs.first(where: { $0 is AVCaptureVideoDataOutput }) as? AVCaptureVideoDataOutput {
      output.setSampleBufferDelegate(self, queue: writer.queue)
    }
  }

  func attachAudioWriter(_ writer: AudioTrackWriter) {
    audioQueue.sync {
      self.audioWriter = writer
    }
    if let output = captureSession?.outputs.first(where: { $0 is AVCaptureAudioDataOutput }) as? AVCaptureAudioDataOutput {
      output.setSampleBufferDelegate(self, queue: writer.queue)
    }
  }

  func detachWriters() {
    verifyQueue.sync {
      self.videoWriter = nil
    }
    audioQueue.sync {
      self.audioWriter = nil
    }
    if let videoOut = captureSession?.outputs.first(where: { $0 is AVCaptureVideoDataOutput }) as? AVCaptureVideoDataOutput {
      videoOut.setSampleBufferDelegate(self, queue: verifyQueue)
    }
    if let audioOut = captureSession?.outputs.first(where: { $0 is AVCaptureAudioDataOutput }) as? AVCaptureAudioDataOutput {
      audioOut.setSampleBufferDelegate(self, queue: audioQueue)
    }
  }

  func pause() {
    verifyQueue.async { self.isPaused = true }
  }

  func resume() {
    verifyQueue.async { self.isPaused = false }
  }

  func stop() {
    captureSession?.stopRunning()
    captureSession = nil
    logger.info("Device capture stopped")
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    if output is AVCaptureVideoDataOutput {
      if let cont = firstFrameContinuation {
        firstFrameContinuation = nil
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
          let w = CVPixelBufferGetWidth(imageBuffer)
          let h = CVPixelBufferGetHeight(imageBuffer)
          verifiedDims = (w & ~1, h & ~1)
        }
        cont.resume()
        return
      }
      if isPaused { return }
      videoWriter?.appendSampleBuffer(sampleBuffer)
    } else if output is AVCaptureAudioDataOutput {
      if isPaused { return }
      audioWriter?.appendSample(sampleBuffer)
    }
  }

  var deviceAudioFormat: (sampleRate: Double, channelCount: Int)? {
    guard let session = captureSession else { return nil }
    for output in session.outputs {
      if let audioOut = output as? AVCaptureAudioDataOutput,
        let connection = audioOut.connection(with: .audio),
        let desc = connection.audioChannels.first
      {
        _ = desc
        return (48000, 2)
      }
    }
    return (48000, 2)
  }
}
