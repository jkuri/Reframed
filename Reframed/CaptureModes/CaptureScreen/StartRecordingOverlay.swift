import AppKit
import SwiftUI

struct StartRecordingOverlayView: View {
  let screen: NSScreen
  let delay: Int
  let screenIndex: Int
  let totalScreens: Int
  var onCountdownStart: ((NSScreen) -> Void)?
  let onCancel: () -> Void
  let onStart: (NSScreen) -> Void
  @State private var triggerStart = false

  private func resolution(for screen: NSScreen) -> String {
    let width = Int(screen.frame.width * screen.backingScaleFactor)
    let height = Int(screen.frame.height * screen.backingScaleFactor)
    return "\(width) \u{00d7} \(height)"
  }

  private func refreshRate(for screen: NSScreen) -> String? {
    guard let mode = CGDisplayCopyDisplayMode(screen.displayID) else { return nil }
    let hz = Int(mode.refreshRate)
    guard hz > 0 else { return nil }
    return "\(hz) Hz"
  }

  private var isPrimary: Bool {
    screen.displayID == CGMainDisplayID()
  }

  var body: some View {
    ZStack {
      ReframedColors.overlayDimBackground
        .edgesIgnoringSafeArea(.all)

      VStack(spacing: 12) {
        if totalScreens > 1 {
          Text("Display \(screenIndex)")
            .font(.system(size: FontSize.xxl, weight: .bold, design: .rounded))
            .foregroundStyle(Color.black)
        }

        Text(screen.localizedName)
          .font(.system(size: FontSize.xs, weight: .medium))
          .foregroundStyle(Color.black)

        HStack(spacing: 8) {
          Text(resolution(for: screen))
            .font(.system(size: FontSize.xs))
            .foregroundStyle(Color.black.opacity(0.6))

          if let hz = refreshRate(for: screen) {
            Text("·")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(Color.black.opacity(0.4))
            Text(hz)
              .font(.system(size: FontSize.xs))
              .foregroundStyle(Color.black.opacity(0.6))
          }

          if isPrimary && totalScreens > 1 {
            Text("·")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(Color.black.opacity(0.4))
            Text("Primary")
              .font(.system(size: FontSize.xxs, weight: .medium))
              .foregroundStyle(Color.black.opacity(0.5))
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.black.opacity(0.08))
              .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
          }
        }

        StartRecordingButton(
          delay: delay,
          onCountdownStart: { onCountdownStart?(screen) },
          onCancel: { onCancel() },
          action: { onStart(screen) },
          trigger: $triggerStart
        )

        Text("Press Esc to cancel · Enter to start")
          .font(.system(size: FontSize.xxs))
          .foregroundStyle(Color.black.opacity(0.35))
      }
      .padding(24)
      .background(ReframedColors.overlayCardBackground)
      .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
      .shadow(radius: 20)

      Button("") { onCancel() }
        .keyboardShortcut(.escape, modifiers: [])
        .opacity(0)
        .frame(width: 0, height: 0)

      Button("") { triggerStart = true }
        .keyboardShortcut(.return, modifiers: [])
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
    screenIndex: Int,
    totalScreens: Int,
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
    appearance = NSAppearance(named: .aqua)
    hasShadow = true
    hidesOnDeactivate = false
    ignoresMouseEvents = false
    acceptsMouseMovedEvents = true

    let view = StartRecordingOverlayView(
      screen: screen,
      delay: delay,
      screenIndex: screenIndex,
      totalScreens: totalScreens,
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
