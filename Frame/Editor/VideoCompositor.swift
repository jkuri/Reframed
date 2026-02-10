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

        var audioFiles: [URL] = []
        if let sysURL = result.systemAudioURL { audioFiles.append(sysURL) }
        if let micURL = result.microphoneAudioURL { audioFiles.append(micURL) }

        for audioURL in audioFiles {
          let audioAsset = AVURLAsset(url: audioURL)
          if let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
            let compAudioTrack = composition.addMutableTrack(
              withMediaType: .audio,
              preferredTrackID: kCMPersistentTrackID_Invalid
            )
            let audioTimeRange = try await audioTrack.load(.timeRange)
            let audioDuration = CMTimeMinimum(audioTimeRange.duration, effectiveTrim.duration)
            let audioRange = CMTimeRange(
              start: effectiveTrim.start,
              duration: CMTimeMinimum(audioDuration, CMTimeSubtract(audioTimeRange.end, effectiveTrim.start))
            )
            if CMTimeCompare(audioRange.duration, .zero) > 0 {
              try compAudioTrack?.insertTimeRange(audioRange, of: audioTrack, at: .zero)
            }
          }
        }

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

    var audioFiles: [URL] = []
    if let sysURL = result.systemAudioURL { audioFiles.append(sysURL) }
    if let micURL = result.microphoneAudioURL { audioFiles.append(micURL) }

    for audioURL in audioFiles {
      let audioAsset = AVURLAsset(url: audioURL)
      if let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first {
        let compAudioTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
        let audioTimeRange = try await audioTrack.load(.timeRange)
        let audioRange = CMTimeRange(
          start: effectiveTrim.start,
          duration: CMTimeMinimum(audioTimeRange.duration, effectiveTrim.duration)
        )
        if CMTimeCompare(audioRange.duration, .zero) > 0 {
          try compAudioTrack?.insertTimeRange(audioRange, of: audioTrack, at: .zero)
        }
      }
    }

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
}
