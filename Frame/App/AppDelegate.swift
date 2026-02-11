import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  let session = SessionState()
  private var statusItem: NSStatusItem!
  private var permissionsWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    ConfigService.shared.applyAppearance()
    setupStatusItem()
    if Permissions.allPermissionsGranted {
      session.showToolbar()
    }
  }

  private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    guard let button = statusItem.button else { return }
    button.image = NSImage(systemSymbolName: "rectangle.dashed.badge.record", accessibilityDescription: "Frame")
    button.action = #selector(statusItemClicked)
    button.target = self
    session.statusItemButton = button
  }

  @objc private func statusItemClicked() {
    if Permissions.allPermissionsGranted {
      session.toggleToolbar()
    } else {
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

  private func showPermissionsWindow() {
    if let permissionsWindow, permissionsWindow.isVisible {
      permissionsWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.backgroundColor = FrameColors.panelBackgroundNS
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

    let min = NSSize(width: 800, height: 400)
    window.contentMinSize = min
    window.minSize = min

    permissionsWindow = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
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
