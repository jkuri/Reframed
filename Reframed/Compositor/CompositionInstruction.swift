import AVFoundation
import CoreMedia

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
  let showCursor: Bool
  let showClickHighlights: Bool
  let clickHighlightColor: CGColor
  let clickHighlightSize: CGFloat
  let zoomFollowCursor: Bool
  let zoomTimeline: ZoomTimeline?
  let trimStartSeconds: Double
  let cameraFullscreenRegions: [CMTimeRange]
  let cameraFullscreenFillMode: CameraFullscreenFillMode
  let cameraFullscreenAspect: CameraFullscreenAspect

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
    cursorStyle: CursorStyle = .defaultArrow,
    cursorSize: CGFloat = 24,
    showCursor: Bool = false,
    showClickHighlights: Bool = true,
    clickHighlightColor: CGColor = CGColor(srgbRed: 0.2, green: 0.5, blue: 1.0, alpha: 1.0),
    clickHighlightSize: CGFloat = 36,
    zoomFollowCursor: Bool = true,
    zoomTimeline: ZoomTimeline? = nil,
    trimStartSeconds: Double = 0,
    cameraFullscreenRegions: [CMTimeRange] = [],
    cameraFullscreenFillMode: CameraFullscreenFillMode = .fit,
    cameraFullscreenAspect: CameraFullscreenAspect = .original
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
    self.showCursor = showCursor
    self.showClickHighlights = showClickHighlights
    self.clickHighlightColor = clickHighlightColor
    self.clickHighlightSize = clickHighlightSize
    self.zoomFollowCursor = zoomFollowCursor
    self.zoomTimeline = zoomTimeline
    self.trimStartSeconds = trimStartSeconds
    self.cameraFullscreenRegions = cameraFullscreenRegions
    self.cameraFullscreenFillMode = cameraFullscreenFillMode
    self.cameraFullscreenAspect = cameraFullscreenAspect

    var trackIDs: [NSValue] = [NSNumber(value: screenTrackID)]
    if let wid = webcamTrackID {
      trackIDs.append(NSNumber(value: wid))
    }
    self.requiredSourceTrackIDs = trackIDs
    super.init()
  }
}
