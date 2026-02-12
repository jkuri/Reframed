import AppKit
import SwiftUI

@MainActor
final class CaptureToolbarWindow: NSPanel {
  private let session: SessionState
  nonisolated(unsafe) private var sizeObserver: NSObjectProtocol?
  nonisolated(unsafe) private var moveObserver: NSObjectProtocol?
  private var userHasMoved = false

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
    sharingType = .none

    let toolbar = CaptureToolbar(session: session)
    let hostingView = NSHostingView(rootView: toolbar)
    hostingView.sizingOptions = [.intrinsicContentSize]
    contentView = hostingView

    let size = hostingView.fittingSize
    let origin = resolvedOrigin(for: size)
    if StateService.shared.toolbarPosition != nil {
      userHasMoved = true
    }
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

    moveObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didMoveNotification,
      object: self,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        self.userHasMoved = true
        StateService.shared.toolbarPosition = self.frame.origin
      }
    }
  }

  deinit {
    if let sizeObserver {
      NotificationCenter.default.removeObserver(sizeObserver)
    }
    if let moveObserver {
      NotificationCenter.default.removeObserver(moveObserver)
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

  private func resolvedOrigin(for size: NSSize) -> NSPoint {
    if let saved = StateService.shared.toolbarPosition {
      let rect = NSRect(origin: saved, size: size)
      for screen in NSScreen.screens {
        if screen.visibleFrame.intersects(rect) {
          return saved
        }
      }
    }
    return defaultOrigin(for: size)
  }

  private func defaultOrigin(for size: NSSize) -> NSPoint {
    guard let screen = NSScreen.main else { return .zero }
    return NSPoint(
      x: screen.frame.midX - size.width / 2,
      y: screen.frame.minY + 140
    )
  }

  private func recenterHorizontally() {
    guard let contentView else { return }
    let newSize = contentView.fittingSize
    guard newSize.width > 0, newSize.height > 0 else { return }

    let newX: CGFloat
    if userHasMoved {
      let midX = frame.origin.x + frame.width / 2
      newX = midX - newSize.width / 2
    } else {
      guard let screen = NSScreen.main else { return }
      newX = screen.frame.midX - newSize.width / 2
    }

    let newOrigin = NSPoint(x: newX, y: frame.origin.y)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.2
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      animator().setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
    }
  }
}
