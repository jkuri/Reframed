import SwiftUI

@main
struct FrameApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  init() {
    LogBootstrap.configure()
  }

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
