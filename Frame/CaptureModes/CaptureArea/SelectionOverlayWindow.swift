import AppKit

@MainActor
final class SelectionOverlayWindow: NSWindow {
  init(session: SessionState) {
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
    sharingType = .none

    let overlayView = SelectionOverlayView(frame: unionRect, session: session)
    session.overlayView = overlayView
    contentView = overlayView
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
