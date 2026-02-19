import SwiftUI

struct CompactTimerView: View {
  let startedAt: Date
  let frozen: Bool

  var body: some View {
    if frozen {
      timerText(for: Date())
    } else {
      SwiftUI.TimelineView(.periodic(from: startedAt, by: 1)) { context in
        timerText(for: context.date)
      }
    }
  }

  private func timerText(for date: Date) -> some View {
    Text(formatDuration(seconds: Int(date.timeIntervalSince(startedAt))))
      .font(.system(size: 16, design: .monospaced))
      .foregroundStyle(ReframedColors.primaryText)
      .frame(minWidth: 80)
  }
}

struct ToolbarActionButton: View {
  let icon: String
  let tooltip: String
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 15))
        .foregroundStyle(ReframedColors.primaryText)
        .frame(width: 36, height: 36)
        .background(isHovered ? ReframedColors.hoverBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help(tooltip)
  }
}

struct ToolbarToggleButton: View {
  let icon: String
  let activeIcon: String
  let label: String
  let isOn: Bool
  let isAvailable: Bool
  let tooltip: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: isOn ? activeIcon : icon)
          .font(.system(size: 18))
          .foregroundStyle(iconColor)
        Text(label)
          .font(.system(size: 10))
          .foregroundStyle(labelColor)
      }
      .frame(width: 56, height: 52)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!isAvailable)
    .help(tooltip)
  }

  private var iconColor: Color {
    if !isAvailable { return ReframedColors.disabledText }
    return isOn ? ReframedColors.primaryText : ReframedColors.primaryText
  }

  private var labelColor: Color {
    if !isAvailable { return ReframedColors.disabledText }
    return isOn ? ReframedColors.secondaryText : ReframedColors.secondaryText
  }

  private var background: Color {
    if !isAvailable { return Color.clear }
    if isOn { return ReframedColors.selectedBackground }
    return Color.clear
  }
}

struct AudioLevelIcon: View {
  let icon: String
  let level: Float

  private let dotCount = 8
  private let thresholds: [Float] = [0.01, 0.03, 0.06, 0.10, 0.16, 0.24, 0.35, 0.50]

  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.system(size: 15))
        .foregroundStyle(ReframedColors.tertiaryText)
        .frame(height: 20)
      HStack(spacing: 1.5) {
        ForEach(0..<dotCount, id: \.self) { i in
          Circle()
            .fill(level > thresholds[i] ? Color.accentColor : ReframedColors.tertiaryText.opacity(0.2))
            .frame(width: 3, height: 3)
        }
      }
    }
  }
}

struct ToolbarDivider: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme

    Rectangle()
      .fill(ReframedColors.divider)
      .frame(width: 1, height: 32)
      .padding(.horizontal, 8)
  }
}
