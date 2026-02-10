import AVFoundation
import CoreMedia

final class PiPCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
  let timeRange: CMTimeRange
  let enablePostProcessing = false
  let containsTweening = false
  let requiredSourceTrackIDs: [NSValue]?
  let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

  let screenTrackID: CMPersistentTrackID
  let webcamTrackID: CMPersistentTrackID
  let pipRect: CGRect
  let cornerRadius: CGFloat
  let outputSize: CGSize

  init(
    timeRange: CMTimeRange,
    screenTrackID: CMPersistentTrackID,
    webcamTrackID: CMPersistentTrackID,
    pipRect: CGRect,
    cornerRadius: CGFloat,
    outputSize: CGSize
  ) {
    self.timeRange = timeRange
    self.screenTrackID = screenTrackID
    self.webcamTrackID = webcamTrackID
    self.pipRect = pipRect
    self.cornerRadius = cornerRadius
    self.outputSize = outputSize
    self.requiredSourceTrackIDs = [
      NSNumber(value: screenTrackID),
      NSNumber(value: webcamTrackID),
    ]
    super.init()
  }
}
