import AVFoundation
import CoreMedia
import Logging

final class AudioTrackWriter: @unchecked Sendable {
  private var assetWriter: AVAssetWriter?
  private var audioInput: AVAssetWriterInput?
  private var isStarted = false
  private let outputURL: URL
  private let outputSettings: [String: Any]
  private let clock: SharedRecordingClock
  private let logger: Logger
  let queue: DispatchQueue
  private(set) var firstSamplePTS: CMTime = .invalid
  private var isPaused = false
  private var pauseOffset = CMTime.zero
  private var hasRegistered = false
  nonisolated(unsafe) private(set) var currentPeakLevel: Float = 0

  init(outputURL: URL, label: String, sampleRate: Double, channelCount: Int, clock: SharedRecordingClock) throws {
    self.outputURL = outputURL
    self.clock = clock
    self.logger = Logger(label: "eu.jankuri.reframed.audio-track-writer.\(label)")
    self.queue = DispatchQueue(label: "eu.jankuri.reframed.audio-track-writer.\(label).queue", qos: .userInteractive)
    self.outputSettings = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: channelCount,
      AVEncoderBitRateKey: 128_000,
    ]

    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    self.assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
  }

  func pause() {
    queue.async {
      self.isPaused = true
    }
  }

  func resume(withOffset offset: CMTime) {
    queue.async {
      self.isPaused = false
      self.pauseOffset = offset
    }
  }

  func appendSample(_ sampleBuffer: CMSampleBuffer) {
    dispatchPrecondition(condition: .onQueue(queue))

    let newPeak = computePeakLevel(sampleBuffer)
    currentPeakLevel = max(newPeak, currentPeakLevel * 0.85)

    guard let assetWriter else { return }

    if isPaused { return }

    let rawPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

    if !hasRegistered {
      clock.registerStream(firstPTS: rawPTS)
      hasRegistered = true
    }

    guard let adjustedPTS = clock.adjustPTS(rawPTS, pauseOffset: pauseOffset) else { return }

    if !isStarted {
      let formatHint = CMSampleBufferGetFormatDescription(sampleBuffer)
      let input = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings, sourceFormatHint: formatHint)
      input.expectsMediaDataInRealTime = true
      assetWriter.add(input)
      self.audioInput = input

      guard assetWriter.startWriting() else {
        logger.error("Failed to start audio writing: \(assetWriter.error?.localizedDescription ?? "unknown")")
        self.assetWriter = nil
        self.audioInput = nil
        return
      }
      assetWriter.startSession(atSourceTime: adjustedPTS)
      firstSamplePTS = adjustedPTS
      isStarted = true
      logger.info("Audio writing started at PTS \(String(format: "%.3f", CMTimeGetSeconds(adjustedPTS)))s")
    }

    guard let audioInput, audioInput.isReadyForMoreMediaData else { return }

    var timingInfo = CMSampleTimingInfo(
      duration: CMSampleBufferGetDuration(sampleBuffer),
      presentationTimeStamp: adjustedPTS,
      decodeTimeStamp: .invalid
    )
    var adjustedBuffer: CMSampleBuffer?
    let status = CMSampleBufferCreateCopyWithNewTiming(
      allocator: kCFAllocatorDefault,
      sampleBuffer: sampleBuffer,
      sampleTimingEntryCount: 1,
      sampleTimingArray: &timingInfo,
      sampleBufferOut: &adjustedBuffer
    )
    if status == noErr, let adjusted = adjustedBuffer {
      audioInput.append(adjusted)
    }
  }

  private func computePeakLevel(_ sampleBuffer: CMSampleBuffer) -> Float {
    guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return 0 }
    let length = CMBlockBufferGetDataLength(blockBuffer)
    guard length > 0 else { return 0 }

    var dataPointer: UnsafeMutablePointer<Int8>?
    var lengthAtOffset: Int = 0
    let status = CMBlockBufferGetDataPointer(
      blockBuffer,
      atOffset: 0,
      lengthAtOffsetOut: &lengthAtOffset,
      totalLengthOut: nil,
      dataPointerOut: &dataPointer
    )
    guard status == noErr, let ptr = dataPointer else { return 0 }

    var peak: Float = 0
    if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
      let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
    {
      if asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
        let count = lengthAtOffset / MemoryLayout<Float>.size
        let floatPtr = UnsafeRawPointer(ptr).assumingMemoryBound(to: Float.self)
        for i in stride(from: 0, to: count, by: 4) {
          let v = Swift.abs(floatPtr[i])
          if v > peak { peak = v }
        }
      } else {
        let count = lengthAtOffset / MemoryLayout<Int16>.size
        let int16Ptr = UnsafeRawPointer(ptr).assumingMemoryBound(to: Int16.self)
        for i in stride(from: 0, to: count, by: 4) {
          let v = Float(Swift.abs(int16Ptr[i])) / Float(Int16.max)
          if v > peak { peak = v }
        }
      }
    }
    return peak
  }

  func finish() async -> URL? {
    return await withCheckedContinuation { continuation in
      queue.async { [self] in
        guard let assetWriter, let audioInput else {
          continuation.resume(returning: nil)
          return
        }

        guard isStarted else {
          logger.warning("Audio writer was never started, nothing to finish")
          continuation.resume(returning: nil)
          return
        }

        audioInput.markAsFinished()

        nonisolated(unsafe) let writer = assetWriter
        writer.finishWriting {
          if writer.status == .completed {
            self.logger.info("Audio writing finished: \(self.outputURL.lastPathComponent)")
            continuation.resume(returning: self.outputURL)
          } else {
            self.logger.error("Audio writing failed: \(writer.error?.localizedDescription ?? "unknown")")
            continuation.resume(returning: nil)
          }
        }
      }
    }
  }
}
