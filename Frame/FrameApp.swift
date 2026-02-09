import MenuBarExtraAccess
import SwiftUI

@main
struct FrameApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var isMenuPresented = false
  @State private var coordinator = CaptureCoordinator()

  init() {
    LogBootstrap.configure()
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(coordinator: coordinator, isMenuPresented: $isMenuPresented)
    } label: {
      MenuBarIconView(state: coordinator.ui.state)
    }
    .menuBarExtraStyle(.window)
    .menuBarExtraAccess(isPresented: $isMenuPresented)
    .onChange(of: isMenuPresented) { _, newValue in
      guard newValue else { return }
      let currentState = coordinator.ui.state
      switch currentState {
      case .recording, .paused:
        isMenuPresented = false
        Task {
          try? await coordinator.stopRecording()
        }
      default:
        break
      }
    }
  }
}
