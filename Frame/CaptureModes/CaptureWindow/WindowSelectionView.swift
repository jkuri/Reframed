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

          context.fill(targetPath, with: .color(Color(nsColor: .controlAccentColor).opacity(0.7)))
          context.stroke(targetPath, with: .color(Color(nsColor: .controlAccentColor)), lineWidth: 2)
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
              .foregroundStyle(.white)
              .shadow(color: .black.opacity(0.3), radius: 4)

            HStack(spacing: 8) {
              Text("\(Int(current.frame.width)) \u{00d7} \(Int(current.frame.height))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))

              Button {
                showingResize.toggle()
              } label: {
                Text("Resize")
                  .font(.system(size: 13))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 4)
                  .background(Color.white.opacity(0.15))
                  .clipShape(RoundedRectangle(cornerRadius: 5))
              }
              .buttonStyle(.plain)
              .popover(isPresented: $showingResize, arrowEdge: .bottom) {
                ResizePopover(windowController: windowController, window: current)
              }
            }

            StartRecordingButton {
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

private struct ResizePopover: View {
  let windowController: WindowController
  let window: WindowInfo

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: "Common")

      ResizeRow(label: "1280 \u{00d7} 720") { windowController.resize(window, to: CGSize(width: 1280, height: 720)) }
      ResizeRow(label: "1920 \u{00d7} 1080") { windowController.resize(window, to: CGSize(width: 1920, height: 1080)) }
      ResizeRow(label: "2560 \u{00d7} 1440") { windowController.resize(window, to: CGSize(width: 2560, height: 1440)) }

      Divider().background(FrameColors.divider).padding(.vertical, 4)

      SectionHeader(title: "4:3")

      ResizeRow(label: "640 \u{00d7} 480") { windowController.resize(window, to: CGSize(width: 640, height: 480)) }
      ResizeRow(label: "800 \u{00d7} 600") { windowController.resize(window, to: CGSize(width: 800, height: 600)) }
      ResizeRow(label: "1024 \u{00d7} 768") { windowController.resize(window, to: CGSize(width: 1024, height: 768)) }
      ResizeRow(label: "1280 \u{00d7} 960") { windowController.resize(window, to: CGSize(width: 1280, height: 960)) }
      ResizeRow(label: "1600 \u{00d7} 1200") { windowController.resize(window, to: CGSize(width: 1600, height: 1200)) }

      Divider().background(FrameColors.divider).padding(.vertical, 4)

      SectionHeader(title: "16:9")

      ResizeRow(label: "854 \u{00d7} 480") { windowController.resize(window, to: CGSize(width: 854, height: 480)) }
      ResizeRow(label: "1280 \u{00d7} 720") { windowController.resize(window, to: CGSize(width: 1280, height: 720)) }
      ResizeRow(label: "1920 \u{00d7} 1080") { windowController.resize(window, to: CGSize(width: 1920, height: 1080)) }
      ResizeRow(label: "2560 \u{00d7} 1440") { windowController.resize(window, to: CGSize(width: 2560, height: 1440)) }
      ResizeRow(label: "3840 \u{00d7} 2160") { windowController.resize(window, to: CGSize(width: 3840, height: 2160)) }

      Divider().background(FrameColors.divider).padding(.vertical, 4)

      SectionHeader(title: "16:10")

      ResizeRow(label: "640 \u{00d7} 400") { windowController.resize(window, to: CGSize(width: 640, height: 400)) }
      ResizeRow(label: "1280 \u{00d7} 800") { windowController.resize(window, to: CGSize(width: 1280, height: 800)) }
      ResizeRow(label: "1440 \u{00d7} 900") { windowController.resize(window, to: CGSize(width: 1440, height: 900)) }
      ResizeRow(label: "1680 \u{00d7} 1050") { windowController.resize(window, to: CGSize(width: 1680, height: 1050)) }
      ResizeRow(label: "1920 \u{00d7} 1200") { windowController.resize(window, to: CGSize(width: 1920, height: 1200)) }
      ResizeRow(label: "2560 \u{00d7} 1600") { windowController.resize(window, to: CGSize(width: 2560, height: 1600)) }

      Divider().background(FrameColors.divider).padding(.vertical, 4)

      SectionHeader(title: "9:16")

      ResizeRow(label: "360 \u{00d7} 640") { windowController.resize(window, to: CGSize(width: 360, height: 640)) }
      ResizeRow(label: "720 \u{00d7} 1280") { windowController.resize(window, to: CGSize(width: 720, height: 1280)) }
      ResizeRow(label: "1080 \u{00d7} 1920") { windowController.resize(window, to: CGSize(width: 1080, height: 1920)) }

      Divider().background(FrameColors.divider).padding(.vertical, 4)

      SectionHeader(title: "Square")

      ResizeRow(label: "480 \u{00d7} 480") { windowController.resize(window, to: CGSize(width: 480, height: 480)) }
      ResizeRow(label: "640 \u{00d7} 640") { windowController.resize(window, to: CGSize(width: 640, height: 640)) }
      ResizeRow(label: "720 \u{00d7} 720") { windowController.resize(window, to: CGSize(width: 720, height: 720)) }
      ResizeRow(label: "1080 \u{00d7} 1080") { windowController.resize(window, to: CGSize(width: 1080, height: 1080)) }
      ResizeRow(label: "1440 \u{00d7} 1440") { windowController.resize(window, to: CGSize(width: 1440, height: 1440)) }
    }
    .padding(.vertical, 8)
    .frame(width: 200)
    .background(FrameColors.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(FrameColors.subtleBorder, lineWidth: 0.5)
    )
  }
}

private struct ResizeRow: View {
  let label: String
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack {
        Text(label)
          .font(.system(size: 13))
        Spacer()
      }
      .foregroundStyle(FrameColors.primaryText)
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      RoundedRectangle(cornerRadius: 4)
        .fill(isHovered ? FrameColors.hoverBackground : Color.clear)
        .padding(.horizontal, 4)
    )
    .onHover { isHovered = $0 }
  }
}
