import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  let session = SessionState()
  private var statusItem: NSStatusItem!
  private var popover: NSPopover?
  private var permissionsWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    setupStatusItem()
    session.onBecomeIdle = { [weak self] in
      self?.dismissPopover()
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
    if session.state == .idle {
      if Permissions.allPermissionsGranted {
        session.toggleToolbar()
      } else {
        showPermissionsWindow()
      }
    } else {
      togglePopover()
    }
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
    window.backgroundColor = NSColor(FrameColors.panelBackground)
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

  private func dismissPermissionsWindow() {
    permissionsWindow?.close()
    permissionsWindow = nil
  }

  private func togglePopover() {
    if let popover, popover.isShown {
      dismissPopover()
      return
    }
    let pop = NSPopover()
    pop.behavior = .transient
    pop.contentViewController = NSHostingController(
      rootView: MenuBarView(session: session)
    )
    self.popover = pop
    if let button = statusItem.button {
      pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }

  private func dismissPopover() {
    popover?.performClose(nil)
    popover = nil
  }
}
