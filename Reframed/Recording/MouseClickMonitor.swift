import AppKit

@MainActor
final class MouseClickMonitor {
  private var monitor: Any?
  private var keystrokeMonitor: Any?
  private let metadataRecorder: CursorMetadataRecorder?

  init(metadataRecorder: CursorMetadataRecorder? = nil) {
    self.metadataRecorder = metadataRecorder
  }

  func start() {
    guard monitor == nil else { return }
    let cursorRecorder = metadataRecorder
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
      MainActor.assumeIsolated {
        let screenPoint = NSEvent.mouseLocation
        let button = event.type == .rightMouseDown ? 1 : 0
        cursorRecorder?.recordClick(at: screenPoint, button: button)
      }
    }

    if cursorRecorder != nil {
      keystrokeMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
        let isDown = event.type == .keyDown
        cursorRecorder?.recordKeystroke(keyCode: event.keyCode, modifiers: UInt(event.modifierFlags.rawValue), isDown: isDown)
      }
    }
  }

  func stop() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
    monitor = nil

    if let keystrokeMonitor {
      NSEvent.removeMonitor(keystrokeMonitor)
    }
    keystrokeMonitor = nil
  }
}
