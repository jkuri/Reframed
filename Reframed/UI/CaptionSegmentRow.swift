import SwiftUI

struct CaptionSegmentRow: View {
  let segment: CaptionSegment
  let onSeek: () -> Void

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
      }

      Text(segment.text)
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.primaryText)
        .lineLimit(3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(ReframedColors.muted.opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
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
