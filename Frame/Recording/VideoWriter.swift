import AVFoundation
import CoreMedia
import CoreVideo
import Logging

actor VideoWriter {
  private var assetWriter: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var isStarted = false
  private let outputURL: URL
  private let logger = Logger(label: "com.frame.video-writer")

  init(outputURL: URL, width: Int, height: Int) throws {
    self.outputURL = outputURL

    // Remove file if it already exists
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: width * height * 8,
        AVVideoExpectedSourceFrameRateKey: 30,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      ] as [String: Any],
    ]

    let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    input.expectsMediaDataInRealTime = true

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
      ]
    )

    writer.add(input)

    self.assetWriter = writer
    self.videoInput = input
    self.adaptor = adaptor
  }

  func appendPixelBuffer(_ pixelBuffer: CVPixelBuffer, at timestamp: CMTime) {
    guard let assetWriter, let videoInput, let adaptor else { return }

    if !isStarted {
      guard assetWriter.startWriting() else {
        logger.error("Failed to start writing: \(assetWriter.error?.localizedDescription ?? "unknown")")
        return
      }
      assetWriter.startSession(atSourceTime: timestamp)
      isStarted = true
      logger.info("Video writing started")
    }

    guard videoInput.isReadyForMoreMediaData else { return }

    adaptor.append(pixelBuffer, withPresentationTime: timestamp)
  }

  func finish() async -> URL? {
    guard let assetWriter, let videoInput else { return nil }

    guard isStarted else {
      logger.warning("Writer was never started, nothing to finish")
      return nil
    }

    videoInput.markAsFinished()

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      assetWriter.finishWriting {
        continuation.resume()
      }
    }

    if assetWriter.status == .completed {
      logger.info("Video writing finished: \(outputURL.lastPathComponent)")
      return outputURL
    } else {
      logger.error("Video writing failed: \(assetWriter.error?.localizedDescription ?? "unknown")")
      return nil
    }
  }
}
