import AVFoundation
import CoreMedia
import Foundation
import Logging

enum VideoCompositor {
  static let logger = Logger(label: "eu.jankuri.reframed.video-compositor")

  struct AudioSource {
    let url: URL
    let regions: [CMTimeRange]
    let volume: Float
  }

  static func export(
    result: RecordingResult,
    config: ExportConfiguration,
    progressHandler: (@MainActor @Sendable (Double, Double?) -> Void)? = nil
  ) async throws -> URL {
    let composition = AVMutableComposition()
    let screenAsset = AVURLAsset(url: result.screenVideoURL)

    guard let screenVideoTrack = try await screenAsset.loadTracks(withMediaType: .video).first else {
      throw CaptureError.recordingFailed("No video track in screen recording")
    }

    let screenNaturalSize = try await screenVideoTrack.load(.naturalSize)
    let screenTimeRange = try await screenVideoTrack.load(.timeRange)

    let effectiveTrim: CMTimeRange
    if config.trimRange.duration.isValid && CMTimeCompare(config.trimRange.duration, .zero) > 0 {
      effectiveTrim = config.trimRange
    } else {
      effectiveTrim = screenTimeRange
    }

    let hasVideoRegions = config.videoRegions != nil && !config.videoRegions!.isEmpty
    let compScreenTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: 1
    )

    var videoSegments: [VideoSegment] = []
    let compositionDuration: CMTime

    if hasVideoRegions, let vRegions = config.videoRegions {
      var insertTime = CMTime.zero
      for region in vRegions {
        let overlapStart = CMTimeMaximum(region.timeRange.start, effectiveTrim.start)
        let overlapEnd = CMTimeMinimum(region.timeRange.end, effectiveTrim.end)
        guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { continue }
        let segmentRange = CMTimeRange(start: overlapStart, end: overlapEnd)
        try compScreenTrack?.insertTimeRange(segmentRange, of: screenVideoTrack, at: insertTime)
        videoSegments.append(VideoSegment(sourceRange: segmentRange, compositionStart: insertTime))
        insertTime = CMTimeAdd(insertTime, segmentRange.duration)
      }
      compositionDuration = insertTime
    } else {
      try compScreenTrack?.insertTimeRange(effectiveTrim, of: screenVideoTrack, at: .zero)
      compositionDuration = effectiveTrim.duration
    }

    let (processedMicURL, shouldCleanupProcessedMic) = try await processMicrophoneAudio(
      result: result,
      config: config
    )

    let clickSoundURL = try generateClickSound(
      cursorSnapshot: config.cursorSnapshot,
      config: config,
      compositionDuration: compositionDuration,
      videoSegments: videoSegments,
      hasVideoRegions: hasVideoRegions,
      effectiveTrim: effectiveTrim
    )

    defer {
      if shouldCleanupProcessedMic, let url = processedMicURL {
        try? FileManager.default.removeItem(at: url)
      }
      if let url = clickSoundURL {
        try? FileManager.default.removeItem(at: url)
      }
    }

    let effectiveAudioRegions: [CMTimeRange] =
      hasVideoRegions
      ? videoSegments.map { $0.sourceRange }
      : [effectiveTrim]

