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
  var writtenSamples = 0
  var droppedSamples = 0
  nonisolated(unsafe) private(set) var lastWrittenPTS: CMTime = .invalid
  private var lastLogTime: CFAbsoluteTime = 0

  private var videoPTSProvider: (@Sendable () -> CMTime)?
  private var driftCorrection = CMTime.zero
  private var totalBuffersReceived = 0
  private var nextDriftCheckBuffer = 100
  private let driftCheckInterval = 100
  private let driftCorrectionThreshold: Double = 0.005

  init(outputURL: URL, label: String, sampleRate: Double, channelCount: Int, clock: SharedRecordingClock) throws {
    self.outputURL = outputURL
    self.clock = clock
    self.logger = Logger(label: "eu.jankuri.reframed.audio-track-writer.\(label)")
    self.queue = DispatchQueue(label: "eu.jankuri.reframed.audio-track-writer.\(label).queue", qos: .userInteractive)
    self.outputSettings = [
      AVFormatIDKey: kAudioFormatAppleLossless,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: channelCount,
      AVEncoderBitDepthHintKey: 24,
    ]

    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    self.assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
  }

  func setVideoPTSProvider(_ provider: @escaping @Sendable () -> CMTime) {
    queue.async {
      self.videoPTSProvider = provider
    }
  }

  func resetStats() {
    writtenSamples = 0
    droppedSamples = 0
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

  private var pendingSamples: [(CMSampleBuffer, CMTime)] = []
  private let maxPendingSamples = 4800

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

    totalBuffersReceived += 1
    if isStarted && totalBuffersReceived >= nextDriftCheckBuffer {
      nextDriftCheckBuffer = totalBuffersReceived + driftCheckInterval
      if let getVideoPTS = videoPTSProvider {
        let videoPTS = getVideoPTS()
        if videoPTS.isValid {
          let audioPTS = CMTimeAdd(adjustedPTS, driftCorrection)
          let drift = CMTimeGetSeconds(videoPTS) - CMTimeGetSeconds(audioPTS)
          if drift > driftCorrectionThreshold {
            driftCorrection = CMTimeAdd(driftCorrection, CMTime(seconds: drift, preferredTimescale: 600))
          }
        }
      }
    }

    let finalPTS = CMTimeAdd(adjustedPTS, driftCorrection)

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
      assetWriter.startSession(atSourceTime: finalPTS)
      firstSamplePTS = finalPTS
      isStarted = true
      logger.info("Audio writing started at PTS \(String(format: "%.3f", CMTimeGetSeconds(finalPTS)))s")
    }

    let adjusted = createTimingAdjustedSample(sampleBuffer, pts: finalPTS)

    guard let audioInput else { return }

    if audioInput.isReadyForMoreMediaData {
      flushPendingSamples(audioInput)
      if let adj = adjusted {
        if audioInput.isReadyForMoreMediaData {
          audioInput.append(adj)
          writtenSamples += 1
          lastWrittenPTS = finalPTS
        } else {
          enqueuePending(adj, pts: finalPTS)
        }
      }
    } else {
      if let adj = adjusted {
        enqueuePending(adj, pts: finalPTS)
      }
    }

    let now = CFAbsoluteTimeGetCurrent()
    if now - lastLogTime >= 2.0 {
      logger.info(
        "Audio stats: \(writtenSamples) written, \(droppedSamples) dropped, pending \(pendingSamples.count), PTS \(String(format: "%.3f", CMTimeGetSeconds(finalPTS)))s"
      )
      resetStats()
      lastLogTime = now
    }
  }

  private func createTimingAdjustedSample(_ sampleBuffer: CMSampleBuffer, pts: CMTime) -> CMSampleBuffer? {
    var timingInfo = CMSampleTimingInfo(
      duration: CMSampleBufferGetDuration(sampleBuffer),
      presentationTimeStamp: pts,
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
    if status != noErr {
      droppedSamples += 1
    }
    return adjustedBuffer
  }

  private func flushPendingSamples(_ input: AVAssetWriterInput) {
    while !pendingSamples.isEmpty && input.isReadyForMoreMediaData {
      let (sample, pts) = pendingSamples.removeFirst()
      input.append(sample)
      writtenSamples += 1
      lastWrittenPTS = pts
    }
  }

  private func enqueuePending(_ sample: CMSampleBuffer, pts: CMTime) {
    if pendingSamples.count >= maxPendingSamples {
      pendingSamples.removeFirst()
      droppedSamples += 1
    }
    pendingSamples.append((sample, pts))
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

        if self.lastWrittenPTS.isValid {
          self.logger.info(
            "Audio final: last PTS \(String(format: "%.3f", CMTimeGetSeconds(self.lastWrittenPTS)))s, drift correction \(String(format: "%.3f", CMTimeGetSeconds(self.driftCorrection)))s, pending \(self.pendingSamples.count)"
          )
        }

        self.flushPendingSamples(audioInput)

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
