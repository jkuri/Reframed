import AVFoundation
import CoreMedia
import Foundation
import Logging

enum VideoCompositor {
  private static let logger = Logger(label: "eu.jankuri.frame.video-compositor")

  static func export(
    result: RecordingResult,
    pipLayout: PiPLayout,
    trimRange: CMTimeRange
  ) async throws -> URL {
    let composition = AVMutableComposition()
    let screenAsset = AVURLAsset(url: result.screenVideoURL)

    guard let screenVideoTrack = try await screenAsset.loadTracks(withMediaType: .video).first else {
      throw CaptureError.recordingFailed("No video track in screen recording")
    }

    let screenNaturalSize = try await screenVideoTrack.load(.naturalSize)
    let screenTimeRange = try await screenVideoTrack.load(.timeRange)

    let effectiveTrim: CMTimeRange
    if trimRange.duration.isValid && CMTimeCompare(trimRange.duration, .zero) > 0 {
      effectiveTrim = trimRange
    } else {
      effectiveTrim = screenTimeRange
    }

    let compScreenTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: 1
    )
    try compScreenTrack?.insertTimeRange(effectiveTrim, of: screenVideoTrack, at: .zero)

    var audioFiles: [URL] = []
    if let sysURL = result.systemAudioURL { audioFiles.append(sysURL) }
    if let micURL = result.microphoneAudioURL { audioFiles.append(micURL) }

    let mixedAudioURL: URL?
    if audioFiles.count > 1 {
      mixedAudioURL = try await mixAudioFiles(audioFiles)
    } else {
      mixedAudioURL = audioFiles.first
    }

    if let webcamURL = result.webcamVideoURL, let webcamSize = result.webcamSize {
      let webcamAsset = AVURLAsset(url: webcamURL)
      if let webcamVideoTrack = try await webcamAsset.loadTracks(withMediaType: .video).first {
        let wTrack = composition.addMutableTrack(
          withMediaType: .video,
          preferredTrackID: 2
        )
        try wTrack?.insertTimeRange(effectiveTrim, of: webcamVideoTrack, at: .zero)
        let pipRect = pipLayout.pixelRect(screenSize: screenNaturalSize, webcamSize: webcamSize)

        let instruction = PiPCompositionInstruction(
          timeRange: CMTimeRange(start: .zero, duration: effectiveTrim.duration),
          screenTrackID: 1,
          webcamTrackID: 2,
          pipRect: pipRect,
          cornerRadius: 12,
          outputSize: screenNaturalSize
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = PiPVideoCompositor.self
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(result.fps))
        videoComposition.renderSize = screenNaturalSize
        videoComposition.instructions = [instruction]

        try await addAudioTrack(to: composition, from: mixedAudioURL, trimRange: effectiveTrim)

        let outputURL = FileManager.default.tempRecordingURL()
        guard let exportSession = AVAssetExportSession(
          asset: composition,
          presetName: AVAssetExportPresetHighestQuality
        ) else {
          throw CaptureError.recordingFailed("Failed to create export session")
        }

        exportSession.videoComposition = videoComposition
        exportSession.timeRange = CMTimeRange(start: .zero, duration: effectiveTrim.duration)
        try await exportSession.export(to: outputURL, as: .mp4)

        let destination = await MainActor.run { FileManager.default.defaultSaveURL(for: outputURL) }
        try FileManager.default.moveToFinal(from: outputURL, to: destination)
        FileManager.default.cleanupTempDir()

        logger.info("Composited export saved: \(destination.path)")
        return destination
      }
    }

    try await addAudioTrack(to: composition, from: mixedAudioURL, trimRange: effectiveTrim)

    let outputURL = FileManager.default.tempRecordingURL()
    guard let exportSession = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetPassthrough
    ) else {
      throw CaptureError.recordingFailed("Failed to create export session")
    }

    exportSession.timeRange = CMTimeRange(start: .zero, duration: effectiveTrim.duration)
    try await exportSession.export(to: outputURL, as: .mp4)

    let destination = await MainActor.run { FileManager.default.defaultSaveURL(for: outputURL) }
    try FileManager.default.moveToFinal(from: outputURL, to: destination)
    FileManager.default.cleanupTempDir()

    logger.info("Passthrough export saved: \(destination.path)")
    return destination
  }

  private static func addAudioTrack(
    to composition: AVMutableComposition,
    from audioURL: URL?,
    trimRange: CMTimeRange
  ) async throws {
    guard let audioURL else { return }
    let audioAsset = AVURLAsset(url: audioURL)
    guard let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else { return }
    let audioTimeRange = try await audioTrack.load(.timeRange)
    let audioDuration = CMTimeMinimum(audioTimeRange.duration, trimRange.duration)
    let audioRange = CMTimeRange(
      start: trimRange.start,
      duration: CMTimeMinimum(audioDuration, CMTimeSubtract(audioTimeRange.end, trimRange.start))
    )
    guard CMTimeCompare(audioRange.duration, .zero) > 0 else { return }
    let compAudioTrack = composition.addMutableTrack(
      withMediaType: .audio,
      preferredTrackID: kCMPersistentTrackID_Invalid
    )
    try compAudioTrack?.insertTimeRange(audioRange, of: audioTrack, at: .zero)
  }

  private static func mixAudioFiles(_ files: [URL]) async throws -> URL {
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

    let outputURL = FileManager.default.tempRecordingURL()
      .deletingLastPathComponent()
      .appendingPathComponent("mixed-audio.m4a")
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    guard let exportSession = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetAppleM4A
    ) else {
      throw CaptureError.recordingFailed("Failed to create audio mix session")
    }

    exportSession.audioMix = audioMix
    try await exportSession.export(to: outputURL, as: .m4a)

    logger.info("Audio mix finished: \(files.count) tracks -> \(outputURL.lastPathComponent)")
    return outputURL
  }
}
