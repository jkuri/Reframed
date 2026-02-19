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
  var hasWebcam: Bool = false
  var captureMode: CaptureMode?
  var captureQuality: String? = nil
  var editorState: EditorStateData?
}

struct CursorSettingsData: Codable, Sendable, Equatable {
  var showCursor: Bool
  var cursorStyleRaw: Int
  var cursorSize: CGFloat
  var showClickHighlights: Bool = true
  var clickHighlightColor: CodableColor? = nil
  var clickHighlightSize: CGFloat = 36
}

struct ZoomSettingsData: Codable, Sendable, Equatable {
  var zoomEnabled: Bool = false
  var autoZoomEnabled: Bool
  var zoomFollowCursor: Bool = true
  var zoomLevel: Double
  var transitionDuration: Double
  var dwellThreshold: Double
  var keyframes: [ZoomKeyframe]
}

struct AnimationSettingsData: Codable, Sendable, Equatable {
  var cursorMovementEnabled: Bool = false
  var cursorMovementSpeed: CursorMovementSpeed = .medium
}

struct AudioSettingsData: Codable, Sendable, Equatable {
  var systemAudioVolume: Float = 1.0
  var micAudioVolume: Float = 1.0
  var systemAudioMuted: Bool = false
  var micAudioMuted: Bool = false
  var micNoiseReductionEnabled: Bool = false
  var micNoiseReductionIntensity: Float = 0.5
  var cachedNoiseReductionIntensity: Float?
}

struct AudioRegionData: Codable, Sendable, Identifiable, Equatable {
  var id: UUID = UUID()
  var startSeconds: Double
  var endSeconds: Double
}

struct EditorStateData: Codable, Sendable {
  var trimStartSeconds: Double
  var trimEndSeconds: Double
  var backgroundStyle: BackgroundStyle
  var backgroundImageFillMode: BackgroundImageFillMode?
  var canvasAspect: CanvasAspect?
  var padding: CGFloat
  var videoCornerRadius: CGFloat
  var cameraAspect: CameraAspect?
  var cameraCornerRadius: CGFloat
  var cameraBorderWidth: CGFloat
  var cameraBorderColor: CodableColor?
  var videoShadow: CGFloat?
  var cameraShadow: CGFloat?
  var cameraMirrored: Bool?
  var cameraFullscreenFillMode: CameraFullscreenFillMode?
  var cameraFullscreenAspect: CameraFullscreenAspect?
  var cameraLayout: CameraLayout
  var webcamEnabled: Bool?
  var cursorSettings: CursorSettingsData?
  var zoomSettings: ZoomSettingsData?
  var animationSettings: AnimationSettingsData?
  var audioSettings: AudioSettingsData?
  var systemAudioRegions: [AudioRegionData]?
  var micAudioRegions: [AudioRegionData]?
  var cameraFullscreenRegions: [AudioRegionData]?
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
