import SwiftUI

struct ShortcutRecorderButton: View {
  @Binding var shortcut: KeyboardShortcut
  @State private var isRecording = false

  var body: some View {
    ZStack {
      if isRecording {
        HStack(spacing: 4) {
          Text("Press shortcut...")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.dimLabel)
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
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.accentColor, lineWidth: 1.5)
        )
      } else {
        Button {
          isRecording = true
        } label: {
          Text(shortcut.displayString)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .tracking(3)
            .foregroundStyle(ReframedColors.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .frame(minWidth: 60)
            .background(ReframedColors.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
      }
    }
  }
}
