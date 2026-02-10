import SwiftUI

struct ModeButton: View {
  let icon: String
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 18))
        .foregroundStyle(.white)
        .frame(width: 44, height: 44)
        .background(
          isSelected ? Color.white.opacity(0.12) :
          isHovered ? Color.white.opacity(0.06) :
          Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}
