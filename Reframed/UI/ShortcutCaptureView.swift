import AppKit
import SwiftUI

struct ShortcutCaptureView: NSViewRepresentable {
  var onCapture: (KeyboardShortcut) -> Void
  var onCancel: () -> Void

  func makeNSView(context: Context) -> ShortcutCaptureNSView {
    let view = ShortcutCaptureNSView()
    view.onCapture = onCapture
    view.onCancel = onCancel
    return view
  }

  func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {}
}

final class ShortcutCaptureNSView: NSView {
  var onCapture: ((KeyboardShortcut) -> Void)?
  var onCancel: (() -> Void)?
  nonisolated(unsafe) private var monitor: Any?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil {
      startMonitoring()
    } else {
      stopMonitoring()
    }
  }

  private func startMonitoring() {
    guard monitor == nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self else { return event }

      if event.keyCode == 53 {
        self.onCancel?()
        return nil
      }

      let mask: NSEvent.ModifierFlags = [.command, .control, .option]
      let mods = event.modifierFlags.intersection(mask)
      guard !mods.isEmpty else { return nil }

      let allMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
      let flags = event.modifierFlags.intersection(allMask).rawValue
      let shortcut = KeyboardShortcut(keyCode: event.keyCode, modifierFlags: flags)
      self.onCapture?(shortcut)
      return nil
    }
  }

  private func stopMonitoring() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
    monitor = nil
  }

  deinit {
    if let monitor {
      NSEvent.removeMonitor(monitor)
    }
  }
}
