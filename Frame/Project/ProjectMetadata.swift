import CoreGraphics
import Foundation

struct ProjectMetadata: Codable, Sendable {
  var version: Int = 1
  var name: String?
  var createdAt: Date
  var fps: Int
  var screenSize: CodableSize
  var webcamSize: CodableSize?
  var hasSystemAudio: Bool
  var hasMicrophoneAudio: Bool
  var editorState: EditorStateData?
}

struct EditorStateData: Codable, Sendable {
  var trimStartSeconds: Double
  var trimEndSeconds: Double
  var backgroundStyle: BackgroundStyle
  var padding: CGFloat
  var videoCornerRadius: CGFloat
  var pipCornerRadius: CGFloat
  var pipBorderWidth: CGFloat
  var pipLayout: PiPLayout
}

struct CodableSize: Codable, Sendable {
  var width: CGFloat
  var height: CGFloat

  init(_ size: CGSize) {
    self.width = size.width
    self.height = size.height
  }

  var cgSize: CGSize {
    CGSize(width: width, height: height)
  }
}
