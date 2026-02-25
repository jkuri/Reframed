import AppKit
import SwiftUI

@MainActor
final class WindowSelectionOverlay: NSWindow {
  init(screen: NSScreen, session: SessionState, windowController: WindowController) {
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

    let view = WindowSelectionView(
      session: session,
      screen: screen,
      windowController: windowController
    )
    let hostingView = NSHostingView(rootView: view)
    contentView = hostingView

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
