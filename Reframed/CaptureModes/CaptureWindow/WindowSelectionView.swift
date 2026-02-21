import AppKit
import ScreenCaptureKit
import SwiftUI

struct WindowSelectionView: View {
  let session: SessionState
  @StateObject private var windowController = WindowController()
  @State private var eventMonitor: Any?
  @State private var refreshTimer: Timer?
  @State private var showingResize = false

  private func toLocal(_ rect: CGRect) -> CGRect {
    let unionOrigin = NSScreen.unionFrame.origin
    return CGRect(
      x: rect.origin.x - unionOrigin.x,
      y: rect.origin.y - unionOrigin.y,
      width: rect.width,
      height: rect.height
    )
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Canvas { context, size in
          let unionRect = CGRect(origin: .zero, size: size)
          context.fill(Path(unionRect), with: .color(.black.opacity(0.55)))

          guard let window = windowController.currentWindow else { return }

          let targetRect = toLocal(window.frame)
          let cornerRadius: CGFloat = 10.0
          let targetPath = Path(roundedRect: targetRect, cornerRadius: cornerRadius)

          context.blendMode = .destinationOut
          context.fill(targetPath, with: .color(.black))
          context.blendMode = .normal

          context.fill(targetPath, with: .color(.white.opacity(0.8)))
          context.stroke(targetPath, with: .color(.white), lineWidth: 2)
        }
        .edgesIgnoringSafeArea(.all)

        if let current = windowController.currentWindow {
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
                    .background(ReframedColors.background)
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
    .onAppear {
      Task { await windowController.updateSCWindows() }
      startTrackingMouse()
      startRefreshTimer()
    }
    .onDisappear {
      stopTrackingMouse()
      stopRefreshTimer()
    }
  }

  private func updateHoveredWindow(at location: CGPoint) {
    if let found = windowController.findWindow(at: location) {
      windowController.currentWindow = found
    } else {
      windowController.currentWindow = nil
    }
  }

  private func startTrackingMouse() {
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
      let mouseLocation = NSEvent.mouseLocation
      let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
      let flippedY = primaryScreenHeight - mouseLocation.y
      let globalLocation = CGPoint(x: mouseLocation.x, y: flippedY)
      updateHoveredWindow(at: globalLocation)
      return event
    }
  }

  private func stopTrackingMouse() {
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
  }

  private func startRefreshTimer() {
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
      Task { @MainActor in
        await windowController.updateSCWindows()
      }
    }
  }

  private func stopRefreshTimer() {
    refreshTimer?.invalidate()
    refreshTimer = nil
  }
}