    var audioSources: [AudioSource] = []
    if let sysURL = result.systemAudioURL, config.systemAudioVolume > 0 {
      let sysRegs = config.systemAudioRegions ?? effectiveAudioRegions
      audioSources.append(AudioSource(url: sysURL, regions: sysRegs, volume: config.systemAudioVolume))
    }
    if let micURL = result.microphoneAudioURL, config.micAudioVolume > 0 {
      let effectiveMicURL = processedMicURL ?? micURL
      let micRegs = config.micAudioRegions ?? effectiveAudioRegions
      audioSources.append(AudioSource(url: effectiveMicURL, regions: micRegs, volume: config.micAudioVolume))
    }
    if let csURL = clickSoundURL {
      let clickAsset = AVURLAsset(url: csURL)
      if let clickAudioTrack = try await clickAsset.loadTracks(withMediaType: .audio).first {
        let clickCompTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
        )
        try clickCompTrack?.insertTimeRange(
          CMTimeRange(start: .zero, duration: compositionDuration),
          of: clickAudioTrack,
          at: .zero
        )
      }
    }

    let needsCompositor = checkNeedsCompositor(
      result: result,
      config: config,
      clickSoundURL: clickSoundURL,
      hasVideoRegions: hasVideoRegions,
      screenNaturalSize: screenNaturalSize
    )

    let canvasSize = computeCanvasSize(
      screenNaturalSize: screenNaturalSize,
      canvasAspect: config.canvasAspect,
      padding: config.padding
    )
    let renderSize = computeRenderSize(
      canvasSize: canvasSize,
      resolution: config.exportSettings.resolution
    )
    let exportFPS = config.exportSettings.fps.value(fallback: result.fps)

    if needsCompositor {
      let instruction = try await buildCompositionInstruction(
        composition: composition,
        result: result,
        config: config,
        effectiveTrim: effectiveTrim,
        screenNaturalSize: screenNaturalSize,
        hasVideoRegions: hasVideoRegions,
        videoSegments: videoSegments,
        compositionDuration: compositionDuration,
        canvasSize: canvasSize,
        renderSize: renderSize
      )

      if config.exportSettings.format.isGIF {
        let outputURL = FileManager.default.tempGIFURL()
        try await gifExport(
          composition: composition,
          instruction: instruction,
          renderSize: renderSize,
          fps: exportFPS,
          trimDuration: compositionDuration,
          outputURL: outputURL,
          gifQuality: config.exportSettings.gifQuality.value,
          progressHandler: progressHandler
        )

        let destination = await MainActor.run {
          FileManager.default.defaultSaveURL(for: outputURL, extension: "gif")
        }
        try FileManager.default.moveToFinal(from: outputURL, to: destination)

        logger.info("GIF export saved: \(destination.path)")
        return destination
      }

      let audioSegInfo: [VideoSegmentInfo]? =
        hasVideoRegions
        ? videoSegments.map {
          VideoSegmentInfo(sourceRange: $0.sourceRange, compositionStart: $0.compositionStart)
        }
        : nil
      try await addAudioTracks(
        to: composition,
        sources: audioSources,
        videoTrimRange: effectiveTrim,
        videoSegments: audioSegInfo
      )
      let audioMix = buildAudioMix(for: composition, sources: audioSources)

      let outputURL = FileManager.default.tempRecordingURL()

      if config.exportSettings.mode == ExportMode.parallel {
        try await parallelRenderExport(
          composition: composition,
          instruction: instruction,
          renderSize: renderSize,
          fps: exportFPS,
          trimDuration: compositionDuration,
          outputURL: outputURL,
          fileType: config.exportSettings.format.fileType,
          codec: config.exportSettings.codec,
          audioMix: audioMix,
          audioBitrate: config.exportSettings.audioBitrate.value,
          isHDR: result.isHDR,
          progressHandler: progressHandler
        )
      } else {
        try await runManualExport(
          composition: composition,
          instruction: instruction,
          renderSize: renderSize,
          fps: exportFPS,
          trimDuration: compositionDuration,
          outputURL: outputURL,
          fileType: config.exportSettings.format.fileType,
          codec: config.exportSettings.codec,
          audioMix: audioMix,
          audioBitrate: config.exportSettings.audioBitrate.value,
          isHDR: result.isHDR,
          progressHandler: progressHandler
        )
      }

      let destination = await MainActor.run {
        FileManager.default.defaultSaveURL(
          for: outputURL,
          extension: config.exportSettings.format.fileExtension
        )
      }
      try FileManager.default.moveToFinal(from: outputURL, to: destination)

      logger.info("Composited export saved: \(destination.path)")
      return destination
    }

    try await addAudioTracks(
      to: composition,
      sources: audioSources,
      videoTrimRange: effectiveTrim
    )

    let outputURL = FileManager.default.tempRecordingURL()
    guard
      let exportSession = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPresetPassthrough
      )
    else {
      throw CaptureError.recordingFailed("Failed to create export session")
    }

    exportSession.timeRange = CMTimeRange(start: .zero, duration: effectiveTrim.duration)
    if let audioMix = buildAudioMix(for: composition, sources: audioSources) {
      exportSession.audioMix = audioMix
    }
    try await runExport(
      exportSession,
      to: outputURL,
      fileType: config.exportSettings.format.fileType,
      progressHandler: progressHandler
    )

    let destination = await MainActor.run {
      FileManager.default.defaultSaveURL(
        for: outputURL,
        extension: config.exportSettings.format.fileExtension
      )
    }
    try FileManager.default.moveToFinal(from: outputURL, to: destination)

    logger.info("Passthrough export saved: \(destination.path)")
    return destination
  }
}
