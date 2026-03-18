import AVFoundation
import CoreMedia
import Foundation

extension VideoCompositor {
  static func checkNeedsCompositor(
    result: RecordingResult,
    config: ExportConfiguration,
    clickSoundURL: URL?,
    hasVideoRegions: Bool,
    screenNaturalSize: CGSize
  ) -> Bool {
    let hasNonDefaultBackground: Bool = {
      switch config.backgroundStyle {
      case .none: return false
      case .solidColor(let c): return !(c.r == 0 && c.g == 0 && c.b == 0)
      case .gradient, .image: return true
      }
    }()
    let hasVisualEffects =
      hasNonDefaultBackground || config.canvasAspect != CanvasAspect.original
      || config.padding > 0 || config.videoCornerRadius > 0 || config.videoShadow > 0
    let sourceCodecMatchesExport: Bool = {
      switch result.captureQuality {
      case .veryHigh: return config.exportSettings.codec == ExportCodec.proRes4444
      case .high: return config.exportSettings.codec == ExportCodec.proRes422
      case .standard: return config.exportSettings.codec == ExportCodec.h265
      }
    }()
    let needsReencode =
      !sourceCodecMatchesExport || config.exportSettings.resolution != ExportResolution.original
      || config.exportSettings.fps != ExportFPS.original
    return hasVisualEffects
      || result.webcamVideoURL != nil
      || needsReencode
      || config.cursorSnapshot != nil
      || config.zoomTimeline != nil
      || config.exportSettings.format.isGIF
      || hasVideoRegions
      || (config.captionsEnabled && !config.captionSegments.isEmpty)
      || (!config.spotlightRegions.isEmpty && config.cursorSnapshot != nil)
      || clickSoundURL != nil
  }

  static func computeCanvasSize(
    screenNaturalSize: CGSize,
    canvasAspect: CanvasAspect,
    padding: CGFloat
  ) -> CGSize {
    if let baseSize = canvasAspect.size(for: screenNaturalSize) {
      return baseSize
    } else if padding > 0 {
      let scale = 1.0 + 2.0 * padding
      return CGSize(
        width: screenNaturalSize.width * scale,
        height: screenNaturalSize.height * scale
      )
    }
    return screenNaturalSize
  }

  static func computeRenderSize(
    canvasSize: CGSize,
    resolution: ExportResolution
  ) -> CGSize {
    if let targetWidth = resolution.pixelWidth {
      let aspect = canvasSize.height / max(canvasSize.width, 1)
      return CGSize(width: targetWidth, height: round(targetWidth * aspect))
    }
    return canvasSize
  }

