import AVFoundation
import CoreMedia

struct RegionTransitionInfo: Sendable {
  let timeRange: CMTimeRange
  let entryTransition: RegionTransitionType
  let entryDuration: Double
  let exitTransition: RegionTransitionType
  let exitDuration: Double
}

struct CameraCustomRegion: Sendable {
  let timeRange: CMTimeRange
  let layout: CameraLayout
  let cameraAspect: CameraAspect
  let cornerRadius: CGFloat
  let shadow: CGFloat
  let borderWidth: CGFloat
  let borderColor: CGColor
  let mirrored: Bool
  let entryTransition: RegionTransitionType
  let entryDuration: Double
  let exitTransition: RegionTransitionType
  let exitDuration: Double
}

struct VideoSegmentMapping: Sendable {
  let compositionStart: Double
  let sourceStart: Double
  let duration: Double
}

final class CompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
  let timeRange: CMTimeRange
  let enablePostProcessing = false
  let containsTweening = false
  let requiredSourceTrackIDs: [NSValue]?
  let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

  let screenTrackID: CMPersistentTrackID
  let webcamTrackID: CMPersistentTrackID?
  let cameraRect: CGRect?
  let cameraCornerRadius: CGFloat
  let cameraBorderWidth: CGFloat
  let cameraBorderColor: CGColor
  let videoShadow: CGFloat
  let cameraShadow: CGFloat
  let cameraMirrored: Bool
  let outputSize: CGSize

  let backgroundColors: [(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)]
  let backgroundStartPoint: CGPoint
  let backgroundEndPoint: CGPoint
  let backgroundImage: CGImage?
  let backgroundImageFillMode: BackgroundImageFillMode
  let paddingH: CGFloat
  let paddingV: CGFloat
  let videoCornerRadius: CGFloat
  let canvasSize: CGSize

  let cursorSnapshot: CursorMetadataSnapshot?
  let cursorStyle: CursorStyle
  let cursorSize: CGFloat
  let cursorFillColor: CodableColor
  let cursorStrokeColor: CodableColor
  let showCursor: Bool
  let showClickHighlights: Bool
  let clickHighlightColor: CGColor
  let clickHighlightSize: CGFloat
  let useSystemCursor: Bool
  let cursorSway: CGFloat
  let cursorMotionBlur: CGFloat
  let clickBounce: CGFloat
  let zoomFollowCursor: Bool
  let zoomTimeline: ZoomTimeline?
  let trimStartSeconds: Double
  let cameraFullscreenRegions: [RegionTransitionInfo]
  let cameraHiddenRegions: [RegionTransitionInfo]
  let cameraCustomRegions: [CameraCustomRegion]
  let videoRegions: [RegionTransitionInfo]
  let videoSegmentMappings: [VideoSegmentMapping]
  let webcamSize: CGSize?
  let cameraAspect: CameraAspect
  let cameraFullscreenFillMode: CameraFullscreenFillMode
  let cameraFullscreenAspect: CameraFullscreenAspect
  let cameraBackgroundStyle: CameraBackgroundStyle
  let cameraBackgroundImage: CGImage?

  let captionScreenWidth: CGFloat
  let captionSegments: [CaptionSegment]
  let captionsEnabled: Bool
  let captionFontSize: CGFloat
  let captionFontWeight: CaptionFontWeight
  let captionTextColor: CodableColor
  let captionBackgroundColor: CodableColor
  let captionBackgroundOpacity: CGFloat
  let captionShowBackground: Bool
  let captionPosition: CaptionPosition
  let captionMaxWordsPerLine: Int

  let spotlightRegions: [SpotlightRegionData]
  let spotlightRadius: CGFloat
  let spotlightDimOpacity: CGFloat
  let spotlightEdgeSoftness: CGFloat
  let isHDR: Bool

  init(
    timeRange: CMTimeRange,
    screenTrackID: CMPersistentTrackID,
    webcamTrackID: CMPersistentTrackID?,
    cameraRect: CGRect?,
    cameraCornerRadius: CGFloat,
    cameraBorderWidth: CGFloat = 0,
    cameraBorderColor: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3),
    videoShadow: CGFloat = 0,
    cameraShadow: CGFloat = 0,
    cameraMirrored: Bool = false,
    outputSize: CGSize,
    backgroundColors: [(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)] = [],
    backgroundStartPoint: CGPoint = .zero,
    backgroundEndPoint: CGPoint = CGPoint(x: 0, y: 1),
    backgroundImage: CGImage? = nil,
    backgroundImageFillMode: BackgroundImageFillMode = .fill,
    paddingH: CGFloat = 0,
    paddingV: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    canvasSize: CGSize = .zero,
    cursorSnapshot: CursorMetadataSnapshot? = nil,
    cursorStyle: CursorStyle = .centerDefault,
    cursorSize: CGFloat = 24,
    cursorFillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1),
    cursorStrokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0),
    showCursor: Bool = false,
    showClickHighlights: Bool = true,
    clickHighlightColor: CGColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1.0),
    clickHighlightSize: CGFloat = 36,
    useSystemCursor: Bool = false,
    cursorSway: CGFloat = 0,
    cursorMotionBlur: CGFloat = 0,
    clickBounce: CGFloat = 0,
    zoomFollowCursor: Bool = true,
    zoomTimeline: ZoomTimeline? = nil,
    trimStartSeconds: Double = 0,
    cameraFullscreenRegions: [RegionTransitionInfo] = [],
    cameraHiddenRegions: [RegionTransitionInfo] = [],
    cameraCustomRegions: [CameraCustomRegion] = [],
    videoRegions: [RegionTransitionInfo] = [],
    videoSegmentMappings: [VideoSegmentMapping] = [],
    webcamSize: CGSize? = nil,
    cameraAspect: CameraAspect = .original,
    cameraFullscreenFillMode: CameraFullscreenFillMode = .fit,
    cameraFullscreenAspect: CameraFullscreenAspect = .original,
    cameraBackgroundStyle: CameraBackgroundStyle = .none,
    cameraBackgroundImage: CGImage? = nil,
    captionScreenWidth: CGFloat = 1920,
    captionSegments: [CaptionSegment] = [],
    captionsEnabled: Bool = false,
    captionFontSize: CGFloat = 48,
    captionFontWeight: CaptionFontWeight = .bold,
    captionTextColor: CodableColor = CodableColor(r: 1, g: 1, b: 1),
    captionBackgroundColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 1.0),
    captionBackgroundOpacity: CGFloat = 0.6,
    captionShowBackground: Bool = true,
    captionPosition: CaptionPosition = .bottom,
    captionMaxWordsPerLine: Int = 6,
    spotlightRegions: [SpotlightRegionData] = [],
    spotlightRadius: CGFloat = 200,
    spotlightDimOpacity: CGFloat = 0.6,
    spotlightEdgeSoftness: CGFloat = 50,
    isHDR: Bool = false
  ) {
    self.timeRange = timeRange
    self.screenTrackID = screenTrackID
    self.webcamTrackID = webcamTrackID
    self.cameraRect = cameraRect
    self.cameraCornerRadius = cameraCornerRadius
    self.cameraBorderWidth = cameraBorderWidth
    self.cameraBorderColor = cameraBorderColor
    self.videoShadow = videoShadow
    self.cameraShadow = cameraShadow
    self.cameraMirrored = cameraMirrored
    self.outputSize = outputSize
    self.backgroundColors = backgroundColors
    self.backgroundStartPoint = backgroundStartPoint
    self.backgroundEndPoint = backgroundEndPoint
    self.backgroundImage = backgroundImage
    self.backgroundImageFillMode = backgroundImageFillMode
    self.paddingH = paddingH
    self.paddingV = paddingV
    self.videoCornerRadius = videoCornerRadius
    self.canvasSize = canvasSize.width > 0 ? canvasSize : outputSize
    self.cursorSnapshot = cursorSnapshot
    self.cursorStyle = cursorStyle
    self.cursorSize = cursorSize
    self.cursorFillColor = cursorFillColor
    self.cursorStrokeColor = cursorStrokeColor
    self.showCursor = showCursor
    self.showClickHighlights = showClickHighlights
    self.clickHighlightColor = clickHighlightColor
    self.clickHighlightSize = clickHighlightSize
    self.useSystemCursor = useSystemCursor
    self.cursorSway = cursorSway
    self.cursorMotionBlur = cursorMotionBlur
    self.clickBounce = clickBounce
    self.zoomFollowCursor = zoomFollowCursor
    self.zoomTimeline = zoomTimeline
    self.trimStartSeconds = trimStartSeconds
    self.cameraFullscreenRegions = cameraFullscreenRegions
    self.cameraHiddenRegions = cameraHiddenRegions
    self.cameraCustomRegions = cameraCustomRegions
    self.videoRegions = videoRegions
    self.videoSegmentMappings = videoSegmentMappings
    self.webcamSize = webcamSize
    self.cameraAspect = cameraAspect
    self.cameraFullscreenFillMode = cameraFullscreenFillMode
    self.cameraFullscreenAspect = cameraFullscreenAspect
    self.cameraBackgroundStyle = cameraBackgroundStyle
    self.cameraBackgroundImage = cameraBackgroundImage
    self.captionScreenWidth = captionScreenWidth
    self.captionSegments = captionSegments
    self.captionsEnabled = captionsEnabled
    self.captionFontSize = captionFontSize
    self.captionFontWeight = captionFontWeight
    self.captionTextColor = captionTextColor
    self.captionBackgroundColor = captionBackgroundColor
    self.captionBackgroundOpacity = captionBackgroundOpacity
    self.captionShowBackground = captionShowBackground
    self.captionPosition = captionPosition
    self.captionMaxWordsPerLine = captionMaxWordsPerLine
    self.spotlightRegions = spotlightRegions
    self.spotlightRadius = spotlightRadius
    self.spotlightDimOpacity = spotlightDimOpacity
    self.spotlightEdgeSoftness = spotlightEdgeSoftness
    self.isHDR = isHDR
    var trackIDs: [NSValue] = [NSNumber(value: screenTrackID)]
    if let wid = webcamTrackID {
      trackIDs.append(NSNumber(value: wid))
    }
    self.requiredSourceTrackIDs = trackIDs
    super.init()
  }

  func isSpotlightActive(at metadataTime: Double) -> Bool {
    if spotlightRegions.isEmpty { return false }
    return spotlightRegions.contains { metadataTime >= $0.startSeconds && metadataTime <= $0.endSeconds }
  }

  func effectiveSpotlightSettings(
    at metadataTime: Double
  ) -> (
    radius: CGFloat, dimOpacity: CGFloat, edgeSoftness: CGFloat, fadeFactor: CGFloat
  ) {
    if let region = spotlightRegions.first(where: {
      metadataTime >= $0.startSeconds && metadataTime <= $0.endSeconds
    }) {
      let fade = region.fadeDuration ?? 0
      var factor: CGFloat = 1.0
      if fade > 0 {
        let elapsed = metadataTime - region.startSeconds
        let remaining = region.endSeconds - metadataTime
        if elapsed < fade {
          factor = min(1.0, CGFloat(elapsed / fade))
        }
        if remaining < fade {
          factor = min(factor, CGFloat(remaining / fade))
        }
      }
      return (
        radius: region.customRadius ?? spotlightRadius,
        dimOpacity: region.customDimOpacity ?? spotlightDimOpacity,
        edgeSoftness: region.customEdgeSoftness ?? spotlightEdgeSoftness,
        fadeFactor: factor
      )
    }
    return (
      radius: spotlightRadius,
      dimOpacity: spotlightDimOpacity,
      edgeSoftness: spotlightEdgeSoftness,
      fadeFactor: 1.0
    )
  }

  func sourceTime(for compositionTime: CMTime) -> Double {
    let t = CMTimeGetSeconds(compositionTime)
    for seg in videoSegmentMappings {
      let compEnd = seg.compositionStart + seg.duration
      if t >= seg.compositionStart && t < compEnd {
        return seg.sourceStart + (t - seg.compositionStart)
      }
    }
    return t + trimStartSeconds
  }
}
