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
    cameraLayout: CameraLayout,
    cameraAspect: CameraAspect = .original,
    trimRange: CMTimeRange,
    systemAudioRegions: [CMTimeRange]? = nil,
    micAudioRegions: [CMTimeRange]? = nil,
    cameraFullscreenRegions: [CameraRegionInfo]? = nil,
    cameraHiddenRegions: [CameraRegionInfo]? = nil,
    cameraCustomRegions: [CameraCustomRegion]? = nil,
    backgroundStyle: BackgroundStyle = .none,
    backgroundImageURL: URL? = nil,
    backgroundImageFillMode: BackgroundImageFillMode = .fill,
    canvasAspect: CanvasAspect = .original,
    padding: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    cameraCornerRadius: CGFloat = 12,
    cameraBorderWidth: CGFloat = 0,
    cameraBorderColor: CodableColor = CodableColor(r: 1, g: 1, b: 1, a: 0.3),
    videoShadow: CGFloat = 0,
    cameraShadow: CGFloat = 0,
    cameraMirrored: Bool = false,
    cameraFullscreenFillMode: CameraFullscreenFillMode = .fit,
    cameraFullscreenAspect: CameraFullscreenAspect = .original,
    exportSettings: ExportSettings = ExportSettings(),
    cursorSnapshot: CursorMetadataSnapshot? = nil,
    cursorStyle: CursorStyle = .defaultArrow,
    cursorSize: CGFloat = 24,
    showClickHighlights: Bool = true,
    clickHighlightColor: CGColor = CGColor(srgbRed: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
    clickHighlightSize: CGFloat = 36,
    zoomFollowCursor: Bool = true,
    zoomTimeline: ZoomTimeline? = nil,
    systemAudioVolume: Float = 1.0,
    micAudioVolume: Float = 1.0,
    micNoiseReductionEnabled: Bool = false,
    micNoiseReductionIntensity: Float = 0.5,
    processedMicAudioURL: URL? = nil,
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

    var processedMicURL: URL?
    var shouldCleanupProcessedMic = false
    if let micURL = result.microphoneAudioURL, micNoiseReductionEnabled, micAudioVolume > 0 {
      if let cachedURL = processedMicAudioURL, FileManager.default.fileExists(atPath: cachedURL.path) {
        processedMicURL = cachedURL
      } else {
        let tempURL = FileManager.default.temporaryDirectory
          .appendingPathComponent("reframed-nr-\(UUID().uuidString).m4a")
        try await RNNoiseProcessor.processFile(
          inputURL: micURL,
          outputURL: tempURL,
          intensity: micNoiseReductionIntensity
        )
        processedMicURL = tempURL
        shouldCleanupProcessedMic = true
      }
    }
    defer {
      if shouldCleanupProcessedMic, let url = processedMicURL {
        try? FileManager.default.removeItem(at: url)
      }
    }

    var audioSources: [AudioSource] = []
    if let sysURL = result.systemAudioURL, systemAudioVolume > 0 {
      audioSources.append(
        AudioSource(url: sysURL, regions: systemAudioRegions ?? [effectiveTrim], volume: systemAudioVolume)
      )
    }
    if let micURL = result.microphoneAudioURL, micAudioVolume > 0 {
      let effectiveMicURL = processedMicURL ?? micURL
      audioSources.append(
        AudioSource(
          url: effectiveMicURL,
          regions: micAudioRegions ?? [effectiveTrim],
          volume: micAudioVolume
        )
      )
    }

    let hasNonDefaultBackground: Bool = {
      switch backgroundStyle {
      case .none: return false
      case .solidColor(let c): return !(c.r == 0 && c.g == 0 && c.b == 0)
      case .gradient, .image: return true
      }
    }()
    let hasVisualEffects =
      hasNonDefaultBackground || canvasAspect != .original || padding > 0 || videoCornerRadius > 0
      || videoShadow > 0
    let hasWebcam = result.webcamVideoURL != nil
    let hasCursor = cursorSnapshot != nil
    let hasZoom = zoomTimeline != nil
    let sourceCodecMatchesExport: Bool = {
      switch result.captureQuality {
      case .veryHigh: return exportSettings.codec == .proRes4444
      case .high: return exportSettings.codec == .proRes422
      case .standard: return exportSettings.codec == .h265
      }
    }()
    let needsReencode =
      !sourceCodecMatchesExport || exportSettings.resolution != .original
      || exportSettings.fps != .original
    let needsCompositor =
      hasVisualEffects || hasWebcam || needsReencode || hasCursor || hasZoom
      || exportSettings.format.isGIF

    let canvasSize: CGSize
    if let baseSize = canvasAspect.size(for: screenNaturalSize) {
      canvasSize = baseSize
    } else if padding > 0 {
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
      var cameraRect: CGRect?

      if let webcamURL = result.webcamVideoURL, let webcamSize = result.webcamSize {
        let webcamAsset = AVURLAsset(url: webcamURL)
        if let webcamVideoTrack = try await webcamAsset.loadTracks(withMediaType: .video).first {
          let wTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: 2
          )
          try wTrack?.insertTimeRange(effectiveTrim, of: webcamVideoTrack, at: .zero)
          webcamTrackID = 2
          cameraRect = cameraLayout.pixelRect(
            screenSize: canvasSize,
            webcamSize: webcamSize,
            cameraAspect: cameraAspect
          )
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

      var bgImage: CGImage?
      if case .image = backgroundStyle, let imageURL = backgroundImageURL,
        let dataProvider = CGDataProvider(url: imageURL as CFURL),
        let source = CGImageSourceCreateWithDataProvider(dataProvider, nil),
        CGImageSourceGetCount(source) > 0
      {
        bgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
      }

      let scaleX = renderSize.width / canvasSize.width
      let scaleY = renderSize.height / canvasSize.height
      let paddingHPx = padding * screenNaturalSize.width * scaleX
      let paddingVPx = padding * screenNaturalSize.height * scaleY

      let scaledCornerRadius: CGFloat = {
        let paddedW = renderSize.width - 2 * paddingHPx
        let paddedH = renderSize.height - 2 * paddingVPx
        let paddedArea = CGRect(x: 0, y: 0, width: paddedW, height: paddedH)
        let videoFitRect = AVMakeRect(aspectRatio: screenNaturalSize, insideRect: paddedArea)
        return min(videoFitRect.width, videoFitRect.height) * (videoCornerRadius / 100.0)
      }()

      let instruction = CompositionInstruction(
        timeRange: CMTimeRange(start: .zero, duration: effectiveTrim.duration),
        screenTrackID: 1,
        webcamTrackID: webcamTrackID,
        cameraRect: cameraRect.map { rect in
          let scaleX = renderSize.width / canvasSize.width
          let scaleY = renderSize.height / canvasSize.height
          return CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
          )
        },
        cameraCornerRadius: {
          guard let rect = cameraRect else { return 0 }
          let sX = renderSize.width / canvasSize.width
          let sY = renderSize.height / canvasSize.height
          let scaledW = rect.width * sX
          let scaledH = rect.height * sY
          return min(scaledW, scaledH) * (cameraCornerRadius / 100.0)
        }(),
        cameraBorderWidth: cameraBorderWidth * (renderSize.width / canvasSize.width),
        cameraBorderColor: cameraBorderColor.cgColor,
        videoShadow: videoShadow,
        cameraShadow: cameraShadow,
        cameraMirrored: cameraMirrored,
        outputSize: renderSize,
        backgroundColors: bgColors,
        backgroundStartPoint: bgStartPoint,
        backgroundEndPoint: bgEndPoint,
        backgroundImage: bgImage,
        backgroundImageFillMode: backgroundImageFillMode,
        paddingH: paddingHPx,
        paddingV: paddingVPx,
        videoCornerRadius: scaledCornerRadius,
        canvasSize: renderSize,
        cursorSnapshot: cursorSnapshot,
        cursorStyle: cursorStyle,
        cursorSize: cursorSize,
        showCursor: cursorSnapshot != nil,
        showClickHighlights: showClickHighlights,
        clickHighlightColor: clickHighlightColor,
        clickHighlightSize: clickHighlightSize,
        zoomFollowCursor: zoomFollowCursor,
        zoomTimeline: zoomTimeline,
        trimStartSeconds: CMTimeGetSeconds(effectiveTrim.start),
        cameraFullscreenRegions: (cameraFullscreenRegions ?? []).compactMap { region in
          let overlapStart = CMTimeMaximum(region.timeRange.start, effectiveTrim.start)
          let overlapEnd = CMTimeMinimum(region.timeRange.end, effectiveTrim.end)
          guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { return nil }
          return CameraRegionInfo(
            timeRange: CMTimeRange(
              start: CMTimeSubtract(overlapStart, effectiveTrim.start),
              end: CMTimeSubtract(overlapEnd, effectiveTrim.start)
            ),
            entryTransition: region.entryTransition,
            entryDuration: region.entryDuration,
            exitTransition: region.exitTransition,
            exitDuration: region.exitDuration
          )
        },
        cameraHiddenRegions: (cameraHiddenRegions ?? []).compactMap { region in
          let overlapStart = CMTimeMaximum(region.timeRange.start, effectiveTrim.start)
          let overlapEnd = CMTimeMinimum(region.timeRange.end, effectiveTrim.end)
          guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { return nil }
          return CameraRegionInfo(
            timeRange: CMTimeRange(
              start: CMTimeSubtract(overlapStart, effectiveTrim.start),
              end: CMTimeSubtract(overlapEnd, effectiveTrim.start)
            ),
            entryTransition: region.entryTransition,
            entryDuration: region.entryDuration,
            exitTransition: region.exitTransition,
            exitDuration: region.exitDuration
          )
        },
        cameraCustomRegions: (cameraCustomRegions ?? []).compactMap { region in
          let overlapStart = CMTimeMaximum(region.timeRange.start, effectiveTrim.start)
          let overlapEnd = CMTimeMinimum(region.timeRange.end, effectiveTrim.end)
          guard CMTimeCompare(overlapEnd, overlapStart) > 0 else { return nil }
          return CameraCustomRegion(
            timeRange: CMTimeRange(
              start: CMTimeSubtract(overlapStart, effectiveTrim.start),
              end: CMTimeSubtract(overlapEnd, effectiveTrim.start)
            ),
            layout: region.layout,
            cameraAspect: region.cameraAspect,
            cornerRadius: region.cornerRadius,
            shadow: region.shadow,
            borderWidth: region.borderWidth,
            borderColor: region.borderColor,
            mirrored: region.mirrored,
            entryTransition: region.entryTransition,
            entryDuration: region.entryDuration,
            exitTransition: region.exitTransition,
            exitDuration: region.exitDuration
          )
        },
        webcamSize: result.webcamSize,
        cameraAspect: cameraAspect,
        cameraFullscreenFillMode: cameraFullscreenFillMode,
        cameraFullscreenAspect: cameraFullscreenAspect
      )

      if exportSettings.format.isGIF {
        let outputURL = FileManager.default.tempGIFURL()
        try await gifExport(
          composition: composition,
          instruction: instruction,
          renderSize: renderSize,
          fps: exportFPS,
          trimDuration: effectiveTrim.duration,
          outputURL: outputURL,
          gifQuality: exportSettings.gifQuality.value,
          progressHandler: progressHandler
        )

        let destination = await MainActor.run {
          FileManager.default.defaultSaveURL(for: outputURL, extension: "gif")
        }
        try FileManager.default.moveToFinal(from: outputURL, to: destination)

        logger.info("GIF export saved: \(destination.path)")
        return destination
      }

      let videoComposition = AVMutableVideoComposition()
      videoComposition.customVideoCompositorClass = CameraVideoCompositor.self
      videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(exportFPS))
      videoComposition.renderSize = renderSize
      videoComposition.instructions = [instruction]

      try await addAudioTracks(to: composition, sources: audioSources, videoTrimRange: effectiveTrim)
      let audioMix = buildAudioMix(for: composition, sources: audioSources)

      let outputURL = FileManager.default.tempRecordingURL()

      if exportSettings.mode == .parallel {
        try await parallelRenderExport(
          composition: composition,
          instruction: instruction,
          renderSize: renderSize,
          fps: exportFPS,
          trimDuration: effectiveTrim.duration,
          outputURL: outputURL,
          fileType: exportSettings.format.fileType,
          codec: exportSettings.codec,
          audioMix: audioMix,
          audioBitrate: exportSettings.audioBitrate.value,
          progressHandler: progressHandler
        )
      } else {
        try await runManualExport(
          asset: composition,
          videoComposition: videoComposition,
          timeRange: CMTimeRange(start: .zero, duration: effectiveTrim.duration),
          renderSize: renderSize,
          codec: exportSettings.codec.videoCodecType,
          exportFPS: Double(exportFPS),
          to: outputURL,
          fileType: exportSettings.format.fileType,
          audioMix: audioMix,
          audioBitrate: exportSettings.audioBitrate.value,
          progressHandler: progressHandler
        )
      }

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
    if let audioMix = buildAudioMix(for: composition, sources: audioSources) {
      exportSession.audioMix = audioMix
    }
    try await runExport(
      exportSession,
      to: outputURL,
      fileType: exportSettings.format.fileType,
      progressHandler: progressHandler
    )

    let destination = await MainActor.run {
      FileManager.default.defaultSaveURL(for: outputURL, extension: exportSettings.format.fileExtension)
    }
    try FileManager.default.moveToFinal(from: outputURL, to: destination)

    logger.info("Passthrough export saved: \(destination.path)")
    return destination
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
    case .image:
      return []
    }
  }
}
