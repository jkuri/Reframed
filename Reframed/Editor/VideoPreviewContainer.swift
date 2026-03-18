import AVFoundation
import AppKit

final class VideoPreviewContainer: NSView {
  let screenPlayerLayer = AVPlayerLayer()
  let webcamPlayerLayer = AVPlayerLayer()
  let webcamWrapper = NSView()
  let webcamView = WebcamCameraView()
  let cursorOverlay = CursorOverlayLayer()
  let spotlightOverlay = SpotlightOverlayLayer()
  let screenContainerLayer = CALayer()
  var coordinator: VideoPreviewView.Coordinator?
  var isCameraHidden = false
  var isCameraFullscreen = false
  var currentFullscreenFillMode: CameraFullscreenFillMode = .fit
  var currentFullscreenAspect: CameraFullscreenAspect = .original
  var cameraTransitionProgress: CGFloat = 1.0
  var cameraTransitionType: RegionTransitionType = .none
  var screenTransitionProgress: CGFloat = 1.0
  var screenTransitionType: RegionTransitionType = .none
  var isScreenHidden = false
  var isDraggingCamera = false
  var currentLayout = CameraLayout()
  var currentWebcamSize: CGSize?
  var currentScreenSize: CGSize = .zero
  var currentCanvasSize: CGSize = .zero
  var currentPadding: CGFloat = 0
  var currentVideoCornerRadius: CGFloat = 0
  var currentCameraAspect: CameraAspect = .original
  var currentCameraCornerRadius: CGFloat = 12
  var currentCameraBorderWidth: CGFloat = 0
  var currentCameraBorderColor: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3)
  var currentVideoShadow: CGFloat = 0
  var currentCameraShadow: CGFloat = 0
  var currentCameraMirrored: Bool = false
  var isCustomRegionTransition = false
  var defaultPipLayout = CameraLayout()
  var defaultPipCameraAspect: CameraAspect = .original
  var defaultPipCornerRadius: CGFloat = 12
  var defaultPipBorderWidth: CGFloat = 0
  var defaultPipBorderColor: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3)
  var defaultPipShadow: CGFloat = 0
  var defaultPipMirrored: Bool = false
  let screenMaskLayer = CAShapeLayer()
  let screenShadowLayer = CALayer()
  var trackingArea: NSTrackingArea?
  var currentZoomRect = CGRect(x: 0, y: 0, width: 1, height: 1)
  var lastCursorNormalizedPosition: CGPoint = .zero
  var lastCursorStyle: CursorStyle = .centerDefault
  var lastCursorSize: CGFloat = 24
  var lastCursorVisible = false
  var lastCursorClicks: [(point: CGPoint, progress: Double)] = []
  var lastClickHighlightColor: CGColor?
  var lastClickHighlightSize: CGFloat = 36
  var lastCursorFillColor: CodableColor = CodableColor(r: 1, g: 1, b: 1)
  var lastCursorStrokeColor: CodableColor = CodableColor(r: 0, g: 0, b: 0)
  var lastSwayRotation: CGFloat = 0
  var lastBounceScale: CGFloat = 1.0
  var lastMotionBlurDx: CGFloat = 0
  var lastMotionBlurDy: CGFloat = 0
  var lastMotionBlurMagnitude: CGFloat = 0
  var lastSystemCursorType: SystemCursorType?
  var lastSpotlightNormalizedPosition: CGPoint = .zero
  var lastSpotlightRadius: CGFloat = 200
  var lastSpotlightDimOpacity: CGFloat = 0.6
  var lastSpotlightEdgeSoftness: CGFloat = 50
  var lastSpotlightVisible = false
  var currentCameraBackgroundStyle: CameraBackgroundStyle = .none
  var currentCameraBackgroundImage: NSImage?
  var webcamOutput: AVPlayerItemVideoOutput?
  let processedWebcamLayer = CALayer()
  let segmentationProcessor = PersonSegmentationProcessor(quality: .balanced)
  let segmentationQueue = DispatchQueue(label: "eu.jkuri.reframed.segmentation", qos: .userInteractive)
  var isProcessingWebcamFrame = false
  var lastProcessedWebcamTime: Double = -1

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    screenShadowLayer.shadowColor = NSColor.black.cgColor
    screenShadowLayer.shadowOffset = .zero
    screenShadowLayer.shadowOpacity = 0
    screenShadowLayer.isHidden = true
    layer?.addSublayer(screenShadowLayer)

    screenContainerLayer.masksToBounds = true
    layer?.addSublayer(screenContainerLayer)

    screenPlayerLayer.videoGravity = .resizeAspectFill
    screenContainerLayer.addSublayer(screenPlayerLayer)

    spotlightOverlay.zPosition = 8
    screenContainerLayer.addSublayer(spotlightOverlay)

    cursorOverlay.zPosition = 10
    screenContainerLayer.addSublayer(cursorOverlay)

    webcamWrapper.wantsLayer = true
    webcamWrapper.layer?.zPosition = 20
    webcamWrapper.layer?.masksToBounds = false

    webcamView.wantsLayer = true
    webcamView.layer?.cornerRadius = 12
    webcamView.layer?.masksToBounds = true
    webcamView.layer?.borderWidth = 0
    webcamView.layer?.borderColor = NSColor.clear.cgColor
    webcamPlayerLayer.videoGravity = .resizeAspectFill
    webcamView.layer?.addSublayer(webcamPlayerLayer)
    webcamPlayerLayer.isHidden = true

    processedWebcamLayer.contentsGravity = .resizeAspectFill
    processedWebcamLayer.isHidden = true
    webcamView.layer?.addSublayer(processedWebcamLayer)

    webcamWrapper.addSubview(webcamView)
    addSubview(webcamWrapper)
  }

  required init?(coder: NSCoder) { nil }

  override func layout() {
    super.layout()
    layoutAll()
    if lastCursorVisible {
      applyCursorOverlay()
    }
    if lastSpotlightVisible {
      applySpotlightOverlay()
    }
  }
}
