import AVFoundation
import AppKit
import SwiftUI

struct VideoPreviewView: NSViewRepresentable {
  let screenPlayer: AVPlayer
  let webcamPlayer: AVPlayer?
  @Binding var cameraLayout: CameraLayout
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
  var cameraBackgroundStyle: CameraBackgroundStyle = .none
  var cameraBackgroundImage: NSImage?

  func makeNSView(context: Context) -> VideoPreviewContainer {
    let container = VideoPreviewContainer()
    container.screenPlayerLayer.player = screenPlayer
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

    let hiddenRegion = cameraHiddenRegions.first { currentTime >= $0.start && currentTime <= $0.end }
    let isCameraHidden = hiddenRegion != nil
    nsView.isCameraHidden = isCameraHidden
    let fsRegion = cameraFullscreenRegions.first { currentTime >= $0.start && currentTime <= $0.end }
    let isFullscreen = !isCameraHidden && fsRegion != nil
    nsView.isCameraFullscreen = isFullscreen
    nsView.currentFullscreenFillMode = cameraFullscreenFillMode
    nsView.currentFullscreenAspect = cameraFullscreenAspect

    let customRegion = cameraCustomRegions.first(where: { currentTime >= $0.start && currentTime <= $0.end })

    let transitionProgress: CGFloat = {
      if let r = hiddenRegion {
        let p = Self.computeTransitionProgress(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
        return 1.0 - p
      }
      if let r = fsRegion {
        return Self.computeTransitionProgress(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      if let r = customRegion {
        return Self.computeTransitionProgress(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      return 1.0
    }()

    let activeTransitionType: RegionTransitionType = {
      if let r = hiddenRegion {
        return Self.resolveTransitionType(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      if let r = fsRegion {
        return Self.resolveTransitionType(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      if let r = customRegion {
        return Self.resolveTransitionType(
          time: currentTime,
          start: r.start,
          end: r.end,
          entryTransition: r.entryTransition,
          entryDuration: r.entryDuration,
          exitTransition: r.exitTransition,
          exitDuration: r.exitDuration
        )
      }
      return .none
    }()

    nsView.cameraTransitionProgress = transitionProgress
    nsView.cameraTransitionType = activeTransitionType

    let videoRegion = videoRegions.first(where: { currentTime >= $0.start && currentTime <= $0.end })
    let screenTransitionProgress: CGFloat = {
      guard let r = videoRegion else { return 1.0 }
      return Self.computeTransitionProgress(
        time: currentTime,
        start: r.start,
        end: r.end,
        entryTransition: r.entryTransition,
        entryDuration: r.entryDuration,
        exitTransition: r.exitTransition,
        exitDuration: r.exitDuration
      )
    }()
    let screenTransitionType: RegionTransitionType = {
      guard let r = videoRegion else { return .none }
      return Self.resolveTransitionType(
        time: currentTime,
        start: r.start,
        end: r.end,
        entryTransition: r.entryTransition,
        entryDuration: r.entryDuration,
        exitTransition: r.exitTransition,
        exitDuration: r.exitDuration
      )
    }()
    nsView.screenTransitionProgress = screenTransitionProgress
    nsView.screenTransitionType = screenTransitionType
    nsView.isScreenHidden = isPreviewMode && !videoRegions.isEmpty && videoRegion == nil

    let prevStyle = nsView.currentCameraBackgroundStyle
    let prevImage = nsView.currentCameraBackgroundImage
    nsView.currentCameraBackgroundStyle = cameraBackgroundStyle
    nsView.currentCameraBackgroundImage = cameraBackgroundImage
    let styleChanged = prevStyle != cameraBackgroundStyle || prevImage !== cameraBackgroundImage
    if styleChanged {
      nsView.lastProcessedWebcamTime = -1
    }
    if cameraBackgroundStyle != .none, webcamPlayer != nil {
      if prevStyle == .none, let webcam = webcamPlayer {
        nsView.setupWebcamOutput(for: webcam)
      } else {
        nsView.processCurrentWebcamFrame()
      }
    } else if prevStyle != .none {
      nsView.teardownWebcamOutput()
    }

    let effectiveLayout = customRegion?.layout ?? cameraLayout

    nsView.updateCameraLayout(
      effectiveLayout,
      webcamSize: webcamSize,
      screenSize: screenSize,
      canvasSize: canvasSize,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      cameraAspect: customRegion?.cameraAspect ?? cameraAspect,
      cameraCornerRadius: customRegion?.cornerRadius ?? cameraCornerRadius,
      cameraBorderWidth: customRegion?.borderWidth ?? cameraBorderWidth,
      cameraBorderColor: customRegion?.borderColor ?? cameraBorderColor,
      videoShadow: videoShadow,
      cameraShadow: customRegion?.shadow ?? cameraShadow,
      cameraMirrored: customRegion?.mirrored ?? cameraMirrored
    )

    if let zoom = zoomTimeline {
      var zoomRect = zoom.zoomRect(at: currentTime)
      if zoomFollowCursor, zoomRect.width < 1.0 || zoomRect.height < 1.0,
        let provider = cursorMetadataProvider
      {
        let cursorPos = provider.sample(at: currentTime)
        zoomRect = ZoomTimeline.followCursor(zoomRect, cursorPosition: cursorPos)
      }
      nsView.updateZoomRect(zoomRect)
    } else {
      nsView.updateZoomRect(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    if let provider = cursorMetadataProvider, showCursor {
      let pos = provider.sample(at: currentTime)
      let clicks = showClickHighlights ? provider.activeClicks(at: currentTime) : []
      nsView.updateCursorOverlay(
        normalizedPosition: pos,
        style: cursorStyle,
        size: cursorSize,
        visible: true,
        clicks: clicks,
        clickHighlightColor: clickHighlightColor,
        clickHighlightSize: clickHighlightSize,
        cursorFillColor: cursorFillColor,
        cursorStrokeColor: cursorStrokeColor
      )
    } else {
      nsView.updateCursorOverlay(
        normalizedPosition: .zero,
        style: .centerDefault,
        size: 24,
        visible: false,
        clicks: []
      )
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(cameraLayout: $cameraLayout, screenSize: screenSize, canvasSize: canvasSize, webcamSize: webcamSize)
  }

  final class Coordinator {
    var cameraLayout: Binding<CameraLayout>
    let screenSize: CGSize
    var canvasSize: CGSize
    let webcamSize: CGSize?
    var isDragging = false
    var dragStart: CGPoint = .zero
    var startLayout: CameraLayout = CameraLayout()

    init(cameraLayout: Binding<CameraLayout>, screenSize: CGSize, canvasSize: CGSize, webcamSize: CGSize?) {
      self.cameraLayout = cameraLayout
      self.screenSize = screenSize
      self.canvasSize = canvasSize
      self.webcamSize = webcamSize
    }
  }
}

final class VideoPreviewContainer: NSView {
  let screenPlayerLayer = AVPlayerLayer()
  let webcamPlayerLayer = AVPlayerLayer()
  let webcamWrapper = NSView()
  let webcamView = WebcamCameraView()
  let cursorOverlay = CursorOverlayLayer()
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
  var currentCameraBackgroundStyle: CameraBackgroundStyle = .none
  var currentCameraBackgroundImage: NSImage?
  var webcamOutput: AVPlayerItemVideoOutput?
  let processedWebcamLayer = CALayer()
  private let segmentationProcessor = PersonSegmentationProcessor(quality: .balanced)
  private let segmentationQueue = DispatchQueue(label: "eu.jkuri.reframed.segmentation", qos: .userInteractive)
  private var isProcessingWebcamFrame = false
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
  }
}

extension VideoPreviewContainer {
  func setupWebcamOutput(for player: AVPlayer) {
    guard webcamOutput == nil else { return }
    let formatKey = kCVPixelBufferPixelFormatTypeKey as String
    let formatValue = Int(kCVPixelFormatType_32BGRA)
    let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [formatKey: formatValue])
    output.setDelegate(self, queue: .main)
    player.currentItem?.add(output)
    webcamOutput = output
    output.requestNotificationOfMediaDataChange(withAdvanceInterval: 0.0)
  }

  func teardownWebcamOutput() {
    if let output = webcamOutput, let item = webcamPlayerLayer.player?.currentItem {
      item.remove(output)
    }
    webcamOutput = nil
    processedWebcamLayer.contents = nil
    processedWebcamLayer.isHidden = true
    webcamPlayerLayer.isHidden = false
    lastProcessedWebcamTime = -1
  }

  func processCurrentWebcamFrame() {
    guard currentCameraBackgroundStyle != .none,
      let output = webcamOutput,
      let player = webcamPlayerLayer.player
    else {
      processedWebcamLayer.isHidden = true
      webcamPlayerLayer.isHidden = false
      return
    }

    guard !isProcessingWebcamFrame else { return }

    let time = player.currentTime()
    let seconds = CMTimeGetSeconds(time)
    guard seconds.isFinite else { return }

    let itemTime = output.itemTime(forHostTime: CACurrentMediaTime())
    guard output.hasNewPixelBuffer(forItemTime: itemTime) || abs(seconds - lastProcessedWebcamTime) > 0.01 else {
      return
    }

    var backgroundCGImage: CGImage?
    if case .image = currentCameraBackgroundStyle, let nsImage = currentCameraBackgroundImage {
      var rect = CGRect(origin: .zero, size: nsImage.size)
      backgroundCGImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    guard let pixelBuffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }
    lastProcessedWebcamTime = seconds
    isProcessingWebcamFrame = true

    let style = currentCameraBackgroundStyle
    let processor = segmentationProcessor
    let bgImage = backgroundCGImage
    nonisolated(unsafe) let buffer = pixelBuffer

    segmentationQueue.async { [weak self] in
      let processed = processor.processFrame(
        webcamBuffer: buffer,
        style: style,
        backgroundCGImage: bgImage
      )
      DispatchQueue.main.async {
        guard let self else { return }
        self.isProcessingWebcamFrame = false
        guard let processed else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.processedWebcamLayer.contents = processed
        self.processedWebcamLayer.isHidden = false
        self.syncProcessedWebcamLayer()
        self.webcamPlayerLayer.isHidden = true
        CATransaction.commit()
      }
    }
  }
}

extension VideoPreviewContainer: AVPlayerItemOutputPullDelegate {
  nonisolated func outputMediaDataWillChange(_ sender: AVPlayerItemOutput) {
    DispatchQueue.main.async { [weak self] in
      self?.processCurrentWebcamFrame()
    }
  }
}

final class WebcamCameraView: NSView {
  override var isFlipped: Bool { true }
}
