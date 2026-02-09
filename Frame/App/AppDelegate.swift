import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Ensure the app doesn't show in the Dock
    NSApp.setActivationPolicy(.accessory)
  }
}
