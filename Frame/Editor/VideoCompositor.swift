import AVFoundation
import CoreMedia
import Foundation
import Logging

enum VideoCompositor {
  private static let logger = Logger(label: "eu.jankuri.frame.video-compositor")

  static func export(
    result: RecordingResult,
    pipLayout: PiPLayout,
    trimRange: CMTimeRange,
    backgroundStyle: BackgroundStyle = .none,
    padding: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    pipCornerRadius: CGFloat = 12,
    pipBorderWidth: CGFloat = 0,
    exportSettings: ExportSettings = ExportSettings(),
    progressHandler: (@MainActor @Sendable (Double) -> Void)? = nil
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

    let hasVisualEffects = backgroundStyle != .none || padding > 0 || videoCornerRadius > 0
    let hasWebcam = result.webcamVideoURL != nil
    let needsReencode =
      exportSettings.codec != .h264 || exportSettings.resolution != .original
      || exportSettings.fps != .original
    let needsCompositor = hasVisualEffects || hasWebcam || needsReencode

    let canvasSize: CGSize
    if padding > 0 {
      let scale = 1.0 + 2.0 * padding
      canvasSize = CGSize(width: screenNaturalSize.width * scale, height: screenNaturalSize.height * scale)
    } else {
      canvasSize = screenNaturalSize
    }

    let renderSize: CGSize
    if let targetWidth = exportSettings.resolution.pixelWidth {
      let aspect = canvasSize.height / max(canvasSize.width, 1)
      renderSize = CGSize(width: targetWidth, height: round(targetWidth * aspect))
    } else {
      renderSize = canvasSize
    }

    let exportFPS = exportSettings.fps.value(fallback: result.fps)

    if needsCompositor {
      var webcamTrackID: CMPersistentTrackID?
      var pipRect: CGRect?

      if let webcamURL = result.webcamVideoURL, let webcamSize = result.webcamSize {
        let webcamAsset = AVURLAsset(url: webcamURL)
        if let webcamVideoTrack = try await webcamAsset.loadTracks(withMediaType: .video).first {
          let wTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: 2
          )
          try wTrack?.insertTimeRange(effectiveTrim, of: webcamVideoTrack, at: .zero)
          webcamTrackID = 2
          pipRect = pipLayout.pixelRect(screenSize: screenNaturalSize, webcamSize: webcamSize)
        }
      }

      let bgColors = backgroundColorTuples(for: backgroundStyle)
      let bgStartPoint: CGPoint
      let bgEndPoint: CGPoint
      if case .gradient(let id) = backgroundStyle, let preset = GradientPresets.preset(for: id) {
        bgStartPoint = preset.cgStartPoint
        bgEndPoint = preset.cgEndPoint
      } else {
        bgStartPoint = .zero
        bgEndPoint = CGPoint(x: 0, y: 1)
      }

      let scaleX = renderSize.width / canvasSize.width
      let scaleY = renderSize.height / canvasSize.height
      let paddingHPx = padding * screenNaturalSize.width * scaleX
      let paddingVPx = padding * screenNaturalSize.height * scaleY
      let scaledCornerRadius = videoCornerRadius * scaleX

      let instruction = CompositionInstruction(
        timeRange: CMTimeRange(start: .zero, duration: effectiveTrim.duration),
        screenTrackID: 1,
        webcamTrackID: webcamTrackID,
        pipRect: pipRect.map { rect in
          let scaleX = renderSize.width / canvasSize.width
          let scaleY = renderSize.height / canvasSize.height
          return CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
          )
        },
        pipCornerRadius: pipCornerRadius * (renderSize.width / canvasSize.width),
        pipBorderWidth: pipBorderWidth * (renderSize.width / canvasSize.width),
        outputSize: renderSize,
        backgroundColors: bgColors,
        backgroundStartPoint: bgStartPoint,
        backgroundEndPoint: bgEndPoint,
        paddingH: paddingHPx,
        paddingV: paddingVPx,
        videoCornerRadius: scaledCornerRadius,
        canvasSize: renderSize
      )

