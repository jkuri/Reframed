import AVFoundation
import Logging

enum VideoTranscoder {
  private static let logger = Logger(label: "eu.jankuri.frame.video-transcoder")

  static func merge(videoFile: URL, audioFiles: [URL], to outputURL: URL) async throws -> URL {
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let mixedAudioURL: URL?

    if audioFiles.count > 1 {
      let tempMixed = outputURL.deletingLastPathComponent().appendingPathComponent("mixed-audio.m4a")
      if FileManager.default.fileExists(atPath: tempMixed.path) {
        try FileManager.default.removeItem(at: tempMixed)
      }
      mixedAudioURL = try await mixAudioFiles(audioFiles, to: tempMixed)
    } else {
      mixedAudioURL = audioFiles.first
    }

    let composition = AVMutableComposition()

    let videoAsset = AVURLAsset(url: videoFile)
    let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
    if let sourceVideoTrack = videoTracks.first {
      let timeRange = try await sourceVideoTrack.load(.timeRange)
      let compositionVideoTrack = composition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
      )
      try compositionVideoTrack?.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
    }

    if let audioURL = mixedAudioURL {
      let audioAsset = AVURLAsset(url: audioURL)
      let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
      if let sourceAudioTrack = audioTracks.first {
        let timeRange = try await sourceAudioTrack.load(.timeRange)
        let compositionAudioTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
        try compositionAudioTrack?.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
      }
    }

    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
      throw CaptureError.recordingFailed("Failed to create export session")
    }

    try await exportSession.export(to: outputURL, as: .mp4)

    try? FileManager.default.removeItem(at: videoFile)
    for audioFile in audioFiles {
      try? FileManager.default.removeItem(at: audioFile)
    }
    if audioFiles.count > 1, let mixed = mixedAudioURL {
      try? FileManager.default.removeItem(at: mixed)
    }

    logger.info("Merge finished: \(outputURL.lastPathComponent)")
    return outputURL
  }

  private static func mixAudioFiles(_ audioFiles: [URL], to outputURL: URL) async throws -> URL {
    let composition = AVMutableComposition()

    for audioFile in audioFiles {
      let asset = AVURLAsset(url: audioFile)
      let tracks = try await asset.loadTracks(withMediaType: .audio)
      if let sourceTrack = tracks.first {
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

    logger.info("Audio mix finished: \(audioFiles.count) tracks -> \(outputURL.lastPathComponent)")
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
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
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
        AVVideoAverageBitRateKey: width * height * 12,
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
      let queue = DispatchQueue(label: "eu.jankuri.frame.video-transcoder.queue")
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
