import AVFoundation
import SwiftUI

struct EditorBottomBar: View {
  @Bindable var editorState: EditorState
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(spacing: 12) {
      Button(action: {
        if editorState.isPlaying {
          editorState.pause()
        } else {
          editorState.play()
        }
      }) {
        Image(systemName: editorState.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 14))
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(FrameColors.primaryText)

      timeDisplay

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  private var timeDisplay: some View {
    let current = formatTime(editorState.currentTime)
    let total = formatTime(editorState.duration)
    return Text("\(current) / \(total)")
      .font(.system(size: 12, design: .monospaced))
      .foregroundStyle(FrameColors.secondaryText)
  }

  private func formatTime(_ time: CMTime) -> String {
    let seconds = max(0, CMTimeGetSeconds(time))
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}