      let videoComposition = AVMutableVideoComposition()
      videoComposition.customVideoCompositorClass = PiPVideoCompositor.self
      videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(exportFPS))
      videoComposition.renderSize = renderSize
      videoComposition.instructions = [instruction]

      try await addAudioTrack(to: composition, from: mixedAudioURL, trimRange: effectiveTrim)

      let outputURL = FileManager.default.tempRecordingURL()
      guard
        let exportSession = AVAssetExportSession(
          asset: composition,
          presetName: exportSettings.codec.exportPreset
        )
      else {
        throw CaptureError.recordingFailed("Failed to create export session")
      }

      exportSession.videoComposition = videoComposition
      exportSession.timeRange = CMTimeRange(start: .zero, duration: effectiveTrim.duration)
      try await runExport(exportSession, to: outputURL, fileType: exportSettings.format.fileType, progressHandler: progressHandler)

      let destination = await MainActor.run { FileManager.default.defaultSaveURL(for: outputURL, extension: exportSettings.format.fileExtension) }
      try FileManager.default.moveToFinal(from: outputURL, to: destination)
      if let mixURL = mixedAudioURL, mixURL.lastPathComponent == "mixed-audio.m4a" {
        try? FileManager.default.removeItem(at: mixURL)
      }

      logger.info("Composited export saved: \(destination.path)")
      return destination
    }

    try await addAudioTrack(to: composition, from: mixedAudioURL, trimRange: effectiveTrim)

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
    try await runExport(exportSession, to: outputURL, fileType: exportSettings.format.fileType, progressHandler: progressHandler)

    let destination = await MainActor.run { FileManager.default.defaultSaveURL(for: outputURL, extension: exportSettings.format.fileExtension) }
    try FileManager.default.moveToFinal(from: outputURL, to: destination)
    if let mixURL = mixedAudioURL, mixURL.lastPathComponent == "mixed-audio.m4a" {
      try? FileManager.default.removeItem(at: mixURL)
    }

    logger.info("Passthrough export saved: \(destination.path)")
    return destination
  }

  private final class ExportProgressPoller: @unchecked Sendable {
    private let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
    var progress: Double { Double(session.progress) }
  }

  private static func runExport(
    _ session: AVAssetExportSession,
    to url: URL,
    fileType: AVFileType = .mp4,
    progressHandler: (@MainActor @Sendable (Double) -> Void)?
  ) async throws {
    let progressTask: Task<Void, Never>?
    if let progressHandler {
      let poller = ExportProgressPoller(session)
      progressTask = Task.detached {
        while !Task.isCancelled {
          await progressHandler(poller.progress)
          try? await Task.sleep(nanoseconds: 200_000_000)
        }
      }
    } else {
      progressTask = nil
    }
    try await session.export(to: url, as: fileType)
    progressTask?.cancel()
  }

  private static func backgroundColorTuples(
    for style: BackgroundStyle
  ) -> [(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)] {
    switch style {
    case .none:
      return []
    case .gradient(let id):
      guard let preset = GradientPresets.preset(for: id) else { return [] }
      return preset.cgColors.map { color in
        let components = color.components ?? [0, 0, 0, 1]
        if components.count >= 4 {
          return (r: components[0], g: components[1], b: components[2], a: components[3])
        } else if components.count >= 2 {
          return (r: components[0], g: components[0], b: components[0], a: components[1])
        }
        return (r: 0, g: 0, b: 0, a: 1)
      }
    case .solidColor(let color):
      return [(r: color.r, g: color.g, b: color.b, a: color.a)]
    }
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

    guard
      let exportSession = AVAssetExportSession(
        asset: composition,
        presetName: AVAssetExportPresetAppleM4A
      )
    else {
      throw CaptureError.recordingFailed("Failed to create audio mix session")
    }

    exportSession.audioMix = audioMix
    try await exportSession.export(to: outputURL, as: .m4a)

    logger.info("Audio mix finished: \(files.count) tracks -> \(outputURL.lastPathComponent)")
    return outputURL
  }
}
