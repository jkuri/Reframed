import MenuBarExtraAccess
import SwiftUI

@main
struct ReframedApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var isMenuPresented = false

  init() {
    LogBootstrap.configure()
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(
        session: appDelegate.session,
        onDismiss: { isMenuPresented = false },
        onShowPermissions: { appDelegate.showPermissionsWindow() }
      )
      .presentationBackground(ReframedColors.backgroundPopover)
    } label: {
      Image(nsImage: MenuBarIcon.makeImage(for: appDelegate.session.menuBarIconState))
    }
    .menuBarExtraStyle(.window)
    .menuBarExtraAccess(isPresented: $isMenuPresented) { statusItem in
      appDelegate.session.statusItemButton = statusItem.button
    }
  }
}
