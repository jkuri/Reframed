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
  var cursorStyle: CursorStyle = .defaultArrow
  var cursorSize: CGFloat = 24
  var showClickHighlights: Bool = true
  var clickHighlightColor: CGColor = CGColor(srgbRed: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
  var clickHighlightSize: CGFloat = 36
  var zoomFollowCursor: Bool = true
  var currentTime: Double = 0
  var zoomTimeline: ZoomTimeline?
  var cameraFullscreenRegions: [(start: Double, end: Double)] = []
  var cameraFullscreenFillMode: CameraFullscreenFillMode = .fit
  var cameraFullscreenAspect: CameraFullscreenAspect = .original

  func makeNSView(context: Context) -> VideoPreviewContainer {
    let container = VideoPreviewContainer()
    container.screenPlayerLayer.player = screenPlayer
    if let webcam = webcamPlayer {
      container.webcamPlayerLayer.player = webcam
      container.webcamPlayerLayer.isHidden = false
    }
    container.coordinator = context.coordinator
    return container
  }

  func updateNSView(_ nsView: VideoPreviewContainer, context: Context) {
    context.coordinator.canvasSize = canvasSize

    let isFullscreen = cameraFullscreenRegions.contains { currentTime >= $0.start && currentTime <= $0.end }
    nsView.isCameraFullscreen = isFullscreen
    nsView.currentFullscreenFillMode = cameraFullscreenFillMode
    nsView.currentFullscreenAspect = cameraFullscreenAspect

    nsView.updateCameraLayout(
      cameraLayout,
      webcamSize: webcamSize,
      screenSize: screenSize,
      canvasSize: canvasSize,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      cameraAspect: cameraAspect,
      cameraCornerRadius: cameraCornerRadius,
      cameraBorderWidth: cameraBorderWidth,
      cameraBorderColor: cameraBorderColor,
      videoShadow: videoShadow,
      cameraShadow: cameraShadow,
      cameraMirrored: cameraMirrored
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
        clickHighlightSize: clickHighlightSize
      )
    } else {
      nsView.updateCursorOverlay(
        normalizedPosition: .zero,
        style: .defaultArrow,
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
  private let webcamWrapper = NSView()
  private let webcamView = WebcamCameraView()
  private let cursorOverlay = CursorOverlayLayer()
  private let screenContainerLayer = CALayer()
  var coordinator: VideoPreviewView.Coordinator?
  var isCameraFullscreen = false
  var currentFullscreenFillMode: CameraFullscreenFillMode = .fit
  var currentFullscreenAspect: CameraFullscreenAspect = .original
  private var isDraggingCamera = false
  private var currentLayout = CameraLayout()
  private var currentWebcamSize: CGSize?
  private var currentScreenSize: CGSize = .zero
  private var currentCanvasSize: CGSize = .zero
  private var currentPadding: CGFloat = 0
  private var currentVideoCornerRadius: CGFloat = 0
  private var currentCameraAspect: CameraAspect = .original
  private var currentCameraCornerRadius: CGFloat = 12
  private var currentCameraBorderWidth: CGFloat = 0
  private var currentCameraBorderColor: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3)
  private var currentVideoShadow: CGFloat = 0
  private var currentCameraShadow: CGFloat = 0
  private var currentCameraMirrored: Bool = false
  private let screenMaskLayer = CAShapeLayer()
  private let screenShadowLayer = CALayer()
  private var trackingArea: NSTrackingArea?
  private var currentZoomRect = CGRect(x: 0, y: 0, width: 1, height: 1)

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
    layer?.addSublayer(cursorOverlay)

    webcamWrapper.wantsLayer = true
    webcamWrapper.layer?.masksToBounds = false

    webcamView.wantsLayer = true
    webcamView.layer?.cornerRadius = 12
    webcamView.layer?.masksToBounds = true
    webcamView.layer?.borderWidth = 0
    webcamView.layer?.borderColor = NSColor.clear.cgColor
    webcamPlayerLayer.videoGravity = .resizeAspectFill
    webcamView.layer?.addSublayer(webcamPlayerLayer)
    webcamPlayerLayer.isHidden = true

    webcamWrapper.addSubview(webcamView)
    addSubview(webcamWrapper)
  }

  required init?(coder: NSCoder) { nil }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let loc = convert(point, from: superview)
    if !webcamWrapper.isHidden && webcamWrapper.frame.contains(loc) {
      return self
    }
    return super.hitTest(point)
  }

  override func layout() {
    super.layout()
    layoutAll()
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let existing = trackingArea {
      removeTrackingArea(existing)
    }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
      owner: self
    )
    addTrackingArea(area)
    trackingArea = area
  }

  func updateCameraLayout(
    _ layout: CameraLayout,
    webcamSize: CGSize?,
    screenSize: CGSize,
    canvasSize: CGSize,
    padding: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    cameraAspect: CameraAspect = .original,
    cameraCornerRadius: CGFloat = 12,
    cameraBorderWidth: CGFloat = 0,
    cameraBorderColor: CGColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.3),
    videoShadow: CGFloat = 0,
    cameraShadow: CGFloat = 0,
    cameraMirrored: Bool = false
  ) {
    currentLayout = layout
    currentWebcamSize = webcamSize
    currentScreenSize = screenSize
    currentCanvasSize = canvasSize.width > 0 ? canvasSize : screenSize
    currentPadding = padding
    currentVideoCornerRadius = videoCornerRadius
    currentCameraAspect = cameraAspect
    currentCameraCornerRadius = cameraCornerRadius
    currentCameraBorderWidth = cameraBorderWidth
    currentCameraBorderColor = cameraBorderColor
    currentVideoShadow = videoShadow
    currentCameraShadow = cameraShadow
    currentCameraMirrored = cameraMirrored
    layoutAll()
  }

  func updateCursorOverlay(
    normalizedPosition: CGPoint,
    style: CursorStyle,
    size: CGFloat,
    visible: Bool,
    clicks: [(point: CGPoint, progress: Double)],
    clickHighlightColor: CGColor? = nil,
    clickHighlightSize: CGFloat = 36
  ) {
    let canvasRect = AVMakeRect(aspectRatio: currentCanvasSize, insideRect: bounds)
    let scaleX = canvasRect.width / max(currentCanvasSize.width, 1)
    let scaleY = canvasRect.height / max(currentCanvasSize.height, 1)
    let padH = currentPadding * currentScreenSize.width * scaleX
    let padV = currentPadding * currentScreenSize.height * scaleY

    let paddedArea = CGRect(
      x: canvasRect.origin.x + padH,
      y: canvasRect.origin.y + padV,
      width: canvasRect.width - padH * 2,
      height: canvasRect.height - padV * 2
    )
    let screenRect = AVMakeRect(aspectRatio: currentScreenSize, insideRect: paddedArea)

    let zr = currentZoomRect
    let isZoomed = zr.width < 1.0 || zr.height < 1.0

    func transformPos(_ pos: CGPoint) -> (CGPoint, Bool) {
      var p = pos
      if isZoomed {
        p = CGPoint(x: (p.x - zr.origin.x) / zr.width, y: (p.y - zr.origin.y) / zr.height)
        if p.x < -0.05 || p.x > 1.05 || p.y < -0.05 || p.y > 1.05 {
          return (p, false)
        }
      }
      let pixelX = screenRect.origin.x + p.x * screenRect.width
      let pixelY = screenRect.origin.y + (1 - p.y) * screenRect.height
      return (CGPoint(x: pixelX, y: pixelY), true)
    }

    let (cursorPixel, cursorVisible) = transformPos(normalizedPosition)

    let adjustedClicks: [(point: CGPoint, progress: Double)] = clicks.compactMap { click in
      let (pixel, vis) = transformPos(click.point)
      guard vis else { return nil }
      return (pixel, click.progress)
    }

    let zoomScale: CGFloat = isZoomed ? 1.0 / zr.width : 1.0
    let baseScale = min(scaleX, scaleY)

    cursorOverlay.update(
      pixelPosition: cursorPixel,
      style: style,
      size: size * baseScale * zoomScale,
      visible: visible && cursorVisible,
      containerSize: bounds.size,
      clicks: adjustedClicks,
      highlightColor: clickHighlightColor,
      highlightSize: clickHighlightSize * baseScale * zoomScale
    )
  }

  func updateZoomRect(_ rect: CGRect) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    currentZoomRect = rect
    let containerBounds = screenContainerLayer.bounds
    if rect.width >= 1.0 && rect.height >= 1.0 {
      screenPlayerLayer.frame = containerBounds
    } else {
      let cw = containerBounds.width
      let ch = containerBounds.height
      let pw = cw / rect.width
      let ph = ch / rect.height
      let px = -rect.origin.x * pw
      let py = -(1 - rect.origin.y - rect.height) * ph
      screenPlayerLayer.frame = CGRect(x: px, y: py, width: pw, height: ph)
    }
    CATransaction.commit()
  }

  private func layoutAll() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    let canvasRect = AVMakeRect(aspectRatio: currentCanvasSize, insideRect: bounds)
    let scaleX = canvasRect.width / max(currentCanvasSize.width, 1)
    let scaleY = canvasRect.height / max(currentCanvasSize.height, 1)
    let padH = currentPadding * currentScreenSize.width * scaleX
    let padV = currentPadding * currentScreenSize.height * scaleY

    let paddedArea = CGRect(
      x: canvasRect.origin.x + padH,
      y: canvasRect.origin.y + padV,
      width: canvasRect.width - padH * 2,
      height: canvasRect.height - padV * 2
    )
    let screenRect = AVMakeRect(aspectRatio: currentScreenSize, insideRect: paddedArea)

    screenContainerLayer.frame = screenRect
    let cornerRadius = min(screenRect.width, screenRect.height) * (currentVideoCornerRadius / 100.0)
    let maskPath = CGPath(
      roundedRect: CGRect(origin: .zero, size: screenRect.size),
      cornerWidth: cornerRadius,
      cornerHeight: cornerRadius,
      transform: nil
    )
    screenMaskLayer.frame = CGRect(origin: .zero, size: screenRect.size)
    screenMaskLayer.path = maskPath
    screenContainerLayer.mask = screenMaskLayer

    if currentVideoShadow > 0 {
      let blur = min(screenRect.width, screenRect.height) * currentVideoShadow / 2000.0
      screenShadowLayer.frame = screenRect
      screenShadowLayer.shadowPath = CGPath(
        roundedRect: CGRect(origin: .zero, size: screenRect.size),
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
      )
      screenShadowLayer.shadowRadius = blur
      screenShadowLayer.shadowOpacity = 0.6
      screenShadowLayer.isHidden = false
    } else {
      screenShadowLayer.isHidden = true
      screenShadowLayer.shadowOpacity = 0
    }

    let zr = currentZoomRect
    if zr.width < 1.0 || zr.height < 1.0 {
      let cw = screenRect.width
      let ch = screenRect.height
      let pw = cw / zr.width
      let ph = ch / zr.height
      let px = -zr.origin.x * pw
      let py = -(1 - zr.origin.y - zr.height) * ph
      screenPlayerLayer.frame = CGRect(x: px, y: py, width: pw, height: ph)
    } else {
      screenPlayerLayer.frame = screenContainerLayer.bounds
    }

    guard let ws = currentWebcamSize, webcamPlayerLayer.player != nil else {
      webcamWrapper.isHidden = true
      CATransaction.commit()
      return
    }

    if isDraggingCamera {
      CATransaction.commit()
      return
    }

    webcamWrapper.isHidden = false

    if isCameraFullscreen {
      webcamWrapper.layer?.shadowOpacity = 0
      screenContainerLayer.isHidden = true
      cursorOverlay.isHidden = true
      webcamWrapper.frame = canvasRect
      webcamView.frame = webcamWrapper.bounds
      webcamView.layer?.cornerRadius = 0
      webcamView.layer?.borderWidth = 0
      webcamView.layer?.borderColor = NSColor.clear.cgColor
      webcamView.layer?.backgroundColor = NSColor.clear.cgColor

      let gravity: AVLayerVideoGravity =
        currentFullscreenFillMode == .fill
        ? .resizeAspectFill : .resizeAspect
      webcamPlayerLayer.videoGravity = gravity

      let containerBounds = webcamView.bounds
      if currentFullscreenAspect == .original {
        webcamPlayerLayer.frame = containerBounds
      } else {
        let targetAspect = currentFullscreenAspect.aspectRatio(webcamSize: ws)
        let virtualSize = CGSize(width: targetAspect * 1000, height: 1000)
        let aspectRect: CGRect
        if currentFullscreenFillMode == .fill {
          let rectAspect = containerBounds.width / max(containerBounds.height, 1)
          let vAspect = virtualSize.width / max(virtualSize.height, 1)
          if vAspect > rectAspect {
            let h = containerBounds.width / max(vAspect, 0.001)
            aspectRect = CGRect(
              x: 0,
              y: containerBounds.midY - h / 2,
              width: containerBounds.width,
              height: h
            )
          } else {
            let w = containerBounds.height * vAspect
            aspectRect = CGRect(
              x: containerBounds.midX - w / 2,
              y: 0,
              width: w,
              height: containerBounds.height
            )
          }
        } else {
          aspectRect = AVMakeRect(aspectRatio: virtualSize, insideRect: containerBounds)
        }
        webcamPlayerLayer.frame = aspectRect
      }

      webcamPlayerLayer.setAffineTransform(
        currentCameraMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
      )
      CATransaction.commit()
      return
    }

    screenContainerLayer.isHidden = false
    cursorOverlay.isHidden = false
    webcamView.layer?.backgroundColor = NSColor.clear.cgColor

    let camAspect = currentCameraAspect.heightToWidthRatio(webcamSize: ws)
    let w = canvasRect.width * currentLayout.relativeWidth
    let h = w * camAspect
    let x = canvasRect.origin.x + canvasRect.width * currentLayout.relativeX
    let y = canvasRect.origin.y + canvasRect.height * currentLayout.relativeY

    let minDim = min(w, h)
    let scaledRadius = minDim * (currentCameraCornerRadius / 100.0)
    let scaledBorder = currentCameraBorderWidth * min(scaleX, scaleY)

    let webcamFrame = CGRect(x: x, y: bounds.height - y - h, width: w, height: h)
    webcamWrapper.frame = webcamFrame
    webcamView.frame = webcamWrapper.bounds
    webcamView.layer?.cornerRadius = scaledRadius
    webcamView.layer?.borderWidth = scaledBorder
    webcamView.layer?.borderColor =
      scaledBorder > 0
      ? currentCameraBorderColor
      : NSColor.clear.cgColor
    webcamPlayerLayer.videoGravity = .resizeAspectFill
    webcamPlayerLayer.frame = webcamView.bounds
    webcamPlayerLayer.setAffineTransform(
      currentCameraMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
    )

    if currentCameraShadow > 0 {
      let camBlur = minDim * currentCameraShadow / 2000.0
      webcamWrapper.layer?.shadowColor = NSColor.black.cgColor
      webcamWrapper.layer?.shadowOffset = .zero
      webcamWrapper.layer?.shadowRadius = camBlur
      webcamWrapper.layer?.shadowOpacity = 0.6
      webcamWrapper.layer?.shadowPath = CGPath(
        roundedRect: webcamView.bounds,
        cornerWidth: scaledRadius,
        cornerHeight: scaledRadius,
        transform: nil
      )
    } else {
      webcamWrapper.layer?.shadowOpacity = 0
    }

    CATransaction.commit()
  }

  override func mouseMoved(with event: NSEvent) {
    guard !webcamWrapper.isHidden else {
      NSCursor.arrow.set()
      return
    }
    let loc = convert(event.locationInWindow, from: nil)
    if webcamWrapper.frame.contains(loc) {
      NSCursor.openHand.set()
    } else {
      NSCursor.arrow.set()
    }
  }

  override func mouseExited(with event: NSEvent) {
    NSCursor.arrow.set()
  }

  override func mouseDown(with event: NSEvent) {
    guard let coord = coordinator else { return super.mouseDown(with: event) }
    let loc = convert(event.locationInWindow, from: nil)

    if webcamWrapper.frame.contains(loc) && !webcamWrapper.isHidden {
      coord.isDragging = true
      NSCursor.closedHand.set()
      coord.dragStart = loc
      coord.startLayout = coord.cameraLayout.wrappedValue
    } else {
      super.mouseDown(with: event)
    }
  }

  override func mouseDragged(with event: NSEvent) {
    guard let coord = coordinator, coord.isDragging else {
      return super.mouseDragged(with: event)
    }
    let loc = convert(event.locationInWindow, from: nil)
    let canvasRect = AVMakeRect(aspectRatio: currentCanvasSize, insideRect: bounds)
    guard canvasRect.width > 0 && canvasRect.height > 0 else { return }

    let dx = (loc.x - coord.dragStart.x) / canvasRect.width
    let dy = -(loc.y - coord.dragStart.y) / canvasRect.height
    var newX = coord.startLayout.relativeX + dx
    var newY = coord.startLayout.relativeY + dy

    let relW = coord.cameraLayout.wrappedValue.relativeWidth
    let relH: CGFloat = {
      guard let ws = currentWebcamSize else { return relW * 0.75 }
      let aspect = currentCameraAspect.heightToWidthRatio(webcamSize: ws)
      return relW * aspect * (currentCanvasSize.width / max(currentCanvasSize.height, 1))
    }()

    newX = max(0, min(1 - relW, newX))
    newY = max(0, min(1 - relH, newY))

    coord.cameraLayout.wrappedValue.relativeX = newX
    coord.cameraLayout.wrappedValue.relativeY = newY

    currentLayout.relativeX = newX
    currentLayout.relativeY = newY

    isDraggingCamera = true
    let camAspect = currentCameraAspect.heightToWidthRatio(
      webcamSize: currentWebcamSize ?? .zero
    )
    let w = canvasRect.width * currentLayout.relativeWidth
    let h = w * camAspect
    let x = canvasRect.origin.x + canvasRect.width * newX
    let y = canvasRect.origin.y + canvasRect.height * newY

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    webcamWrapper.frame = CGRect(x: x, y: bounds.height - y - h, width: w, height: h)
    if currentCameraShadow > 0 {
      let minDim = min(w, h)
      let scaledRadius = minDim * (currentCameraCornerRadius / 100.0)
      let camBlur = minDim * currentCameraShadow / 2000.0
      webcamWrapper.layer?.shadowRadius = camBlur
      webcamWrapper.layer?.shadowOpacity = 0.6
      webcamWrapper.layer?.shadowPath = CGPath(
        roundedRect: webcamView.bounds,
        cornerWidth: scaledRadius,
        cornerHeight: scaledRadius,
        transform: nil
      )
    }
    CATransaction.commit()
  }

  override func mouseUp(with event: NSEvent) {
    let wasDragging = coordinator?.isDragging == true
    coordinator?.isDragging = false
    isDraggingCamera = false
    if wasDragging {
      layoutAll()
      let loc = convert(event.locationInWindow, from: nil)
      if webcamWrapper.frame.contains(loc) {
        NSCursor.openHand.set()
      } else {
        NSCursor.arrow.set()
      }
    }
    super.mouseUp(with: event)
  }
}

private final class WebcamCameraView: NSView {
  override var isFlipped: Bool { true }
}
