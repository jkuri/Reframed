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
  let pipRect: CGRect?
  let pipCornerRadius: CGFloat
  let pipBorderWidth: CGFloat
  let outputSize: CGSize

  let backgroundColors: [(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)]
  let backgroundStartPoint: CGPoint
  let backgroundEndPoint: CGPoint
  let paddingH: CGFloat
  let paddingV: CGFloat
  let videoCornerRadius: CGFloat
  let canvasSize: CGSize

  init(
    timeRange: CMTimeRange,
    screenTrackID: CMPersistentTrackID,
    webcamTrackID: CMPersistentTrackID?,
    pipRect: CGRect?,
    pipCornerRadius: CGFloat,
    pipBorderWidth: CGFloat = 0,
    outputSize: CGSize,
    backgroundColors: [(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)] = [],
    backgroundStartPoint: CGPoint = .zero,
    backgroundEndPoint: CGPoint = CGPoint(x: 0, y: 1),
    paddingH: CGFloat = 0,
    paddingV: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    canvasSize: CGSize = .zero
  ) {
    self.timeRange = timeRange
    self.screenTrackID = screenTrackID
    self.webcamTrackID = webcamTrackID
    self.pipRect = pipRect
    self.pipCornerRadius = pipCornerRadius
    self.pipBorderWidth = pipBorderWidth
    self.outputSize = outputSize
    self.backgroundColors = backgroundColors
    self.backgroundStartPoint = backgroundStartPoint
    self.backgroundEndPoint = backgroundEndPoint
    self.paddingH = paddingH
    self.paddingV = paddingV
    self.videoCornerRadius = videoCornerRadius
    self.canvasSize = canvasSize.width > 0 ? canvasSize : outputSize

    var trackIDs: [NSValue] = [NSNumber(value: screenTrackID)]
    if let wid = webcamTrackID {
      trackIDs.append(NSNumber(value: wid))
    }
    self.requiredSourceTrackIDs = trackIDs
    super.init()
  }
}
