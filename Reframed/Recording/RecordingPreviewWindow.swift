import AppKit
import CoreMedia
import CoreVideo

@MainActor
final class RecordingPreviewWindow {
  private var panel: NSPanel?
  private var previewLayer: CALayer?
  nonisolated(unsafe) private var moveObserver: NSObjectProtocol?
  private var resizeObserver: NSObjectProtocol?
  private var appearanceObserver: NSKeyValueObservation?

  private let defaultVideoWidth: CGFloat = 320
  private var defaultVideoHeight: CGFloat = 180
  private let videoCornerRadius: CGFloat = 8
  private let padding: CGFloat = 6
  private let handleZone: CGFloat = 10

  private var aspectRatio: CGFloat = 16.0 / 9.0

  nonisolated(unsafe) private var lastUpdateTime: CFAbsoluteTime = 0
  private let minUpdateInterval: CFAbsoluteTime = 1.0 / 30.0

  func show(width: Int, height: Int) {
    if width > 0 && height > 0 {
      aspectRatio = CGFloat(width) / CGFloat(height)
    }
    defaultVideoHeight = round(defaultVideoWidth / aspectRatio)

    if panel == nil {
      createPanel()
    }

    guard let contentView = panel?.contentView as? PreviewContentView else { return }

    let videoRect = NSRect(
      x: padding,
      y: padding,
      width: contentView.bounds.width - padding * 2,
      height: contentView.bounds.height - padding * 2
    )
    let videoView = NSView(frame: videoRect)
    videoView.wantsLayer = true
    videoView.layer?.cornerRadius = videoCornerRadius
    videoView.layer?.masksToBounds = true
    videoView.layer?.backgroundColor = NSColor.black.cgColor
    videoView.autoresizingMask = [.width, .height]

    let layer = CALayer()
    layer.frame = videoView.bounds
    layer.contentsGravity = .resizeAspect
    layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    videoView.layer?.addSublayer(layer)
    self.previewLayer = layer

    contentView.addSubview(videoView)
    panel?.orderFrontRegardless()
  }

  nonisolated func updateFrame(_ sampleBuffer: CMSampleBuffer) {
    let now = CFAbsoluteTimeGetCurrent()
    guard now - lastUpdateTime >= minUpdateInterval else { return }
    lastUpdateTime = now

    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    let ioSurface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
    guard let surface = ioSurface else { return }

    nonisolated(unsafe) let unsafeSurface = surface
    DispatchQueue.main.async { [weak self] in
      self?.previewLayer?.contents = unsafeSurface
    }
  }

  func hide() {
    panel?.orderOut(nil)
  }

  func unhide() {
    panel?.orderFrontRegardless()
  }

  func close() {
    savePosition()
    if let observer = moveObserver {
      NotificationCenter.default.removeObserver(observer)
      moveObserver = nil
    }
    if let observer = resizeObserver {
      NotificationCenter.default.removeObserver(observer)
      resizeObserver = nil
    }
    appearanceObserver?.invalidate()
    appearanceObserver = nil
    previewLayer?.removeFromSuperlayer()
    previewLayer = nil
    panel?.orderOut(nil)
    panel?.contentView = nil
    panel = nil
  }

  private func createPanel() {
    let savedHeight = StateService.shared.recordingPreviewHeight
    let videoH = savedHeight ?? defaultVideoHeight
    let videoW = round(videoH * aspectRatio)
    let panelW = videoW + padding * 2
    let panelH = videoH + padding * 2
    let origin = resolvedOrigin(width: panelW, height: panelH)

    let panel = PreviewPanel(
      contentRect: NSRect(origin: origin, size: NSSize(width: panelW, height: panelH)),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    panel.isFloatingPanel = true
    panel.isMovableByWindowBackground = false
    panel.acceptsMouseMovedEvents = true
    panel.hasShadow = true
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.sharingType = Window.sharingType

    let contentView = PreviewContentView(
      frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)),
      aspectRatio: aspectRatio,
      padding: padding,
      handleZone: handleZone
    )

    panel.contentView = contentView
    self.panel = panel

    moveObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didMoveNotification,
      object: panel,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.savePosition() }
    }

    resizeObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didResizeNotification,
      object: panel,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.savePosition() }
    }

    appearanceObserver = NSApp.observe(\.effectiveAppearance) { [weak contentView] _, _ in
      MainActor.assumeIsolated {
        contentView?.needsDisplay = true
      }
    }
  }

  private func resolvedOrigin(width: CGFloat, height: CGFloat) -> CGPoint {
    if let saved = StateService.shared.recordingPreviewPosition {
      let panelRect = NSRect(origin: saved, size: NSSize(width: width, height: height))
      for screen in NSScreen.screens {
        if screen.visibleFrame.intersects(panelRect) {
          return saved
        }
      }
    }
    return defaultOrigin()
  }

  private func defaultOrigin() -> CGPoint {
    guard let screen = NSScreen.main else { return .zero }
    let screenFrame = screen.visibleFrame
    let totalW = defaultVideoWidth + padding * 2
    let totalH = defaultVideoHeight + padding * 2
    return CGPoint(
      x: screenFrame.maxX - totalW - 20,
      y: screenFrame.maxY - totalH - 60
    )
  }

  private func savePosition() {
    guard let frame = panel?.frame else { return }
    StateService.shared.recordingPreviewPosition = frame.origin
    StateService.shared.recordingPreviewHeight = frame.height - padding * 2
  }
}

