import AppKit

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

    let view = RecordingDimView(frame: CGRect(origin: .zero, size: screen.frame.size))
    view.captureRect = localCaptureRect
    contentView = view
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private final class RecordingDimView: NSView {
  var captureRect: CGRect = .zero

  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }

    context.saveGState()
    context.setFillColor(ReframedColors.overlayBackground.cgColor)
    context.addRect(bounds)
    context.addRect(captureRect)
    context.fillPath(using: .evenOdd)
    context.restoreGState()

    context.setStrokeColor(NSColor.controlAccentColor.cgColor)
    context.setLineWidth(2)
    context.stroke(captureRect.insetBy(dx: -1, dy: -1))
  }
}
