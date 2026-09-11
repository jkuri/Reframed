import AVFoundation
import CoreMedia
import Foundation

extension VideoCompositor {
  static func processMicrophoneAudio(
    result: RecordingResult,
    config: ExportConfiguration
  ) async throws -> (URL?, Bool) {
    guard let micURL = result.microphoneAudioURL,
      config.micNoiseReductionEnabled,
      config.micAudioVolume > 0,
      !TimeLapse.dropsAudio(speed: config.playbackSpeed)
    else { return (nil, false) }

    if let cachedURL = config.processedMicAudioURL,
      FileManager.default.fileExists(atPath: cachedURL.path)
    {
      return (cachedURL, false)
    }

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("reframed-nr-\(UUID().uuidString).m4a")
    try await RNNoiseProcessor.processFile(
      inputURL: micURL,
      outputURL: tempURL,
      intensity: config.micNoiseReductionIntensity
    )
    return (tempURL, true)
  }

  static func generateClickSound(
    cursorSnapshot: CursorMetadataSnapshot?,
    config: ExportConfiguration,
    compositionDuration: CMTime,
    videoSegments: [VideoSegment],
    hasVideoRegions: Bool,
    effectiveTrim: CMTimeRange
  ) throws -> URL? {
    guard config.clickSoundEnabled,
      !TimeLapse.dropsAudio(speed: config.playbackSpeed),
      let snapshot = cursorSnapshot,
      !snapshot.clicks.isEmpty
    else { return nil }

    let totalDur = CMTimeGetSeconds(compositionDuration)
    let clicks: [(time: Double, button: Int)]

    if hasVideoRegions, !videoSegments.isEmpty {
      clicks = snapshot.clicks.compactMap { click in
        for seg in videoSegments {
          let segStart = CMTimeGetSeconds(seg.sourceRange.start)
          let segEnd = CMTimeGetSeconds(seg.sourceRange.end)
          guard click.t >= segStart, click.t <= segEnd else { continue }
          let compStart = CMTimeGetSeconds(seg.compositionStart)
          return (time: compStart + (click.t - segStart), button: click.button)
        }
        return nil
      }
    } else {
      let trimStartSec = CMTimeGetSeconds(effectiveTrim.start)
      let trimEndSec = CMTimeGetSeconds(effectiveTrim.end)
      clicks = snapshot.clicks.compactMap {
        guard $0.t >= trimStartSec, $0.t <= trimEndSec else { return nil }
        return (time: $0.t - trimStartSec, button: $0.button)
      }
    }

    guard !clicks.isEmpty else { return nil }

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("reframed-clicks-\(UUID().uuidString).m4a")
    try ClickSoundGenerator.generateClickAudioFile(
      at: tempURL,
      clickTimes: clicks,
      volume: config.clickSoundVolume,
      totalDuration: totalDur,
      style: config.clickSoundStyle
    )
    return tempURL
  }
}
