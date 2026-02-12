import AppKit

@MainActor
final class MouseClickMonitor {
  private var monitor: Any?
  private let color: NSColor
  private let size: CGFloat
  private let renderer: MouseClickRenderer?

  init(color: NSColor, size: CGFloat, renderer: MouseClickRenderer? = nil) {
    self.color = color
    self.size = size
    self.renderer = renderer
  }

  func start() {
    guard monitor == nil else { return }
    let clickColor = color
    let clickSize = size
    let clickRenderer = renderer
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
      MainActor.assumeIsolated {
        let screenPoint = NSEvent.mouseLocation
        clickRenderer?.recordClick(at: screenPoint)
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
