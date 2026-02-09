import AVFoundation
import CoreMedia
import CoreVideo
import Logging

final class VideoWriter: @unchecked Sendable {
  private var assetWriter: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var isStarted = false
  private let outputURL: URL
  private let logger = Logger(label: "eu.jankuri.frame.video-writer")
  let queue = DispatchQueue(label: "eu.jankuri.frame.video-writer.queue", qos: .userInteractive)
  var writtenFrames = 0
  var droppedFrames = 0

  func resetStats() {
    writtenFrames = 0
    droppedFrames = 0
  }

  init(outputURL: URL, width: Int, height: Int) throws {
    self.outputURL = outputURL

    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.hevc,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
      ] as [String: Any],
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: max(80_000_000, width * height * 12),
        AVVideoExpectedSourceFrameRateKey: 60,
        AVVideoMaxKeyFrameIntervalKey: 60,
        AVVideoAllowFrameReorderingKey: false,
      ] as [String: Any],
    ]

    let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    input.expectsMediaDataInRealTime = true

    writer.add(input)

    self.assetWriter = writer
    self.videoInput = input
  }

  func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
    dispatchPrecondition(condition: .onQueue(queue))

    guard let assetWriter, let videoInput else { return }

    if !isStarted {
      guard assetWriter.startWriting() else {
        logger.error("Failed to start writing: \(assetWriter.error?.localizedDescription ?? "unknown")")
        return
      }
      let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      assetWriter.startSession(atSourceTime: timestamp)
      isStarted = true
      logger.info("Video writing started")
    }

    guard videoInput.isReadyForMoreMediaData else {
      droppedFrames += 1
      return
    }

    videoInput.append(sampleBuffer)
    writtenFrames += 1
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
