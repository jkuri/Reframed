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
  var hasCursorMetadata: Bool = false
  var editorState: EditorStateData?
}

struct CursorSettingsData: Codable, Sendable {
  var showCursor: Bool
  var cursorStyleRaw: Int
  var cursorSize: CGFloat
  var cursorSmoothingRaw: Int
  var showClickHighlights: Bool = true
  var clickHighlightColor: CodableColor? = nil
  var clickHighlightSize: CGFloat = 36
}

struct ZoomSettingsData: Codable, Sendable {
  var autoZoomEnabled: Bool
  var zoomFollowCursor: Bool = true
  var zoomLevel: Double
  var transitionDuration: Double
  var dwellThreshold: Double
  var keyframes: [ZoomKeyframe]
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
  var cursorSettings: CursorSettingsData?
  var zoomSettings: ZoomSettingsData?
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
