import SwiftUI

struct ModeButton: View {
  let icon: String
  let label: String
  let isSelected: Bool
  let action: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: icon)
          .font(.system(size: Layout.toolbarIconSize))
          .foregroundStyle(ReframedColors.primaryText)
        Text(label)
          .font(.system(size: FontSize.xxs, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
      }
      .frame(width: Layout.toolbarHeight + 4, height: Layout.toolbarHeight)
      .background(isSelected ? ReframedColors.muted : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
