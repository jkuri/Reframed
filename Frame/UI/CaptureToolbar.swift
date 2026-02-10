import SwiftUI

struct CaptureToolbar: View {
  let session: SessionState
  @State private var showOptions = false

  var body: some View {
    HStack(spacing: 0) {
      Button {
        session.hideToolbar()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 20))
          .foregroundStyle(Color.white.opacity(0.5))
          .frame(width: 36, height: 44)
      }
      .buttonStyle(.plain)

      ToolbarDivider()

      HStack(spacing: 2) {
        ModeButton(
          icon: "rectangle.inset.filled",
          isSelected: session.captureMode == .entireScreen
        ) {
          session.selectMode(.entireScreen)
        }

        ModeButton(
          icon: "macwindow",
          isSelected: session.captureMode == .selectedWindow
        ) {
          session.selectMode(.selectedWindow)
        }

        ModeButton(
          icon: "rectangle.dashed",
          isSelected: session.captureMode == .selectedArea
        ) {
          session.selectMode(.selectedArea)
        }
      }

      ToolbarDivider()

      Button { showOptions.toggle() } label: {
        HStack(spacing: 4) {
          Text("Options")
            .font(.system(size: 13, weight: .medium))
          Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showOptions, arrowEdge: .bottom) {
        OptionsPopover(options: session.options)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(FrameColors.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
    )
  }
}

private struct ToolbarDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color.white.opacity(0.15))
      .frame(width: 1, height: 28)
      .padding(.horizontal, 8)
  }
}
