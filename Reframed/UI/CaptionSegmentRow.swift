import SwiftUI

struct CaptionSegmentRow: View {
  let segment: CaptionSegment
  let onSeek: () -> Void
  let onUpdateText: (String) -> Void
  let onDelete: () -> Void

  @State private var isEditing = false
  @State private var editText = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Button {
          onSeek()
        } label: {
          Text(formatTimeRange(start: segment.startSeconds, end: segment.endSeconds))
            .font(.system(size: FontSize.xs, design: .monospaced))
            .foregroundStyle(ReframedColors.secondaryText)
        }
        .buttonStyle(.plain)
        Spacer()
        IconButton(systemName: "trash", color: ReframedColors.secondaryText) {
          onDelete()
        }
      }

      if isEditing {
        TextField("", text: $editText, axis: .vertical)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.primaryText)
          .textFieldStyle(.plain)
          .lineLimit(1...5)
          .padding(.horizontal, 6)
          .padding(.vertical, 4)
          .background(ReframedColors.fieldBackground)
          .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
          .overlay(
            RoundedRectangle(cornerRadius: Radius.sm)
              .strokeBorder(ReframedColors.accent.opacity(0.5))
          )
          .focused($isFocused)
          .onSubmit { commit() }
          .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
          }
          .onExitCommand { cancel() }
          .onAppear { isFocused = true }
      } else {
        Text(segment.text)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(3)
          .frame(maxWidth: .infinity, alignment: .leading)
          .onTapGesture { startEditing() }
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(ReframedColors.muted.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
  }

  private func startEditing() {
    editText = segment.text
    isEditing = true
  }

  private func commit() {
    let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty, trimmed != segment.text {
      onUpdateText(trimmed)
    }
    isEditing = false
  }

  private func cancel() {
    isEditing = false
  }

  private func formatTimeRange(start: Double, end: Double) -> String {
    "\(formatTimestamp(start)) → \(formatTimestamp(end))"
  }

  private func formatTimestamp(_ seconds: Double) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    let ms = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
    return String(format: "%d:%02d.%02d", mins, secs, ms)
  }
}
