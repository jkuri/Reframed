import AVFoundation
import CoreMedia
import Foundation
import Logging

enum VideoCompositor {
  private static let logger = Logger(label: "eu.jankuri.reframed.video-compositor")

  private struct AudioSource {
    let url: URL
    let trimRange: CMTimeRange
  }

  static func export(
    result: RecordingResult,
    pipLayout: PiPLayout,
    trimRange: CMTimeRange,
    systemAudioTrimRange: CMTimeRange? = nil,
    micAudioTrimRange: CMTimeRange? = nil,
    backgroundStyle: BackgroundStyle = .none,
    padding: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    pipCornerRadius: CGFloat = 12,
    pipBorderWidth: CGFloat = 0,
    exportSettings: ExportSettings = ExportSettings(),
    cursorSnapshot: CursorMetadataSnapshot? = nil,
    cursorStyle: CursorStyle = .defaultArrow,
    cursorSize: CGFloat = 24,
    cursorSmoothing: CursorSmoothing = .standard,
    showClickHighlights: Bool = true,
    clickHighlightColor: CGColor = CGColor(srgbRed: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
    clickHighlightSize: CGFloat = 36,
    zoomFollowCursor: Bool = true,
    zoomTimeline: ZoomTimeline? = nil,
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

    var audioSources: [AudioSource] = []
    if let sysURL = result.systemAudioURL {
      audioSources.append(AudioSource(url: sysURL, trimRange: systemAudioTrimRange ?? effectiveTrim))
    }
    if let micURL = result.microphoneAudioURL {
      audioSources.append(AudioSource(url: micURL, trimRange: micAudioTrimRange ?? effectiveTrim))
    }

    let hasVisualEffects = backgroundStyle != .none || padding > 0 || videoCornerRadius > 0
    let hasWebcam = result.webcamVideoURL != nil
    let hasCursor = cursorSnapshot != nil
    let hasZoom = zoomTimeline != nil
    let needsReencode =
      exportSettings.codec != .h264 || exportSettings.resolution != .original
      || exportSettings.fps != .original
    let needsCompositor = hasVisualEffects || hasWebcam || needsReencode || hasCursor || hasZoom

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
        pipCornerRadius: {
          guard let rect = pipRect else { return 0 }
          let sX = renderSize.width / canvasSize.width
          let sY = renderSize.height / canvasSize.height
          let scaledW = rect.width * sX
          let scaledH = rect.height * sY
          return min(scaledW, scaledH) * (pipCornerRadius / 100.0)
        }(),
        pipBorderWidth: pipBorderWidth * (renderSize.width / canvasSize.width),
        outputSize: renderSize,
        backgroundColors: bgColors,
        backgroundStartPoint: bgStartPoint,
        backgroundEndPoint: bgEndPoint,
        paddingH: paddingHPx,
        paddingV: paddingVPx,
        videoCornerRadius: scaledCornerRadius,
        canvasSize: renderSize,
        cursorSnapshot: cursorSnapshot,
        cursorStyle: cursorStyle,
        cursorSize: cursorSize,
        cursorSmoothing: cursorSmoothing,
        showCursor: cursorSnapshot != nil,
        showClickHighlights: showClickHighlights,
        clickHighlightColor: clickHighlightColor,
        clickHighlightSize: clickHighlightSize,
        zoomFollowCursor: zoomFollowCursor,
        zoomTimeline: zoomTimeline,
        trimStartSeconds: CMTimeGetSeconds(effectiveTrim.start)
      )

      let videoComposition = AVMutableVideoComposition()
      videoComposition.customVideoCompositorClass = PiPVideoCompositor.self
      videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(exportFPS))
      videoComposition.renderSize = renderSize
      videoComposition.instructions = [instruction]

      try await addAudioTracks(to: composition, sources: audioSources, videoTrimRange: effectiveTrim)

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

      let destination = await MainActor.run {
        FileManager.default.defaultSaveURL(for: outputURL, extension: exportSettings.format.fileExtension)
      }
      try FileManager.default.moveToFinal(from: outputURL, to: destination)

      logger.info("Composited export saved: \(destination.path)")
      return destination
    }

    try await addAudioTracks(to: composition, sources: audioSources, videoTrimRange: effectiveTrim)

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

    let destination = await MainActor.run {
      FileManager.default.defaultSaveURL(for: outputURL, extension: exportSettings.format.fileExtension)
    }
    try FileManager.default.moveToFinal(from: outputURL, to: destination)

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

  private static func addAudioTracks(
    to composition: AVMutableComposition,
    sources: [AudioSource],
    videoTrimRange: CMTimeRange
  ) async throws {
    for source in sources {
      let asset = AVURLAsset(url: source.url)
      guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else { continue }

      let overlapStart = CMTimeMaximum(source.trimRange.start, videoTrimRange.start)
      let overlapEnd = CMTimeMinimum(source.trimRange.end, videoTrimRange.end)
      guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { continue }

      let sourceRange = CMTimeRange(start: overlapStart, end: overlapEnd)
      let insertionTime = CMTimeSubtract(overlapStart, videoTrimRange.start)

      let compTrack = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
      )
      try compTrack?.insertTimeRange(sourceRange, of: audioTrack, at: insertionTime)
    }
  }
}
