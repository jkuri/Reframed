import AppKit

@MainActor
final class SelectionOverlayWindow: NSWindow {
  init(screen: NSScreen, session: SessionState) {
    super.init(
      contentRect: screen.frame,
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
    sharingType = Window.sharingType

    let localFrame = CGRect(origin: .zero, size: screen.frame.size)
    let overlayView = SelectionOverlayView(frame: localFrame, session: session)
    contentView = overlayView

    setFrame(screen.frame, display: true)
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .mouseMoved, !isKeyWindow {
      makeKey()
    }
    super.sendEvent(event)
  }
}
