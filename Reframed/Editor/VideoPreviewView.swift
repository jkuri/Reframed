import AVFoundation
import AppKit
import SwiftUI

struct VideoPreviewView: NSViewRepresentable {
  let screenPlayer: AVPlayer
  let webcamPlayer: AVPlayer?
  @Binding var cameraLayout: CameraLayout
  var defaultPipLayout: CameraLayout?
  var defaultPipCameraAspect: CameraAspect?
  var defaultPipCornerRadius: CGFloat?
  var defaultPipBorderWidth: CGFloat?
  var defaultPipBorderColor: CGColor?
  var defaultPipShadow: CGFloat?
  var defaultPipMirrored: Bool?
  let webcamSize: CGSize?
  let screenSize: CGSize
  let canvasSize: CGSize
  var padding: CGFloat = 0
  var videoCornerRadius: CGFloat = 0
  var cameraAspect: CameraAspect = .original
  var cameraCornerRadius: CGFloat = 12
  var cameraBorderWidth: CGFloat = 0
  var cameraBorderColor: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3)
  var videoShadow: CGFloat = 0
  var cameraShadow: CGFloat = 0
  var cameraMirrored: Bool = false
  var cursorMetadataProvider: CursorMetadataProvider?
  var showCursor: Bool = false
  var cursorStyle: CursorStyle = .centerDefault
  var cursorSize: CGFloat = 24
  var cursorFillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1)
  var cursorStrokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0)
  var showClickHighlights: Bool = true
  var clickHighlightColor: CGColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1.0)
  var clickHighlightSize: CGFloat = 36
  var useSystemCursor: Bool = false
  var cursorSway: CGFloat = 0
  var cursorMotionBlur: CGFloat = 0
  var clickBounce: CGFloat = 0
  var zoomFollowCursor: Bool = true
  var currentTime: Double = 0
  var zoomTimeline: ZoomTimeline?
  var cameraFullscreenRegions:
    [(
      start: Double, end: Double,
      entryTransition: RegionTransitionType, entryDuration: Double,
      exitTransition: RegionTransitionType, exitDuration: Double
    )] = []
  var cameraHiddenRegions:
    [(
      start: Double, end: Double,
      entryTransition: RegionTransitionType, entryDuration: Double,
      exitTransition: RegionTransitionType, exitDuration: Double
    )] = []
  var cameraCustomRegions:
    [(
      start: Double, end: Double, layout: CameraLayout, cameraAspect: CameraAspect, cornerRadius: CGFloat, shadow: CGFloat,
      borderWidth: CGFloat, borderColor: CGColor, mirrored: Bool,
      entryTransition: RegionTransitionType, entryDuration: Double,
      exitTransition: RegionTransitionType, exitDuration: Double
    )] = []
  var cameraFullscreenFillMode: CameraFullscreenFillMode = .fit
  var cameraFullscreenAspect: CameraFullscreenAspect = .original
  var videoRegions:
    [(
      start: Double, end: Double,
      entryTransition: RegionTransitionType, entryDuration: Double,
      exitTransition: RegionTransitionType, exitDuration: Double
    )] = []
  var isPreviewMode: Bool = false
  var isPlaying: Bool = false
  var clickSoundEnabled: Bool = false
  var clickSoundVolume: Float = 0.5
  var clickSoundStyle: ClickSoundStyle = .click001
  var spotlightEnabled: Bool = false
  var spotlightRadius: CGFloat = 200
  var spotlightDimOpacity: CGFloat = 0.6
  var spotlightEdgeSoftness: CGFloat = 50
  var cameraBackgroundStyle: CameraBackgroundStyle = .none
  var cameraBackgroundImage: NSImage?
  var isHDR: Bool = false

  func makeNSView(context: Context) -> VideoPreviewContainer {
    let container = VideoPreviewContainer()
    container.screenPlayerLayer.player = screenPlayer
    if isHDR {
      container.layer?.wantsExtendedDynamicRangeContent = true
      container.screenContainerLayer.wantsExtendedDynamicRangeContent = true
      container.screenPlayerLayer.wantsExtendedDynamicRangeContent = true
    }
    if let webcam = webcamPlayer {
      container.webcamPlayerLayer.player = webcam
      container.webcamPlayerLayer.isHidden = false
    }
    container.coordinator = context.coordinator
    if cameraBackgroundStyle != .none, let webcam = webcamPlayer {
      container.currentCameraBackgroundStyle = cameraBackgroundStyle
      container.currentCameraBackgroundImage = cameraBackgroundImage
      container.setupWebcamOutput(for: webcam)
    }
    return container
  }

  func updateNSView(_ nsView: VideoPreviewContainer, context: Context) {
    context.coordinator.cameraLayout = $cameraLayout
    context.coordinator.canvasSize = canvasSize

    if let webcam = webcamPlayer {
      if nsView.webcamPlayerLayer.player !== webcam {
        nsView.webcamPlayerLayer.player = webcam
      }
      nsView.webcamPlayerLayer.isHidden = nsView.currentCameraBackgroundStyle != .none
    } else {
      nsView.webcamPlayerLayer.player = nil
      nsView.webcamPlayerLayer.isHidden = true
    }

    updateCameraVisibility(nsView)
    updateScreenVisibility(nsView)
    updateWebcamOutput(nsView)
    updateLayout(nsView)
    updateZoom(nsView)
    updateOverlays(nsView)
    updateClickSound(context.coordinator)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(cameraLayout: $cameraLayout, screenSize: screenSize, canvasSize: canvasSize, webcamSize: webcamSize)
  }
}
