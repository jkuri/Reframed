import SwiftUI

struct ModeButton: View {
  let icon: String
  let label: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: icon)
          .font(.system(size: 18))
          .foregroundStyle(FrameColors.primaryText)
        Text(label)
          .font(.system(size: 10))
          .foregroundStyle(FrameColors.secondaryText)
      }
      .frame(width: 56, height: 52)
      .background(isSelected ? FrameColors.selectedBackground : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
