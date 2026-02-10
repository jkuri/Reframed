import AppKit
import SwiftUI

@MainActor
final class CaptureToolbarWindow: NSPanel {
  private let onDismiss: () -> Void

  init(session: SessionState, onDismiss: @escaping @MainActor () -> Void) {
    self.onDismiss = onDismiss

    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    level = .screenSaver
    hasShadow = true
    isMovableByWindowBackground = true
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    hidesOnDeactivate = false

    let toolbar = CaptureToolbar(session: session)
    let hostingView = NSHostingView(rootView: toolbar)
    let size = hostingView.fittingSize
    contentView = hostingView

    guard let screen = NSScreen.main else { return }
    let origin = NSPoint(
      x: screen.frame.midX - size.width / 2,
      y: screen.frame.minY + 140
    )
    setFrame(NSRect(origin: origin, size: size), display: true)
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      onDismiss()
      return
    }
    super.keyDown(with: event)
  }
}
