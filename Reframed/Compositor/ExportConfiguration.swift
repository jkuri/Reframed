import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation

struct ExportConfiguration: Sendable {
  var cameraLayout: CameraLayout
  var cameraAspect: CameraAspect = .original
  var trimRange: CMTimeRange
  var systemAudioRegions: [CMTimeRange]? = nil
  var micAudioRegions: [CMTimeRange]? = nil
  var cameraFullscreenRegions: [RegionTransitionInfo]? = nil
  var cameraHiddenRegions: [RegionTransitionInfo]? = nil
  var cameraCustomRegions: [CameraCustomRegion]? = nil
  var videoRegions: [RegionTransitionInfo]? = nil
  var backgroundStyle: BackgroundStyle = .none
  var backgroundImageURL: URL? = nil
  var backgroundImageFillMode: BackgroundImageFillMode = .fill
  var canvasAspect: CanvasAspect = .original
  var padding: CGFloat = 0
  var videoCornerRadius: CGFloat = 0
  var cameraCornerRadius: CGFloat = 12
  var cameraBorderWidth: CGFloat = 0
  var cameraBorderColor: CodableColor = CodableColor(r: 1, g: 1, b: 1, a: 0.3)
  var videoShadow: CGFloat = 0
  var cameraShadow: CGFloat = 0
  var cameraMirrored: Bool = false
  var cameraFullscreenFillMode: CameraFullscreenFillMode = .fit
  var cameraFullscreenAspect: CameraFullscreenAspect = .original
  var exportSettings: ExportSettings = ExportSettings()
  var cursorSnapshot: CursorMetadataSnapshot? = nil
  var cursorStyle: CursorStyle = .centerDefault
  var cursorSize: CGFloat = 24
  var cursorFillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1)
  var cursorStrokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0)
  var showClickHighlights: Bool = true
  var clickHighlightColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 1.0)
  var clickHighlightSize: CGFloat = 36
  var useSystemCursor: Bool = false
  var cursorSway: CGFloat = 0
  var cursorMotionBlur: CGFloat = 0
  var clickBounce: CGFloat = 0
  var zoomFollowCursor: Bool = true
  var zoomTimeline: ZoomTimeline? = nil
  var systemAudioVolume: Float = 1.0
  var micAudioVolume: Float = 1.0
  var micNoiseReductionEnabled: Bool = false
  var micNoiseReductionIntensity: Float = 0.5
  var cameraBackgroundStyle: CameraBackgroundStyle = .none
  var cameraBackgroundImageURL: URL? = nil
  var processedMicAudioURL: URL? = nil
  var captionSegments: [CaptionSegment] = []
  var captionsEnabled: Bool = false
  var captionFontSize: CGFloat = 48
  var captionFontWeight: CaptionFontWeight = .bold
  var captionTextColor: CodableColor = CodableColor(r: 1, g: 1, b: 1)
  var captionBackgroundColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 1.0)
  var captionBackgroundOpacity: CGFloat = 0.6
  var captionShowBackground: Bool = true
  var captionPosition: CaptionPosition = .bottom
  var captionMaxWordsPerLine: Int = 6
  var spotlightRegions: [SpotlightRegionData] = []
  var spotlightRadius: CGFloat = 200
  var spotlightDimOpacity: CGFloat = 0.6
  var spotlightEdgeSoftness: CGFloat = 50
  var clickSoundEnabled: Bool = false
  var clickSoundVolume: Float = 0.5
  var clickSoundStyle: ClickSoundStyle = .click001
}
