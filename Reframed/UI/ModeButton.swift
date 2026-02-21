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
          .font(.system(size: 18))
          .foregroundStyle(ReframedColors.primaryText)
        Text(label)
          .font(.system(size: 10))
          .foregroundStyle(isSelected ? ReframedColors.primaryText : ReframedColors.secondaryText)
      }
      .frame(width: 56, height: 52)
      .background(isSelected ? ReframedColors.muted : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
