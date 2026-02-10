import AVFoundation
import SwiftUI

struct EditorToolbar: View {
  @Bindable var editorState: EditorState
  let onSave: () -> Void
  let onCancel: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: {
        if editorState.isPlaying {
          editorState.pause()
        } else {
          editorState.play()
        }
      }) {
        Image(systemName: editorState.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 16))
          .frame(width: 32, height: 32)
      }
      .buttonStyle(.plain)
      .foregroundStyle(FrameColors.primaryText)

      timeDisplay

      Spacer()

      if editorState.hasWebcam {
        pipCornerButtons
      }

      Spacer()

      Button("Cancel") {
        onCancel()
      }
      .buttonStyle(EditorButtonStyle(isPrimary: false))

      Button("Save") {
        onSave()
      }
      .buttonStyle(EditorButtonStyle(isPrimary: true))
      .disabled(editorState.isExporting)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private var timeDisplay: some View {
    let current = formatTime(editorState.currentTime)
    let total = formatTime(editorState.duration)
    return Text("\(current) / \(total)")
      .font(.system(size: 12, design: .monospaced))
      .foregroundStyle(FrameColors.secondaryText)
  }

  private var pipCornerButtons: some View {
    HStack(spacing: 4) {
      Text("PiP")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(FrameColors.dimLabel)

      ForEach(Array(zip(
        [PiPCorner.topLeft, .topRight, .bottomLeft, .bottomRight],
        ["arrow.up.left", "arrow.up.right", "arrow.down.left", "arrow.down.right"]
      )), id: \.1) { corner, icon in
        Button {
          editorState.setPipCorner(corner)
        } label: {
          Image(systemName: icon)
            .font(.system(size: 10))
            .frame(width: 24, height: 24)
            .background(FrameColors.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .foregroundStyle(FrameColors.primaryText)
      }
    }
  }

  private func formatTime(_ time: CMTime) -> String {
    let seconds = max(0, CMTimeGetSeconds(time))
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}

private struct EditorButtonStyle: ButtonStyle {
  let isPrimary: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(isPrimary ? .white : FrameColors.primaryText)
      .padding(.horizontal, 16)
      .frame(height: 30)
      .background(
        isPrimary
          ? (configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
          : (configuration.isPressed ? FrameColors.buttonPressed : FrameColors.buttonBackground)
      )
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}
