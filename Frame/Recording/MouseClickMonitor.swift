import AppKit

@MainActor
final class MouseClickMonitor {
  private var monitor: Any?
  private let color: NSColor
  private let size: CGFloat

  init(color: NSColor, size: CGFloat) {
    self.color = color
    self.size = size
  }

  func start() {
    guard monitor == nil else { return }
    let clickColor = color
    let clickSize = size
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
      MainActor.assumeIsolated {
        self?.handleClick(event, color: clickColor, size: clickSize)
      }
    }
  }

  func stop() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
    monitor = nil
  }

  private func handleClick(_ event: NSEvent, color: NSColor, size: CGFloat) {
    let screenPoint = NSEvent.mouseLocation
    _ = MouseClickWindow(at: screenPoint, color: color, size: size)
  }
}
