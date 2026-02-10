import AppKit
import SwiftUI

struct StartRecordingOverlayView: View {
  let displayName: String
  let onStart: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      Text(displayName)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.white)

      Button(action: onStart) {
        HStack(spacing: 6) {
          Image(systemName: "record.circle")
            .font(.system(size: 15, weight: .semibold))
          Text("Start recording")
            .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .frame(height: 48)
        .background(Color(nsColor: .controlAccentColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)
    }
  }
}

@MainActor
final class StartRecordingWindow: NSPanel {
  init(onStart: @escaping @MainActor () -> Void) {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    isOpaque = false
    backgroundColor = .clear
    level = .screenSaver
    hasShadow = true
    hidesOnDeactivate = false
    ignoresMouseEvents = false

    let displayName = NSScreen.main?.localizedName ?? "Display"
    let view = StartRecordingOverlayView(displayName: displayName, onStart: onStart)
    let hostingView = NSHostingView(rootView: view)
    let size = hostingView.fittingSize
    contentView = hostingView

    guard let screen = NSScreen.main else { return }
    let origin = NSPoint(
      x: screen.frame.midX - size.width / 2,
      y: screen.frame.midY - size.height / 2
    )
    setFrame(NSRect(origin: origin, size: size), display: true)
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}
