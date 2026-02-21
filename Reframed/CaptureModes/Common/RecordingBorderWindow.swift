import AppKit
import QuartzCore

@MainActor
final class RecordingBorderWindow: NSWindow {
  init(screenRect: CGRect) {
    guard let screen = NSScreen.screens.first(where: { $0.frame.contains(screenRect.origin) }) ?? NSScreen.main else {
      super.init(
        contentRect: .zero,
        styleMask: .borderless,
        backing: .buffered,
        defer: false
      )
      return
    }

    super.init(
      contentRect: screen.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    ignoresMouseEvents = true
    hasShadow = false
    sharingType = .none

    let windowOrigin = screen.frame.origin
    let localCaptureRect = CGRect(
      x: screenRect.origin.x - windowOrigin.x,
      y: screenRect.origin.y - windowOrigin.y,
      width: screenRect.width,
      height: screenRect.height
    )

    let view = RecordingBorderLayerView(
      frame: CGRect(origin: .zero, size: screen.frame.size),
      captureRect: localCaptureRect,
      dimOuterArea: ConfigService.shared.dimOuterArea
    )
    contentView = view
  }

  func updateCaptureRect(screenRect: CGRect) {
    guard let screen = NSScreen.screens.first(where: { $0.frame.contains(screenRect.origin) }) ?? NSScreen.main
    else { return }

    if frame != screen.frame {
      setFrame(screen.frame, display: false)
    }

    guard let layerView = contentView as? RecordingBorderLayerView else { return }
    let windowOrigin = screen.frame.origin
    let localCaptureRect = CGRect(
      x: screenRect.origin.x - windowOrigin.x,
      y: screenRect.origin.y - windowOrigin.y,
      width: screenRect.width,
      height: screenRect.height
    )
    layerView.updateCaptureRect(localCaptureRect)
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private final class RecordingBorderLayerView: NSView {
  private let topDim = CALayer()
  private let bottomDim = CALayer()
  private let leftDim = CALayer()
  private let rightDim = CALayer()
  private let borderLayer = CAShapeLayer()
  private let dimOuterArea: Bool
  private var captureRect: CGRect

  init(frame: NSRect, captureRect: CGRect, dimOuterArea: Bool) {
    self.captureRect = captureRect
    self.dimOuterArea = dimOuterArea
    super.init(frame: frame)

    wantsLayer = true
    layer?.isOpaque = false

    let dimColor = ReframedColors.overlayBackground.cgColor
    for dim in [topDim, bottomDim, leftDim, rightDim] {
      dim.backgroundColor = dimColor
      if dimOuterArea {
        layer?.addSublayer(dim)
      }
    }

    borderLayer.fillColor = nil
    borderLayer.strokeColor = ReframedColors.primaryNS.cgColor
    borderLayer.lineWidth = 2
    layer?.addSublayer(borderLayer)

    layoutLayers()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError()
  }

  func updateCaptureRect(_ rect: CGRect) {
    captureRect = rect
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layoutLayers()
    CATransaction.commit()
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layoutLayers()
    CATransaction.commit()
  }

  private func layoutLayers() {
    let b = bounds
    let r = captureRect

    topDim.frame = CGRect(x: 0, y: r.maxY, width: b.width, height: b.height - r.maxY)
    bottomDim.frame = CGRect(x: 0, y: 0, width: b.width, height: r.minY)
    leftDim.frame = CGRect(x: 0, y: r.minY, width: r.minX, height: r.height)
    rightDim.frame = CGRect(x: r.maxX, y: r.minY, width: b.width - r.maxX, height: r.height)

    let borderRect = r.insetBy(dx: -1, dy: -1)
    borderLayer.path = CGPath(rect: borderRect, transform: nil)
  }
}
