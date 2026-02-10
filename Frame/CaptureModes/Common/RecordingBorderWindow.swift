import AppKit

@MainActor
final class RecordingBorderWindow: NSWindow {
  init(screenRect: CGRect) {
    let padding: CGFloat = 2
    let frameRect = screenRect.insetBy(dx: -padding, dy: -padding)

    super.init(
      contentRect: frameRect,
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

    let borderView = RecordingBorderView(frame: CGRect(origin: .zero, size: frameRect.size))
    contentView = borderView
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private final class RecordingBorderView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.setStrokeColor(NSColor.controlAccentColor.cgColor)
    context.setLineWidth(2)
    context.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
  }
}
