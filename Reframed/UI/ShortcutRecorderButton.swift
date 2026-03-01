import SwiftUI

struct ShortcutRecorderButton: View {
  @Binding var shortcut: KeyboardShortcut
  @State private var isRecording = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    ZStack {
      if isRecording {
        HStack(spacing: 4) {
          Text("Press shortcut...")
            .font(.system(size: FontSize.xs))
            .foregroundStyle(ReframedColors.secondaryText)
          ShortcutCaptureView(
            onCapture: { newShortcut in
              shortcut = newShortcut
              isRecording = false
            },
            onCancel: {
              isRecording = false
            }
          )
          .frame(width: 0, height: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .frame(minWidth: 120)
        .background(ReframedColors.fieldBackground.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(ReframedColors.border))
        .overlay(
          RoundedRectangle(cornerRadius: Radius.md)
            .stroke(ReframedColors.ring, lineWidth: 1.5)
        )
      } else {
        Button {
          isRecording = true
        } label: {
          Text(shortcut.displayString)
            .font(.system(size: FontSize.xs, weight: .medium, design: .monospaced))
            .tracking(3)
            .frame(width: 80)
        }
        .buttonStyle(OutlineButtonStyle(size: .small))
      }
    }
  }
}
