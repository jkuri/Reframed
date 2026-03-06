import AppKit
import ScreenCaptureKit
import SwiftUI

struct WindowSelectionView: View {
  let session: SessionState
  let screen: NSScreen
  @ObservedObject var windowController: WindowController
  @State private var showingResize = false
  @State private var triggerStart = false

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
          context.fill(Path(fullRect), with: .color(ReframedColors.overlayDimBackground))

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
            }

            Text(current.appName)
              .font(.system(size: FontSize.xs, weight: .medium))
              .foregroundStyle(Color.black)

            if !current.title.isEmpty && current.title != current.appName {
              Text(current.title)
                .font(.system(size: FontSize.xs))
                .foregroundStyle(Color.black.opacity(0.6))
                .lineLimit(1)
            }

            HStack(spacing: 8) {
              Text("\(Int(current.frame.width)) \u{00d7} \(Int(current.frame.height))")
                .font(.system(size: FontSize.xs))
                .foregroundStyle(Color.black.opacity(0.6))

              Button("Resize") { showingResize.toggle() }
                .buttonStyle(SecondaryButtonStyle(size: .small, forceLightMode: true))
                .popover(isPresented: $showingResize, arrowEdge: .bottom) {
                  ResizePopover(windowController: windowController, window: current)
                }
            }

            StartRecordingButton(
              delay: session.options.timerDelay.rawValue,
              onCountdownStart: { session.hideToolbar() },
              onCancel: { session.cancelSelection() },
              action: {
                Task {
                  await windowController.updateSCWindows()
                  if let scWindow = windowController.scWindows.first(where: {
                    $0.windowID == CGWindowID(current.id)
                  }) {
                    session.confirmWindowSelection(scWindow)
                  }
                }
              },
              trigger: $triggerStart
            )

            Text("Tab to cycle windows · Esc to cancel · Enter to start")
              .font(.system(size: FontSize.xxs))
              .foregroundStyle(Color.black.opacity(0.35))
          }
          .padding(24)
          .background(ReframedColors.overlayCardBackground)
          .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
          .shadow(radius: 20)
          .position(x: localFrame.midX, y: localFrame.midY)
        } else {
          VStack(spacing: 8) {
            Text("Hover over a window to select it")
              .font(.system(size: FontSize.sm, weight: .medium))
              .foregroundStyle(Color.black)
            Text("Tab to cycle · Esc to cancel")
              .font(.system(size: FontSize.xxs))
              .foregroundStyle(Color.black.opacity(0.35))
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 14)
          .background(ReframedColors.overlayCardBackground)
          .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
          .shadow(radius: 20)
        }

        Button("") {
          session.cancelSelection()
        }
        .keyboardShortcut(.escape, modifiers: [])
        .opacity(0)
        .frame(width: 0, height: 0)

        Button("") {
          windowController.cycleToNextWindow()
        }
        .keyboardShortcut(.tab, modifiers: [])
        .opacity(0)
        .frame(width: 0, height: 0)

        Button("") {
          windowController.cycleToPreviousWindow()
        }
        .keyboardShortcut(.tab, modifiers: .shift)
        .opacity(0)
        .frame(width: 0, height: 0)

        Button("") { triggerStart = true }
          .keyboardShortcut(.return, modifiers: [])
          .opacity(0)
          .frame(width: 0, height: 0)
      }
    }
  }
}
