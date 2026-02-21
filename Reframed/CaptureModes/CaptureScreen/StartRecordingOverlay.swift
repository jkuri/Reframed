import AppKit
import SwiftUI

struct StartRecordingOverlayView: View {
  let displayName: String
  let resolution: String
  let delay: Int
  var onCountdownStart: (() -> Void)?
  let onCancel: () -> Void
  let onStart: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      Text(displayName)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color.black)

      Text(resolution)
        .font(.system(size: 12))
        .foregroundStyle(Color.black.opacity(0.6))

      StartRecordingButton(
        delay: delay,
        onCountdownStart: onCountdownStart,
        onCancel: { onCancel() },
        action: onStart
      )
    }
    .padding(24)
    .background(ReframedColors.overlayCardBackground)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(radius: 20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ReframedColors.overlayDimBackground)
    .overlay {
      Button("") { onCancel() }
        .keyboardShortcut(.escape, modifiers: [])
        .opacity(0)
    }
  }
}

@MainActor
final class StartRecordingWindow: NSPanel {
  init(
    screen: NSScreen,
    delay: Int,
    onCountdownStart: @escaping @MainActor () -> Void,
    onCancel: @escaping @MainActor () -> Void,
    onStart: @escaping @MainActor () -> Void
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

    let displayName = screen.localizedName
    let width = Int(screen.frame.width * screen.backingScaleFactor)
    let height = Int(screen.frame.height * screen.backingScaleFactor)
    let resolution = "\(width) × \(height)"

    let view = StartRecordingOverlayView(
      displayName: displayName,
      resolution: resolution,
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
}
