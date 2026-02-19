import AVFoundation
import CoreMedia
import CoreVideo
import Logging

final class VideoTrackWriter: @unchecked Sendable {
  private var assetWriter: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var isStarted = false
  private let outputURL: URL
  private let clock: SharedRecordingClock
  private let logger = Logger(label: "eu.jankuri.reframed.video-track-writer")
  let queue = DispatchQueue(label: "eu.jankuri.reframed.video-track-writer.queue", qos: .userInteractive)
  var writtenFrames = 0
  var droppedFrames = 0
  private(set) var firstSamplePTS: CMTime = .invalid
  private var isPaused = false
  private var pauseOffset = CMTime.zero
  private var hasRegistered = false

  func resetStats() {
    writtenFrames = 0
    droppedFrames = 0
  }

  init(
    outputURL: URL,
    width: Int,
    height: Int,
    fps: Int = 60,
    clock: SharedRecordingClock,
    captureQuality: CaptureQuality = .standard
  ) throws {
    self.outputURL = outputURL
    self.clock = clock

    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let fileType: AVFileType = captureQuality.isProRes ? .mov : .mp4
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)

    let videoSettings: [String: Any]
    switch captureQuality {
    case .standard:
      videoSettings = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ] as [String: Any],
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: width * height * 5,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
          AVVideoExpectedSourceFrameRateKey: fps,
          AVVideoAllowFrameReorderingKey: false,
        ] as [String: Any],
      ]
    case .high:
      videoSettings = [
        AVVideoCodecKey: AVVideoCodecType.proRes422,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ] as [String: Any],
      ]
    case .veryHigh:
      videoSettings = [
        AVVideoCodecKey: AVVideoCodecType.proRes4444,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ] as [String: Any],
      ]
    }

    let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    input.expectsMediaDataInRealTime = true
    writer.add(input)
    self.videoInput = input
    self.assetWriter = writer
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

  func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
    dispatchPrecondition(condition: .onQueue(queue))

    guard let assetWriter, let videoInput else { return }

    if isPaused { return }

    let workingBuffer = sampleBuffer

    let rawPTS = CMSampleBufferGetPresentationTimeStamp(workingBuffer)

    if !hasRegistered {
      clock.registerStream(firstPTS: rawPTS)
      hasRegistered = true
    }

    guard let adjustedPTS = clock.adjustPTS(rawPTS, pauseOffset: pauseOffset) else { return }

    if !isStarted {
      guard assetWriter.startWriting() else {
        logger.error("Failed to start writing: \(assetWriter.error?.localizedDescription ?? "unknown")")
        return
      }
      assetWriter.startSession(atSourceTime: adjustedPTS)
      firstSamplePTS = adjustedPTS
      isStarted = true
      logger.info("Video writing started at PTS \(String(format: "%.3f", CMTimeGetSeconds(adjustedPTS)))s")
    }

    guard videoInput.isReadyForMoreMediaData else {
      droppedFrames += 1
      return
    }

    var timingInfo = CMSampleTimingInfo(
      duration: CMSampleBufferGetDuration(workingBuffer),
      presentationTimeStamp: adjustedPTS,
      decodeTimeStamp: .invalid
    )
    var adjustedBuffer: CMSampleBuffer?
    let status = CMSampleBufferCreateCopyWithNewTiming(
      allocator: kCFAllocatorDefault,
      sampleBuffer: workingBuffer,
      sampleTimingEntryCount: 1,
      sampleTimingArray: &timingInfo,
      sampleBufferOut: &adjustedBuffer
    )
    if status == noErr, let adjusted = adjustedBuffer {
      videoInput.append(adjusted)
      writtenFrames += 1
    } else {
      droppedFrames += 1
    }
  }

  func finish() async -> URL? {
    return await withCheckedContinuation { continuation in
      queue.async { [self] in
        guard let assetWriter, let videoInput else {
          continuation.resume(returning: nil)
          return
        }

        guard isStarted else {
          logger.warning("Writer was never started, nothing to finish")
          continuation.resume(returning: nil)
          return
        }

        videoInput.markAsFinished()

        nonisolated(unsafe) let writer = assetWriter
        writer.finishWriting {
          if writer.status == .completed {
            self.logger.info("Video writing finished: \(self.outputURL.lastPathComponent)")
            continuation.resume(returning: self.outputURL)
          } else {
            self.logger.error("Video writing failed: \(writer.error?.localizedDescription ?? "unknown")")
            continuation.resume(returning: nil)
          }
        }
      }
    }
  }
}
