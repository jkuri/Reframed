import AppKit
import SwiftUI

@MainActor
final class CaptureToolbarWindow: NSPanel {
  private let session: SessionState
  nonisolated(unsafe) private var sizeObserver: NSObjectProtocol?

  init(session: SessionState, onDismiss: @escaping @MainActor () -> Void) {
    self.session = session

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
    hostingView.sizingOptions = [.intrinsicContentSize]
    contentView = hostingView

    let size = hostingView.fittingSize
    guard let screen = NSScreen.main else { return }
    let origin = NSPoint(
      x: screen.frame.midX - size.width / 2,
      y: screen.frame.minY + 140
    )
    setFrame(NSRect(origin: origin, size: size), display: true)

    hostingView.postsFrameChangedNotifications = true
    sizeObserver = NotificationCenter.default.addObserver(
      forName: NSView.frameDidChangeNotification,
      object: hostingView,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.recenterHorizontally()
      }
    }
  }

  deinit {
    if let sizeObserver {
      NotificationCenter.default.removeObserver(sizeObserver)
    }
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func keyDown(with event: NSEvent) {
    guard event.keyCode == 53 else {
      super.keyDown(with: event)
      return
    }

    switch session.state {
    case .recording, .paused, .processing:
      return
    case .countdown:
      session.cancelCountdown()
    case .selecting:
      session.cancelSelection()
    default:
      if session.captureMode != .none {
        session.selectMode(.none)
      } else {
        session.hideToolbar()
      }
    }
  }

  private func recenterHorizontally() {
    guard let screen = NSScreen.main, let contentView else { return }
    let newSize = contentView.fittingSize
    guard newSize.width > 0, newSize.height > 0 else { return }
    let newOrigin = NSPoint(
      x: screen.frame.midX - newSize.width / 2,
      y: frame.origin.y
    )
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      animator().setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }
  }
}
