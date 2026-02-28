import AppKit
import ScreenCaptureKit
import SwiftUI

struct WindowSelectionView: View {
  let session: SessionState
  let screen: NSScreen
  @ObservedObject var windowController: WindowController
  @State private var showingResize = false

  private func toLocal(_ rect: CGRect) -> CGRect {
    let screenBounds = CGDisplayBounds(screen.displayID)
    return CGRect(
      x: rect.origin.x - screenBounds.origin.x,
      y: rect.origin.y - screenBounds.origin.y,
      width: rect.width,
      height: rect.height
    )
  }

  private var currentWindowOnThisScreen: WindowInfo? {
    guard let current = windowController.currentWindow else { return nil }
    let screenBounds = CGDisplayBounds(screen.displayID)
    let mid = CGPoint(x: current.frame.midX, y: current.frame.midY)
    guard mid.x >= screenBounds.origin.x,
      mid.x < screenBounds.origin.x + screenBounds.width,
      mid.y >= screenBounds.origin.y,
      mid.y < screenBounds.origin.y + screenBounds.height
    else { return nil }
    return current
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Canvas { context, size in
          let fullRect = CGRect(origin: .zero, size: size)
          context.fill(Path(fullRect), with: .color(.black.opacity(0.55)))

          guard let window = currentWindowOnThisScreen else { return }

          let targetRect = toLocal(window.frame)
          let cornerRadius: CGFloat = 10.0
          let targetPath = Path(roundedRect: targetRect, cornerRadius: cornerRadius)

          context.blendMode = .destinationOut
          context.fill(targetPath, with: .color(.black))
          context.blendMode = .normal

          context.fill(targetPath, with: .color(.white.opacity(0.55)))
          context.stroke(targetPath, with: .color(.white), lineWidth: 2)
        }
        .edgesIgnoringSafeArea(.all)

        if let current = currentWindowOnThisScreen {
          let localFrame = toLocal(current.frame)

          VStack(spacing: 12) {
            if let app = NSRunningApplication(processIdentifier: current.appPID),
              let icon = app.icon
            {
              Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            }

            Text(current.appName)
              .font(.title2.bold())
              .foregroundStyle(Color.black)
              .shadow(color: .white.opacity(0.3), radius: 4)

            HStack(spacing: 8) {
              Text("\(Int(current.frame.width)) \u{00d7} \(Int(current.frame.height))")
                .font(.system(size: 15))
                .foregroundStyle(Color.black)
                .shadow(color: .white.opacity(0.3), radius: 4)

              Button("Resize") { showingResize.toggle() }
                .buttonStyle(PrimaryButtonStyle(size: .small, forceLightMode: true))
                .popover(isPresented: $showingResize, arrowEdge: .bottom) {
                  ResizePopover(windowController: windowController, window: current)
                }
            }

            StartRecordingButton(
              delay: session.options.timerDelay.rawValue,
              onCountdownStart: { session.hideToolbar() },
              onCancel: { session.cancelSelection() }
            ) {
              Task {
                await windowController.updateSCWindows()
                if let scWindow = windowController.scWindows.first(where: {
                  $0.windowID == CGWindowID(current.id)
                }) {
                  session.confirmWindowSelection(scWindow)
                }
              }
            }
          }
          .position(x: localFrame.midX, y: localFrame.midY)
        }

        Button("") {
          session.cancelSelection()
        }
        .keyboardShortcut(.escape, modifiers: [])
        .opacity(0)
        .frame(width: 0, height: 0)
      }
    }
  }
}
