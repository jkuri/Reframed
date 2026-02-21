import SwiftUI

struct SelectButton<MenuContent: View>: View {
  let label: String
  var fixedWidth: CGFloat? = nil
  var leadingContent: AnyView? = nil
  @ViewBuilder let menu: () -> MenuContent

  @State private var isPresented = false
  @State private var isHovered = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    Button {
      isPresented.toggle()
    } label: {
      HStack(spacing: 6) {
        if let leadingContent {
          leadingContent
        }
        Text(label)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
        if fixedWidth == nil {
          Spacer()
        }
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(ReframedColors.mutedForeground)
      }
      .padding(.horizontal, 10)
      .frame(width: fixedWidth, height: 30)
      .background(isHovered ? ReframedColors.accent : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.md)
          .stroke(ReframedColors.border, lineWidth: 1)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
      menu()
        .popoverContainerStyle()
    }
  }
}
