@preconcurrency import AVFoundation
import Foundation
import Logging

struct MicrophoneFormat: Sendable {
  let sampleRate: Double
  let channelCount: Int
}

final class MicrophoneCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
  private var captureSession: AVCaptureSession?
  private var audioWriter: AudioTrackWriter?
  private let logger = Logger(label: "eu.jankuri.frame.microphone-capture")
  private var isPaused = false
  private let verifyQueue = DispatchQueue(label: "eu.jankuri.frame.mic-verify", qos: .userInteractive)
  private var firstSampleContinuation: CheckedContinuation<Void, any Error>?

  override init() {
    super.init()
  }

  static func targetFormat(deviceId: String) -> MicrophoneFormat? {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone],
      mediaType: .audio,
      position: .unspecified
    )
    guard let device = discovery.devices.first(where: { $0.uniqueID == deviceId }) else {
      return nil
    }
    let desc = device.activeFormat.formatDescription
    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee
    let nativeRate = asbd?.mSampleRate ?? 48000
    let nativeChannels = Int(asbd?.mChannelsPerFrame ?? 1)

    let targetRate: Double = nativeRate >= 44100 ? nativeRate : 48000
    return MicrophoneFormat(sampleRate: targetRate, channelCount: nativeChannels)
  }

  func startAndVerify(deviceId: String) async throws {
    let granted = await AVCaptureDevice.requestAccess(for: .audio)
    guard granted else {
      logger.error("Microphone permission denied")
      throw CaptureError.permissionDenied
    }

    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone],
      mediaType: .audio,
      position: .unspecified
    )
    guard let device = discovery.devices.first(where: { $0.uniqueID == deviceId }) else {
      logger.error("Microphone device not found: \(deviceId)")
      throw CaptureError.microphoneNotFound
    }

    let session = AVCaptureSession()
    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      throw CaptureError.microphoneNotFound
    }
    session.addInput(input)

    let desc = device.activeFormat.formatDescription
    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee
    let nativeRate = asbd?.mSampleRate ?? 48000
    let nativeChannels = Int(asbd?.mChannelsPerFrame ?? 1)

    let output = AVCaptureAudioDataOutput()
    if nativeRate < 44100 {
      output.audioSettings = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 48000,
        AVNumberOfChannelsKey: nativeChannels,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsNonInterleaved: false,
      ]
      logger.info("Mic resampling \(nativeRate)Hz -> 48000Hz, \(nativeChannels)ch")
    }
    output.setSampleBufferDelegate(self, queue: verifyQueue)
    guard session.canAddOutput(output) else {
      throw CaptureError.microphoneNotFound
    }
    session.addOutput(output)

    logger.info("Microphone native format: sampleRate=\(nativeRate) channels=\(nativeChannels)")

    session.startRunning()
    self.captureSession = session

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      self.verifyQueue.async {
        self.firstSampleContinuation = continuation
      }
      DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) { [weak self] in
        guard let weakSelf = self else { return }
        weakSelf.verifyQueue.async {
          if let cont = weakSelf.firstSampleContinuation {
            weakSelf.firstSampleContinuation = nil
            cont.resume(throwing: CaptureError.microphoneStreamFailed)
          }
        }
      }
    }

    logger.info("Microphone verified: \(device.localizedName)")
  }

  func attachWriter(_ writer: AudioTrackWriter) {
    verifyQueue.sync {
      self.audioWriter = writer
    }
    if let output = captureSession?.outputs.first as? AVCaptureAudioDataOutput {
      output.setSampleBufferDelegate(self, queue: writer.queue)
    }
  }

  func pause() {
    guard let writer = audioWriter else { return }
    writer.queue.async {
      self.isPaused = true
    }
  }

  func resume() {
    guard let writer = audioWriter else { return }
    writer.queue.async {
      self.isPaused = false
    }
  }

  func stop() {
    captureSession?.stopRunning()
    captureSession = nil
    logger.info("Microphone capture stopped")
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    if let cont = firstSampleContinuation {
      firstSampleContinuation = nil
      cont.resume()
      return
    }
    if isPaused { return }
    audioWriter?.appendSample(sampleBuffer)
  }

  static func isDeviceAvailable(deviceId: String) -> Bool {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone],
      mediaType: .audio,
      position: .unspecified
    )
    return discovery.devices.contains { $0.uniqueID == deviceId }
  }
}
