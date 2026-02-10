import AVFoundation
import Foundation
import Logging

struct MicrophoneFormat: Sendable {
  let sampleRate: Double
  let channelCount: Int
}

final class MicrophoneCapture: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
  private var captureSession: AVCaptureSession?
  private let audioWriter: AudioTrackWriter
  private let logger = Logger(label: "eu.jankuri.frame.microphone-capture")

  init(audioWriter: AudioTrackWriter) {
    self.audioWriter = audioWriter
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

  func start(deviceId: String) async throws {
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
    output.setSampleBufferDelegate(self, queue: audioWriter.queue)
    guard session.canAddOutput(output) else {
      throw CaptureError.microphoneNotFound
    }
    session.addOutput(output)

    logger.info("Microphone native format: sampleRate=\(nativeRate) channels=\(nativeChannels)")

    session.startRunning()
    self.captureSession = session
    logger.info("Microphone capture started: \(device.localizedName)")
  }

  func stop() {
    captureSession?.stopRunning()
    captureSession = nil
    logger.info("Microphone capture stopped")
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    audioWriter.appendSample(sampleBuffer)
  }
}
