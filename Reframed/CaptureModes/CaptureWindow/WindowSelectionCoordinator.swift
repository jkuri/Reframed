import AppKit
import ScreenCaptureKit

@MainActor
final class WindowSelectionCoordinator {
  private var overlayWindows: [WindowSelectionOverlay] = []
  private var highlightWindow: RecordingBorderWindow?
  private let windowController = WindowController()
  nonisolated(unsafe) private var eventMonitor: Any?
  nonisolated(unsafe) private var refreshTimer: Timer?

  deinit {
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
    }
    refreshTimer?.invalidate()
  }

  func beginSelection(session: SessionState) {
    for screen in NSScreen.screens {
      let window = WindowSelectionOverlay(
        screen: screen,
        session: session,
        windowController: windowController
      )
      overlayWindows.append(window)
      window.orderFrontRegardless()
    }
    overlayWindows.first?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    Task { await windowController.updateSCWindows() }
    startTrackingMouse()
    startRefreshTimer()
  }

  private func startTrackingMouse() {
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
      guard let self else { return event }
      let mouseLocation = NSEvent.mouseLocation
      let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
      let flippedY = primaryScreenHeight - mouseLocation.y
      let globalLocation = CGPoint(x: mouseLocation.x, y: flippedY)
      if let found = windowController.findWindow(at: globalLocation) {
        windowController.currentWindow = found
      } else {
        windowController.currentWindow = nil
      }
      return event
    }
  }

  private func startRefreshTimer() {
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self else { return }
        await self.windowController.updateSCWindows()
      }
    }
  }

  func highlight(window: SCWindow?) {
    guard let window = window else {
      highlightWindow?.orderOut(nil)
      highlightWindow = nil
      return
    }

    let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
    let cocoaY = mainScreenHeight - CGFloat(window.frame.origin.y) - CGFloat(window.frame.height)

    let rect = CGRect(
      x: CGFloat(window.frame.origin.x),
      y: cocoaY,
      width: CGFloat(window.frame.width),
      height: CGFloat(window.frame.height)
    )

    if let highlightWindow = highlightWindow {
      highlightWindow.setFrame(rect.insetBy(dx: -2, dy: -2), display: true)
    } else {
      let hw = RecordingBorderWindow(screenRect: rect)
      hw.level = .floating
      highlightWindow = hw
      hw.orderFrontRegardless()
    }
  }

  func destroyOverlay() {
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
    refreshTimer?.invalidate()
    refreshTimer = nil

    for window in overlayWindows {
      window.orderOut(nil)
      window.contentView = nil
    }
    overlayWindows.removeAll()

    highlightWindow?.orderOut(nil)
    highlightWindow = nil
  }
}
