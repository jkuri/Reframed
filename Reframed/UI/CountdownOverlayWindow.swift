import AppKit
import SwiftUI

struct CountdownOverlayView: View {
  let remaining: Int
  @State private var scale: CGFloat = 0.5
  @State private var opacity: Double = 0

  var body: some View {
    ZStack {
      Color.black.opacity(0.3)
        .ignoresSafeArea()

      Text("\(remaining)")
        .font(.system(size: 140, weight: .bold, design: .rounded))
        .foregroundStyle(ReframedColors.primaryText)
        .scaleEffect(scale)
        .opacity(opacity)
    }
    .onAppear {
      withAnimation(.easeOut(duration: 0.3)) {
        scale = 1.0
        opacity = 1.0
      }
    }
    .onChange(of: remaining) {
      scale = 0.5
      opacity = 0
      withAnimation(.easeOut(duration: 0.3)) {
        scale = 1.0
        opacity = 1.0
      }
    }
  }
}

@MainActor
final class CountdownOverlayWindow: NSPanel {
  init(screen: NSScreen, remaining: Int) {
    super.init(
      contentRect: screen.frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    level = .screenSaver
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    hasShadow = false
    hidesOnDeactivate = false
    ignoresMouseEvents = true
    sharingType = Window.sharingType

    updateCountdown(remaining)
    setFrame(screen.frame, display: true)
  }

  func updateCountdown(_ remaining: Int) {
    let view = CountdownOverlayView(remaining: remaining)
    let hostingView = NSHostingView(rootView: view)
    hostingView.sizingOptions = [.minSize, .maxSize]
    contentView = hostingView
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}
