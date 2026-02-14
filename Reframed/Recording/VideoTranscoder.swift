import AVFoundation
import CoreMedia
import Logging

enum VideoTranscoder {
  private static let logger = Logger(label: "eu.jankuri.reframed.video-transcoder")

  static func merge(
    videoFile: URL,
    audioFiles: [URL],
    to outputURL: URL
  ) async throws -> URL {
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let videoAsset = AVURLAsset(url: videoFile)
    guard let sourceVideoTrack = try await videoAsset.loadTracks(withMediaType: .video).first else {
      throw CaptureError.recordingFailed("No video track found")
    }
    let videoTimeRange = try await sourceVideoTrack.load(.timeRange)
    let videoDuration = videoTimeRange.duration

    let mixedAudioURL: URL?
    var isTempMix = false

    if audioFiles.count > 1 {
      let tempMixed = outputURL.deletingLastPathComponent().appendingPathComponent("mixed-audio.m4a")
      if FileManager.default.fileExists(atPath: tempMixed.path) {
        try FileManager.default.removeItem(at: tempMixed)
      }
      mixedAudioURL = try await mixAudioFiles(audioFiles, to: tempMixed)
      isTempMix = true
    } else {
      mixedAudioURL = audioFiles.first
    }

    let composition = AVMutableComposition()

    let compVideoTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: kCMPersistentTrackID_Invalid
    )
    try compVideoTrack?.insertTimeRange(videoTimeRange, of: sourceVideoTrack, at: .zero)

    if let audioURL = mixedAudioURL {
      let audioAsset = AVURLAsset(url: audioURL)
      if let sourceAudioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
        let audioTimeRange = try await sourceAudioTrack.load(.timeRange)
        let audioDuration = CMTimeMinimum(audioTimeRange.duration, videoDuration)

        logger.info(
          "A/V merge: videoDuration=\(String(format: "%.3f", CMTimeGetSeconds(videoDuration)))s, audioDuration=\(String(format: "%.3f", CMTimeGetSeconds(audioTimeRange.duration)))s"
        )

        if CMTimeCompare(audioDuration, .zero) > 0 {
          let compAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
          )
          let sourceRange = CMTimeRange(start: audioTimeRange.start, duration: audioDuration)
          try compAudioTrack?.insertTimeRange(sourceRange, of: sourceAudioTrack, at: .zero)
        }
      }
    }

    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
      throw CaptureError.recordingFailed("Failed to create export session")
    }

    exportSession.timeRange = CMTimeRange(start: .zero, duration: videoDuration)
    try await exportSession.export(to: outputURL, as: .mp4)

    try? FileManager.default.removeItem(at: videoFile)
    for file in audioFiles {
      try? FileManager.default.removeItem(at: file)
    }
    if isTempMix, let mixed = mixedAudioURL {
      try? FileManager.default.removeItem(at: mixed)
    }

    logger.info("Merge finished: \(outputURL.lastPathComponent)")
    return outputURL
  }

  private static func mixAudioFiles(_ files: [URL], to outputURL: URL) async throws -> URL {
    let composition = AVMutableComposition()

    for file in files {
      let asset = AVURLAsset(url: file)
      if let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first {
        let timeRange = try await sourceTrack.load(.timeRange)
        let compTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
        try compTrack?.insertTimeRange(timeRange, of: sourceTrack, at: .zero)
      }
    }

    let audioMix = AVMutableAudioMix()
    audioMix.inputParameters = composition.tracks(withMediaType: .audio).map { track in
      let params = AVMutableAudioMixInputParameters(track: track)
      params.setVolume(1.0, at: .zero)
      return params
    }

    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
      throw CaptureError.recordingFailed("Failed to create audio mix session")
    }

    exportSession.audioMix = audioMix
    try await exportSession.export(to: outputURL, as: .m4a)

    logger.info("Audio mix finished: \(files.count) tracks -> \(outputURL.lastPathComponent)")
    return outputURL
  }

  static func transcode(input inputURL: URL, to outputURL: URL) async throws -> URL {
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let asset = AVURLAsset(url: inputURL)
    let videoTrack = try await asset.loadTracks(withMediaType: .video).first!
    let naturalSize = try await videoTrack.load(.naturalSize)
    let width = Int(naturalSize.width)
    let height = Int(naturalSize.height)

    let reader = try AVAssetReader(asset: asset)
    let readerOutput = AVAssetReaderTrackOutput(
      track: videoTrack,
      outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
      ]
    )
    readerOutput.alwaysCopiesSampleData = false
    reader.add(readerOutput)

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let videoSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.hevc,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: width * height * 5,
        AVVideoExpectedSourceFrameRateKey: 60,
        AVVideoMaxKeyFrameIntervalKey: 120,
      ] as [String: Any],
    ]
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    writerInput.expectsMediaDataInRealTime = false
    writer.add(writerInput)

    reader.startReading()
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    logger.info("Transcoding started: \(inputURL.lastPathComponent)")

    nonisolated(unsafe) let input = writerInput
    nonisolated(unsafe) let output = readerOutput
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let queue = DispatchQueue(label: "eu.jankuri.reframed.video-transcoder.queue")
      input.requestMediaDataWhenReady(on: queue) {
        while input.isReadyForMoreMediaData {
          guard let sampleBuffer = output.copyNextSampleBuffer() else {
            input.markAsFinished()
            continuation.resume()
            return
          }
          input.append(sampleBuffer)
        }
      }
    }

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      writer.finishWriting {
        continuation.resume()
      }
    }

    guard writer.status == .completed else {
      throw CaptureError.recordingFailed(writer.error?.localizedDescription ?? "Transcode failed")
    }

    try FileManager.default.removeItem(at: inputURL)
    logger.info("Transcoding finished: \(outputURL.lastPathComponent)")

    return outputURL
  }
}