  static func buildCompositionInstruction(
    composition: AVMutableComposition,
    result: RecordingResult,
    config: ExportConfiguration,
    effectiveTrim: CMTimeRange,
    screenNaturalSize: CGSize,
    hasVideoRegions: Bool,
    videoSegments: [VideoSegment],
    compositionDuration: CMTime,
    canvasSize: CGSize,
    renderSize: CGSize
  ) async throws -> CompositionInstruction {
    var webcamTrackID: CMPersistentTrackID?
    var cameraRect: CGRect?

    if let webcamURL = result.webcamVideoURL, let webcamSize = result.webcamSize {
      let webcamAsset = AVURLAsset(url: webcamURL)
      if let webcamVideoTrack = try await webcamAsset.loadTracks(withMediaType: .video).first {
        let wTrack = composition.addMutableTrack(
          withMediaType: .video,
          preferredTrackID: 2
        )
        if hasVideoRegions {
          for seg in videoSegments {
            try wTrack?.insertTimeRange(seg.sourceRange, of: webcamVideoTrack, at: seg.compositionStart)
          }
        } else {
          try wTrack?.insertTimeRange(effectiveTrim, of: webcamVideoTrack, at: .zero)
        }
        webcamTrackID = 2
        cameraRect = config.cameraLayout.pixelRect(
          screenSize: canvasSize,
          webcamSize: webcamSize,
          cameraAspect: config.cameraAspect
        )
      }
    }

    let bgColors = backgroundColorTuples(for: config.backgroundStyle)
    let bgStartPoint: CGPoint
    let bgEndPoint: CGPoint
    if case .gradient(let id) = config.backgroundStyle, let preset = GradientPresets.preset(for: id) {
      bgStartPoint = preset.cgStartPoint
      bgEndPoint = preset.cgEndPoint
    } else {
      bgStartPoint = .zero
      bgEndPoint = CGPoint(x: 0, y: 1)
    }

    let bgImage = loadBackgroundImage(style: config.backgroundStyle, imageURL: config.backgroundImageURL)
    let camBgImage = loadCameraBackgroundImage(
      style: config.cameraBackgroundStyle,
      imageURL: config.cameraBackgroundImageURL
    )

    let scaleX = renderSize.width / canvasSize.width
    let scaleY = renderSize.height / canvasSize.height
    let paddingHPx = config.padding * screenNaturalSize.width * scaleX
    let paddingVPx = config.padding * screenNaturalSize.height * scaleY

    let scaledCornerRadius: CGFloat = {
      let paddedW = renderSize.width - 2 * paddingHPx
      let paddedH = renderSize.height - 2 * paddingVPx
      let paddedArea = CGRect(x: 0, y: 0, width: paddedW, height: paddedH)
      let videoFitRect = AVMakeRect(aspectRatio: screenNaturalSize, insideRect: paddedArea)
      return min(videoFitRect.width, videoFitRect.height) * (config.videoCornerRadius / 100.0)
    }()

    let regions = remapAllRegions(
      config: config,
      hasVideoRegions: hasVideoRegions,
      videoSegments: videoSegments,
      effectiveTrim: effectiveTrim,
      scaleX: scaleX
    )

    return CompositionInstruction(
      timeRange: CMTimeRange(start: .zero, duration: compositionDuration),
      screenTrackID: 1,
      webcamTrackID: webcamTrackID,
      cameraRect: cameraRect.map { rect in
        CGRect(
          x: rect.origin.x * scaleX,
          y: rect.origin.y * scaleY,
          width: rect.width * scaleX,
          height: rect.height * scaleY
        )
      },
      cameraCornerRadius: {
        guard let rect = cameraRect else { return 0 }
        let scaledW = rect.width * scaleX
        let scaledH = rect.height * scaleY
        return min(scaledW, scaledH) * (config.cameraCornerRadius / 100.0)
      }(),
      cameraBorderWidth: config.cameraBorderWidth * scaleX,
      cameraBorderColor: config.cameraBorderColor.cgColor,
      videoShadow: config.videoShadow,
      cameraShadow: config.cameraShadow,
      cameraMirrored: config.cameraMirrored,
      outputSize: renderSize,
      backgroundColors: bgColors,
      backgroundStartPoint: bgStartPoint,
      backgroundEndPoint: bgEndPoint,
      backgroundImage: bgImage,
      backgroundImageFillMode: config.backgroundImageFillMode,
      paddingH: paddingHPx,
      paddingV: paddingVPx,
      videoCornerRadius: scaledCornerRadius,
      canvasSize: renderSize,
      cursorSnapshot: config.cursorSnapshot,
      cursorStyle: config.cursorStyle,
      cursorSize: config.cursorSize,
      cursorFillColor: config.cursorFillColor,
      cursorStrokeColor: config.cursorStrokeColor,
      showCursor: config.cursorSnapshot != nil,
      showClickHighlights: config.showClickHighlights,
      clickHighlightColor: config.clickHighlightColor.cgColor,
      clickHighlightSize: config.clickHighlightSize,
      useSystemCursor: config.useSystemCursor,
      cursorSway: config.cursorSway,
      cursorMotionBlur: config.cursorMotionBlur,
      clickBounce: config.clickBounce,
      zoomFollowCursor: config.zoomFollowCursor,
      zoomTimeline: config.zoomTimeline,
      trimStartSeconds: hasVideoRegions ? 0 : CMTimeGetSeconds(effectiveTrim.start),
      cameraFullscreenRegions: regions.cameraFullscreen,
      cameraHiddenRegions: regions.cameraHidden,
      cameraCustomRegions: regions.cameraCustom,
      videoRegions: regions.video,
      videoSegmentMappings: hasVideoRegions
        ? videoSegments.map {
          VideoSegmentMapping(
            compositionStart: CMTimeGetSeconds($0.compositionStart),
            sourceStart: CMTimeGetSeconds($0.sourceRange.start),
            duration: CMTimeGetSeconds($0.sourceRange.duration)
          )
        } : [],
      webcamSize: result.webcamSize,
      cameraAspect: config.cameraAspect,
      cameraFullscreenFillMode: config.cameraFullscreenFillMode,
      cameraFullscreenAspect: config.cameraFullscreenAspect,
      cameraBackgroundStyle: config.cameraBackgroundStyle,
      cameraBackgroundImage: camBgImage,
      captionScreenWidth: screenNaturalSize.width,
      captionSegments: regions.captions,
      captionsEnabled: config.captionsEnabled,
      captionFontSize: config.captionFontSize,
      captionFontWeight: config.captionFontWeight,
      captionTextColor: config.captionTextColor,
      captionBackgroundColor: config.captionBackgroundColor,
      captionBackgroundOpacity: config.captionBackgroundOpacity,
      captionShowBackground: config.captionShowBackground,
      captionPosition: config.captionPosition,
      captionMaxWordsPerLine: config.captionMaxWordsPerLine,
      spotlightRegions: regions.spotlight,
      spotlightRadius: config.spotlightRadius,
      spotlightDimOpacity: config.spotlightDimOpacity,
      spotlightEdgeSoftness: config.spotlightEdgeSoftness,
      isHDR: result.isHDR
    )
  }
}
