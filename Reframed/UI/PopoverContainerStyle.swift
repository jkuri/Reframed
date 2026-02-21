import SwiftUI

struct PopoverContainerStyle: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    let _ = colorScheme
    content
      .background(ReframedColors.backgroundPopover)
      .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.lg)
          .strokeBorder(ReframedColors.border, lineWidth: 0.5)
      )
      .presentationBackground(ReframedColors.backgroundPopover)
  }
}

extension View {
  func popoverContainerStyle() -> some View {
    modifier(PopoverContainerStyle())
  }
}
