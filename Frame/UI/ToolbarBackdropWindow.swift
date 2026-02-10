import AppKit

@MainActor
final class ToolbarBackdropWindow: NSWindow {
  init(onDismiss: @escaping @MainActor () -> Void) {
    let frame = NSScreen.unionFrame

    super.init(
      contentRect: frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    level = .screenSaver
    hasShadow = false
    ignoresMouseEvents = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    hidesOnDeactivate = false

    let backdrop = ToolbarBackdropView(frame: frame)
    backdrop.onClick = onDismiss
    contentView = backdrop
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

private final class ToolbarBackdropView: NSView {
  var onClick: (() -> Void)?

  override func draw(_ dirtyRect: NSRect) {
    NSColor(white: 0, alpha: 0.001).setFill()
    dirtyRect.fill()
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func mouseDown(with event: NSEvent) {
    onClick?()
  }
}
