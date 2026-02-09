import AppKit

@MainActor
final class SelectionCoordinator {
  private var overlayWindow: SelectionOverlayWindow?

  func beginSelection(completion: @escaping (SelectionRect?) -> Void) {
    let window = SelectionOverlayWindow { rect in
      completion(rect)
    }

    overlayWindow = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func dismiss() {
    overlayWindow?.orderOut(nil)
    overlayWindow = nil
  }
}
