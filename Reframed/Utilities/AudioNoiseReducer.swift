import AVFoundation
import Foundation

enum AudioNoiseReducer {
  static func processFile(inputURL: URL, outputURL: URL, intensity: Float) async throws {
    let sourceFile = try AVAudioFile(forReading: inputURL)
    let format = sourceFile.processingFormat
    let frameCount = AVAudioFrameCount(sourceFile.length)

    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    let eq = AVAudioUnitEQ(numberOfBands: 2)

    let highPassBand = eq.bands[0]
    highPassBand.filterType = .highPass
    highPassBand.frequency = 80 + (300 - 80) * intensity
    highPassBand.bandwidth = 1.0
    highPassBand.bypass = false

    let lowPassBand = eq.bands[1]
    lowPassBand.filterType = .lowPass
    lowPassBand.frequency = 20000 - (20000 - 8000) * intensity
    lowPassBand.bandwidth = 1.0
    lowPassBand.bypass = false

    engine.attach(playerNode)
    engine.attach(eq)
    engine.connect(playerNode, to: eq, format: format)
    engine.connect(eq, to: engine.mainMixerNode, format: format)

    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
    try engine.start()
    playerNode.play()

    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
    try sourceFile.read(into: buffer)
    playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in }

    let outputFile = try AVAudioFile(
      forWriting: outputURL,
      settings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: format.sampleRate,
        AVNumberOfChannelsKey: format.channelCount,
        AVEncoderBitRateKey: 320_000,
      ]
    )

    let renderBuffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)!
    var remaining = frameCount
    while remaining > 0 {
      try Task.checkCancellation()
      let framesToRender = min(remaining, 4096)
      let status = try engine.renderOffline(framesToRender, to: renderBuffer)
      switch status {
      case .success:
        try outputFile.write(from: renderBuffer)
        remaining -= renderBuffer.frameLength
      case .insufficientDataFromInputNode:
        remaining -= framesToRender
      case .cannotDoInCurrentContext:
        try await Task.sleep(for: .milliseconds(10))
      case .error:
        throw CaptureError.recordingFailed("Audio noise reduction rendering failed")
      @unknown default:
        break
      }
    }

    playerNode.stop()
    engine.stop()
  }
}
