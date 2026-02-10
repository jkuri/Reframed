import CoreGraphics
import Foundation

struct RecordingResult: Sendable {
  let screenVideoURL: URL
  let webcamVideoURL: URL?
  let systemAudioURL: URL?
  let microphoneAudioURL: URL?
  let screenSize: CGSize
  let webcamSize: CGSize?
  let fps: Int
}
