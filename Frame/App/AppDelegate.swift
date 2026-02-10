import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let session = SessionState()
  private var statusItem: NSStatusItem!
  private var popover: NSPopover?

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
      session.toggleToolbar()
    } else {
      togglePopover()
    }
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
