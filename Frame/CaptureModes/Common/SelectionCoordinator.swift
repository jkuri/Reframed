import AppKit

@MainActor
final class SelectionCoordinator {
  private var overlayWindow: SelectionOverlayWindow?
  private var borderWindow: RecordingBorderWindow?

  func beginSelection(session: SessionState) {
    let window = SelectionOverlayWindow(session: session)
    overlayWindow = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func showRecordingBorder(screenRect: CGRect) {
    destroyOverlay()
    let window = RecordingBorderWindow(screenRect: screenRect)
    borderWindow = window
    window.orderFrontRegardless()
  }

  func destroyOverlay() {
    overlayWindow?.orderOut(nil)
    overlayWindow?.contentView = nil
    overlayWindow = nil
  }

  func destroyAll() {
    destroyOverlay()
    borderWindow?.orderOut(nil)
    borderWindow = nil
  }
}
