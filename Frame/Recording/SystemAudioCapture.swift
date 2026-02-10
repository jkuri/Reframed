import Foundation
import Logging
@preconcurrency import ScreenCaptureKit

final class SystemAudioCapture: NSObject, SCStreamDelegate, SCStreamOutput, @unchecked Sendable {
  private var stream: SCStream?
  private let audioWriter: AudioTrackWriter
  private let logger = Logger(label: "eu.jankuri.frame.system-audio-capture")
  private let discardQueue = DispatchQueue(label: "eu.jankuri.frame.system-audio-capture.discard", qos: .background)

  init(audioWriter: AudioTrackWriter) {
    self.audioWriter = audioWriter
    super.init()
  }

  func start(display: SCDisplay) async throws {
    let content = try await Permissions.fetchShareableContent()
    let selfApp = content.applications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
    let excludedApps = [selfApp].compactMap { $0 }
    let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

    let config = SCStreamConfiguration()
    config.width = 2
    config.height = 2
    config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
    config.capturesAudio = true
    config.excludesCurrentProcessAudio = true
    config.captureMicrophone = false
    config.sampleRate = 48000
    config.channelCount = 2

    let stream = SCStream(filter: filter, configuration: config, delegate: self)
    try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: discardQueue)
    try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioWriter.queue)

    try await stream.startCapture()
    self.stream = stream
    logger.info("System audio capture started")
  }

  func stop() async throws {
    try await stream?.stopCapture()
    stream = nil
    logger.info("System audio capture stopped")
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard sampleBuffer.isValid, type == .audio else { return }
    audioWriter.appendSample(sampleBuffer)
  }

  func stream(_ stream: SCStream, didStopWithError error: any Error) {
    logger.error("System audio stream error: \(error.localizedDescription)")
  }
}
