import AVFoundation
import AppKit
import SwiftUI

struct VideoPreviewView: NSViewRepresentable {
  let screenPlayer: AVPlayer
  let webcamPlayer: AVPlayer?
  @Binding var pipLayout: PiPLayout
  let webcamSize: CGSize?
  let screenSize: CGSize
  let canvasSize: CGSize
  var padding: CGFloat = 0
  var videoCornerRadius: CGFloat = 0
  var pipCornerRadius: CGFloat = 12
  var pipBorderWidth: CGFloat = 0
  var cursorMetadataProvider: CursorMetadataProvider?
  var showCursor: Bool = false
  var cursorStyle: CursorStyle = .defaultArrow
  var cursorSize: CGFloat = 24
  var cursorSmoothing: CursorSmoothing = .standard
  var showClickHighlights: Bool = true
  var clickHighlightColor: CGColor = CGColor(srgbRed: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
  var clickHighlightSize: CGFloat = 36
  var zoomFollowCursor: Bool = true
  var currentTime: Double = 0
  var zoomTimeline: ZoomTimeline?

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
    nsView.updatePiPLayout(
      pipLayout,
      webcamSize: webcamSize,
      screenSize: screenSize,
      canvasSize: canvasSize,
      padding: padding,
      videoCornerRadius: videoCornerRadius,
      pipCornerRadius: pipCornerRadius,
      pipBorderWidth: pipBorderWidth
    )

    if let zoom = zoomTimeline {
      var zoomRect = zoom.zoomRect(at: currentTime)
      if zoomFollowCursor, zoomRect.width < 1.0 || zoomRect.height < 1.0,
        let provider = cursorMetadataProvider
      {
        let cursorPos = provider.sample(at: currentTime, smoothing: cursorSmoothing)
        zoomRect = ZoomTimeline.followCursor(zoomRect, cursorPosition: cursorPos)
      }
      nsView.updateZoomRect(zoomRect)
    } else {
      nsView.updateZoomRect(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    if let provider = cursorMetadataProvider, showCursor {
      let pos = provider.sample(at: currentTime, smoothing: cursorSmoothing)
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
    Coordinator(pipLayout: $pipLayout, screenSize: screenSize, canvasSize: canvasSize, webcamSize: webcamSize)
  }

  final class Coordinator {
    var pipLayout: Binding<PiPLayout>
    let screenSize: CGSize
    var canvasSize: CGSize
    let webcamSize: CGSize?
    var isDragging = false
    var dragStart: CGPoint = .zero
    var startLayout: PiPLayout = PiPLayout()

    init(pipLayout: Binding<PiPLayout>, screenSize: CGSize, canvasSize: CGSize, webcamSize: CGSize?) {
      self.pipLayout = pipLayout
      self.screenSize = screenSize
      self.canvasSize = canvasSize
      self.webcamSize = webcamSize
    }
  }
}

final class VideoPreviewContainer: NSView {
  let screenPlayerLayer = AVPlayerLayer()
  let webcamPlayerLayer = AVPlayerLayer()
  private let webcamView = WebcamPiPView()
  private let cursorOverlay = CursorOverlayLayer()
  private let screenContainerLayer = CALayer()
  var coordinator: VideoPreviewView.Coordinator?
  private var currentLayout = PiPLayout()
  private var currentWebcamSize: CGSize?
  private var currentScreenSize: CGSize = .zero
  private var currentCanvasSize: CGSize = .zero
  private var currentPadding: CGFloat = 0
  private var currentVideoCornerRadius: CGFloat = 0
  private var currentPipCornerRadius: CGFloat = 12
  private var currentPipBorderWidth: CGFloat = 0
  private let screenMaskLayer = CAShapeLayer()
  private var trackingArea: NSTrackingArea?
  private var currentZoomRect = CGRect(x: 0, y: 0, width: 1, height: 1)

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    screenContainerLayer.masksToBounds = true
    layer?.addSublayer(screenContainerLayer)

    screenPlayerLayer.videoGravity = .resizeAspectFill
    screenContainerLayer.addSublayer(screenPlayerLayer)

    cursorOverlay.zPosition = 10
    layer?.addSublayer(cursorOverlay)

    webcamView.wantsLayer = true
    webcamView.layer?.cornerRadius = 12
    webcamView.layer?.masksToBounds = true
    webcamView.layer?.borderWidth = 0
    webcamView.layer?.borderColor = NSColor.clear.cgColor
    webcamPlayerLayer.videoGravity = .resizeAspectFill
    webcamView.layer?.addSublayer(webcamPlayerLayer)
    webcamPlayerLayer.isHidden = true
    addSubview(webcamView)
  }

  required init?(coder: NSCoder) { nil }

  override func hitTest(_ point: NSPoint) -> NSView? {
    let loc = convert(point, from: superview)
    if !webcamView.isHidden && webcamView.frame.contains(loc) {
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

  func updatePiPLayout(
    _ layout: PiPLayout,
    webcamSize: CGSize?,
    screenSize: CGSize,
    canvasSize: CGSize,
    padding: CGFloat = 0,
    videoCornerRadius: CGFloat = 0,
    pipCornerRadius: CGFloat = 12,
    pipBorderWidth: CGFloat = 0
  ) {
    currentLayout = layout
    currentWebcamSize = webcamSize
    currentScreenSize = screenSize
    currentCanvasSize = canvasSize.width > 0 ? canvasSize : screenSize
    currentPadding = padding
    currentVideoCornerRadius = videoCornerRadius
    currentPipCornerRadius = pipCornerRadius
    currentPipBorderWidth = pipBorderWidth
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

    let screenRect = CGRect(
      x: canvasRect.origin.x + padH,
      y: canvasRect.origin.y + padV,
      width: canvasRect.width - padH * 2,
      height: canvasRect.height - padV * 2
    )

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

    cursorOverlay.update(
      pixelPosition: cursorPixel,
      style: style,
      size: size * min(scaleX, scaleY),
      visible: visible && cursorVisible,
      containerSize: bounds.size,
      clicks: adjustedClicks,
      highlightColor: clickHighlightColor,
      highlightSize: clickHighlightSize * min(scaleX, scaleY)
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

    let screenRect = CGRect(
      x: canvasRect.origin.x + padH,
      y: canvasRect.origin.y + padV,
      width: canvasRect.width - padH * 2,
      height: canvasRect.height - padV * 2
    )

    screenContainerLayer.frame = screenRect
    let maskPath = CGPath(
      roundedRect: CGRect(origin: .zero, size: screenRect.size),
      cornerWidth: currentVideoCornerRadius * min(scaleX, scaleY),
      cornerHeight: currentVideoCornerRadius * min(scaleX, scaleY),
      transform: nil
    )
    screenMaskLayer.frame = CGRect(origin: .zero, size: screenRect.size)
    screenMaskLayer.path = maskPath
    screenContainerLayer.mask = screenMaskLayer

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
      webcamView.isHidden = true
      CATransaction.commit()
      return
    }
    webcamView.isHidden = false

    let aspect = ws.height / max(ws.width, 1)
    let w = canvasRect.width * currentLayout.relativeWidth
    let h = w * aspect
    let x = canvasRect.origin.x + canvasRect.width * currentLayout.relativeX
    let y = canvasRect.origin.y + canvasRect.height * currentLayout.relativeY

    let minDim = min(w, h)
    let scaledRadius = minDim * (currentPipCornerRadius / 100.0)
    let scaledBorder = currentPipBorderWidth * min(scaleX, scaleY)

    webcamView.frame = CGRect(x: x, y: bounds.height - y - h, width: w, height: h)
    webcamView.layer?.cornerRadius = scaledRadius
    webcamView.layer?.borderWidth = scaledBorder
    webcamView.layer?.borderColor =
      scaledBorder > 0
      ? NSColor.white.withAlphaComponent(0.3).cgColor
      : NSColor.clear.cgColor
    webcamPlayerLayer.frame = webcamView.bounds

    CATransaction.commit()
  }

  override func mouseMoved(with event: NSEvent) {
    guard !webcamView.isHidden else {
      NSCursor.arrow.set()
      return
    }
    let loc = convert(event.locationInWindow, from: nil)
    if webcamView.frame.contains(loc) {
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

    if webcamView.frame.contains(loc) && !webcamView.isHidden {
      coord.isDragging = true
      NSCursor.closedHand.set()
      coord.dragStart = loc
      coord.startLayout = coord.pipLayout.wrappedValue
    } else {
      super.mouseDown(with: event)
    }
  }

  override func mouseDragged(with event: NSEvent) {
    guard let coord = coordinator, coord.isDragging else {
      return super.mouseDragged(with: event)
    }
    let loc = convert(event.locationInWindow, from: nil)
    let canvasRect = AVMakeRect(aspectRatio: coord.canvasSize, insideRect: bounds)
    guard canvasRect.width > 0 && canvasRect.height > 0 else { return }

    let dx = (loc.x - coord.dragStart.x) / canvasRect.width
    let dy = -(loc.y - coord.dragStart.y) / canvasRect.height
    var newX = coord.startLayout.relativeX + dx
    var newY = coord.startLayout.relativeY + dy

    let relW = coord.pipLayout.wrappedValue.relativeWidth
    let relH: CGFloat = {
      guard let ws = coord.webcamSize else { return relW * 0.75 }
      let aspect = ws.height / max(ws.width, 1)
      return relW * aspect * (coord.canvasSize.width / max(coord.canvasSize.height, 1))
    }()

    newX = max(0, min(1 - relW, newX))
    newY = max(0, min(1 - relH, newY))

    let snapDistX: CGFloat = 20 / canvasRect.width
    let snapDistY: CGFloat = 20 / canvasRect.height
    if newX < snapDistX { newX = 0.02 }
    if newX > 1 - relW - snapDistX { newX = 1 - relW - 0.02 }
    if newY < snapDistY { newY = 0.02 }
    if newY > 1 - relH - snapDistY { newY = 1 - relH - 0.02 }

    coord.pipLayout.wrappedValue.relativeX = newX
    coord.pipLayout.wrappedValue.relativeY = newY
  }

  override func mouseUp(with event: NSEvent) {
    let wasDragging = coordinator?.isDragging == true
    coordinator?.isDragging = false
    if wasDragging {
      let loc = convert(event.locationInWindow, from: nil)
      if webcamView.frame.contains(loc) {
        NSCursor.openHand.set()
      } else {
        NSCursor.arrow.set()
      }
    }
    super.mouseUp(with: event)
  }
}

private final class WebcamPiPView: NSView {
  override var isFlipped: Bool { true }
}