private final class PreviewPanel: NSPanel {
  override var canBecomeKey: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .mouseMoved || event.type == .mouseEntered || event.type == .mouseExited {
      (contentView as? PreviewContentView)?.handleMouseEvent(event)
      return
    }
    super.sendEvent(event)
  }
}

private final class PreviewContentView: NSView {
  private enum DragMode {
    case none
    case move
    case resize(ResizeHandle)
  }

  private var dragMode: DragMode = .none
  private var dragStart: NSPoint = .zero
  private var initialFrame: NSRect = .zero
  private let aspectRatio: CGFloat
  private let padding: CGFloat
  private let handleZone: CGFloat
  private let minVideoWidth: CGFloat = 160
  private let maxVideoWidth: CGFloat = 800
  private let videoCornerRadius: CGFloat = 8

  init(frame: NSRect, aspectRatio: CGFloat, padding: CGFloat, handleZone: CGFloat) {
    self.aspectRatio = aspectRatio
    self.padding = padding
    self.handleZone = handleZone
    super.init(frame: frame)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError()
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let cr = videoCornerRadius + padding
    let outerPath = CGPath(roundedRect: bounds, cornerWidth: cr, cornerHeight: cr, transform: nil)
    ctx.addPath(outerPath)
    ctx.setFillColor(ReframedColors.backgroundNS.withAlphaComponent(0.7).cgColor)
    ctx.fillPath()

    let borderPath = CGPath(
      roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
      cornerWidth: cr,
      cornerHeight: cr,
      transform: nil
    )
    ctx.addPath(borderPath)
    ctx.setStrokeColor(ReframedColors.borderNS.cgColor)
    ctx.setLineWidth(1)
    ctx.strokePath()
  }

  private func hitHandle(at point: NSPoint) -> ResizeHandle? {
    let w = bounds.width
    let h = bounds.height
    let zone = handleZone

    let nearLeft = point.x < zone
    let nearRight = point.x > w - zone
    let nearBottom = point.y < zone
    let nearTop = point.y > h - zone

    if nearTop && nearLeft { return .topLeft }
    if nearTop && nearRight { return .topRight }
    if nearBottom && nearLeft { return .bottomLeft }
    if nearBottom && nearRight { return .bottomRight }
    if nearTop { return .top }
    if nearBottom { return .bottom }
    if nearLeft { return .left }
    if nearRight { return .right }
    return nil
  }

  func handleMouseEvent(_ event: NSEvent) {
    if event.type == .mouseExited {
      NSCursor.arrow.set()
      return
    }
    let loc = convert(event.locationInWindow, from: nil)
    if let handle = hitHandle(at: loc) {
      handle.cursor.set()
    } else if bounds.contains(loc) {
      NSCursor.openHand.set()
    } else {
      NSCursor.arrow.set()
    }
  }

  override func mouseDown(with event: NSEvent) {
    guard let window else { return }
    let loc = convert(event.locationInWindow, from: nil)
    initialFrame = window.frame
    dragStart = NSEvent.mouseLocation

    if let handle = hitHandle(at: loc) {
      dragMode = .resize(handle)
      handle.cursor.push()
    } else {
      dragMode = .move
      NSCursor.closedHand.push()
    }
  }

  override func mouseDragged(with event: NSEvent) {
    guard let window else { return }
    let mouse = NSEvent.mouseLocation
    let dx = mouse.x - dragStart.x
    let dy = mouse.y - dragStart.y

    switch dragMode {
    case .move:
      window.setFrameOrigin(
        NSPoint(
          x: initialFrame.origin.x + dx,
          y: initialFrame.origin.y + dy
        )
      )

    case .resize(let handle):
      let f = initialFrame
      let oldVideoW = f.width - padding * 2
      let delta = CGPoint(x: dx, y: dy)
      let freeRect = handle.resize(
        original: CGRect(x: 0, y: 0, width: oldVideoW, height: oldVideoW / aspectRatio),
        delta: delta
      )

      var newVideoW = max(minVideoWidth, min(maxVideoWidth, freeRect.width))
      let newVideoH = round(newVideoW / aspectRatio)
      newVideoW = round(newVideoH * aspectRatio)
      let newW = newVideoW + padding * 2
      let newH = newVideoH + padding * 2

      var newX = f.origin.x
      var newY = f.origin.y

      switch handle {
      case .left, .topLeft, .bottomLeft:
        newX = f.maxX - newW
      default:
        break
      }

      switch handle {
      case .top, .topLeft, .topRight:
        break
      default:
        newY = f.maxY - newH
      }

      window.setFrame(NSRect(x: newX, y: newY, width: newW, height: newH), display: true)

    case .none:
      break
    }
  }

  override func mouseUp(with event: NSEvent) {
    if case .none = dragMode {} else { NSCursor.pop() }
    dragMode = .none
  }
}
