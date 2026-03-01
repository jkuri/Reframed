import AppKit
import SwiftUI

struct StartRecordingOverlayView: View {
  let screen: NSScreen
  let delay: Int
  var onCountdownStart: ((NSScreen) -> Void)?
  let onCancel: () -> Void
  let onStart: (NSScreen) -> Void

  private func resolution(for screen: NSScreen) -> String {
    let width = Int(screen.frame.width * screen.backingScaleFactor)
    let height = Int(screen.frame.height * screen.backingScaleFactor)
    return "\(width) \u{00d7} \(height)"
  }

  var body: some View {
    ZStack {
      ReframedColors.overlayDimBackground
        .edgesIgnoringSafeArea(.all)

      VStack(spacing: 12) {
        Text(screen.localizedName)
          .font(.system(size: FontSize.xs, weight: .medium))
          .foregroundStyle(Color.black)

        Text(resolution(for: screen))
          .font(.system(size: FontSize.xs))
          .foregroundStyle(Color.black.opacity(0.6))

        StartRecordingButton(
          delay: delay,
          onCountdownStart: { onCountdownStart?(screen) },
          onCancel: { onCancel() },
          action: { onStart(screen) }
        )
      }
      .padding(24)
      .background(ReframedColors.overlayCardBackground)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(radius: 20)

      Button("") { onCancel() }
        .keyboardShortcut(.escape, modifiers: [])
        .opacity(0)
        .frame(width: 0, height: 0)
    }
  }
}

@MainActor
final class StartRecordingWindow: NSPanel {
  init(
    screen: NSScreen,
    delay: Int,
    onCountdownStart: @escaping @MainActor (NSScreen) -> Void,
    onCancel: @escaping @MainActor () -> Void,
    onStart: @escaping @MainActor (NSScreen) -> Void
  ) {
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
    hasShadow = true
    hidesOnDeactivate = false
    ignoresMouseEvents = false
    acceptsMouseMovedEvents = true

    let view = StartRecordingOverlayView(
      screen: screen,
      delay: delay,
      onCountdownStart: onCountdownStart,
      onCancel: onCancel,
      onStart: onStart
    )
    let hostingView = NSHostingView(rootView: view)
    hostingView.sizingOptions = [.minSize, .maxSize]
    contentView = hostingView

    setFrame(screen.frame, display: true)
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .mouseMoved, !isKeyWindow {
      makeKey()
    }
    super.sendEvent(event)
  }
}
