import SwiftUI

struct CheckmarkRow: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "checkmark")
          .font(.system(size: 11, weight: .bold))
          .frame(width: 14)
          .opacity(isSelected ? 1 : 0)
        Text(title)
          .font(.system(size: 13))
        Spacer()
      }
      .foregroundStyle(FrameColors.primaryText)
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(CheckmarkRowHoverBackground())
  }
}

private struct CheckmarkRowHoverBackground: View {
  @State private var isHovered = false

  var body: some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(isHovered ? FrameColors.hoverBackground : Color.clear)
      .padding(.horizontal, 4)
      .onHover { isHovered = $0 }
  }
}
