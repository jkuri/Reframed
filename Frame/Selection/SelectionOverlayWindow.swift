import AppKit

@MainActor
final class SelectionOverlayWindow: NSWindow {
  var onComplete: ((SelectionRect?) -> Void)?

  init(onComplete: @escaping (SelectionRect?) -> Void) {
    self.onComplete = onComplete

    let unionRect = NSScreen.unionFrame

    super.init(
      contentRect: unionRect,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    level = .screenSaver
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    ignoresMouseEvents = false
    acceptsMouseMovedEvents = true
    hasShadow = false

    let overlayView = SelectionOverlayView(frame: unionRect)
    overlayView.onComplete = { [weak self] rect in
      self?.onComplete?(rect)
    }
    contentView = overlayView
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
