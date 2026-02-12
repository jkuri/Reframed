import AppKit

@MainActor
final class MouseClickMonitor {
  private var monitor: Any?

  func start() {
    guard monitor == nil else { return }
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
      MainActor.assumeIsolated {
        self?.handleClick(event)
      }
    }
  }

  func stop() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
    monitor = nil
  }

  private func handleClick(_ event: NSEvent) {
    let screenPoint = NSEvent.mouseLocation
    _ = MouseClickWindow(at: screenPoint)
  }
}
