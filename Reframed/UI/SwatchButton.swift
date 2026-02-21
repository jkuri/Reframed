import SwiftUI

struct SwatchButton<S: ShapeStyle>: View {
  let fill: S
  let isSelected: Bool
  let action: () -> Void
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    let _ = colorScheme
    Button(action: action) {
      RoundedRectangle(cornerRadius: Radius.lg)
        .fill(fill)
        .aspectRatio(1.0, contentMode: .fit)
        .overlay(
          RoundedRectangle(cornerRadius: Radius.lg)
            .stroke(ReframedColors.divider, lineWidth: 1)
        )
        .overlay(
          RoundedRectangle(cornerRadius: Radius.lg)
            .stroke(isSelected ? ReframedColors.ring : Color.clear, lineWidth: 2)
            .padding(1)
        )
    }
    .buttonStyle(.plain)
  }
}
