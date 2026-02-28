import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  let session = SessionState()
  private var permissionsWindow: NSWindow?
  private var shortcutManager: KeyboardShortcutManager?

  func applicationDidFinishLaunching(_ notification: Notification) {
    ConfigService.shared.applyAppearance()

    let manager = KeyboardShortcutManager(session: session)
    manager.start()
    shortcutManager = manager

    if !Permissions.allPermissionsGranted {
      showPermissionsWindow()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if Permissions.allPermissionsGranted {
      session.showToolbar()
    } else {
      showPermissionsWindow()
    }
    return false
  }

  func showPermissionsWindow() {
    if let permissionsWindow, permissionsWindow.isVisible {
      permissionsWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 500),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.backgroundColor = ReframedColors.backgroundNS
    window.center()

    window.collectionBehavior.insert(.moveToActiveSpace)

    window.delegate = self
    window.contentViewController = NSHostingController(
      rootView: PermissionsView { [weak self] in
        MainActor.assumeIsolated {
          self?.dismissPermissionsWindow()
        }
      }
    )

    let min = NSSize(width: 800, height: 500)
    window.contentMinSize = min
    window.minSize = min

    permissionsWindow = window
    window.level = .floating
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    DispatchQueue.main.async {
      window.level = .normal
    }
  }

  func windowWillClose(_ notification: Notification) {
    if (notification.object as? NSWindow) === permissionsWindow {
      permissionsWindow = nil
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.pathExtension == "frm" {
      session.openProject(at: url)
    }
  }

  private func dismissPermissionsWindow() {
    permissionsWindow?.close()
    permissionsWindow = nil
  }
}
