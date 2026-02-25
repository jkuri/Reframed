import AppKit

@MainActor
final class SelectionCoordinator {
  private var overlayWindows: [SelectionOverlayWindow] = []
  private var borderWindow: RecordingBorderWindow?

  func beginSelection(session: SessionState) {
    for screen in NSScreen.screens {
      let window = SelectionOverlayWindow(screen: screen, session: session)
      overlayWindows.append(window)
      window.orderFrontRegardless()
    }
    overlayWindows.first?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func restoreSelection(_ globalRect: CGRect, displayID: CGDirectDisplayID, session: SessionState) {
    guard let screen = NSScreen.screen(for: displayID) else { return }
    guard
      let window = overlayWindows.first(where: {
        $0.frame.contains(screen.frame.origin)
      })
    else { return }
    guard let overlayView = window.contentView as? SelectionOverlayView else { return }

    let localRect = CGRect(
      x: globalRect.origin.x - screen.frame.origin.x,
      y: globalRect.origin.y - screen.frame.origin.y,
      width: globalRect.width,
      height: globalRect.height
    )
    overlayView.applyExternalRect(localRect)
    session.overlayView = overlayView
  }

  func showRecordingBorder(screenRect: CGRect) {
    destroyOverlay()
    let window = RecordingBorderWindow(screenRect: screenRect)
    borderWindow = window
    window.orderFrontRegardless()
  }

  func updateRecordingBorder(screenRect: CGRect) {
    borderWindow?.updateCaptureRect(screenRect: screenRect)
  }

  func destroyOverlay() {
    for window in overlayWindows {
      window.orderOut(nil)
      window.contentView = nil
    }
    overlayWindows.removeAll()
  }

  func destroyAll() {
    destroyOverlay()
    borderWindow?.orderOut(nil)
    borderWindow = nil
  }
}
