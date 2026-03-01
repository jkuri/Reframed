import SwiftUI

struct SelectButton<MenuContent: View>: View {
  let label: String
  var fixedWidth: CGFloat? = nil
  var leadingContent: AnyView? = nil
  private let menuBuilder: (@escaping () -> Void) -> MenuContent

  @State private var isPresented = false
  @State private var isHovered = false
  @Environment(\.colorScheme) private var colorScheme

  init(
    label: String,
    fixedWidth: CGFloat? = nil,
    leadingContent: AnyView? = nil,
    @ViewBuilder menu: @escaping () -> MenuContent
  ) {
    self.label = label
    self.fixedWidth = fixedWidth
    self.leadingContent = leadingContent
    self.menuBuilder = { _ in menu() }
  }

  init(
    label: String,
    fixedWidth: CGFloat? = nil,
    leadingContent: AnyView? = nil,
    @ViewBuilder content: @escaping (@escaping () -> Void) -> MenuContent
  ) {
    self.label = label
    self.fixedWidth = fixedWidth
    self.leadingContent = leadingContent
    self.menuBuilder = content
  }

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
          .font(.system(size: FontSize.xs, weight: .medium))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
        if fixedWidth == nil {
          Spacer()
        }
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: FontSize.xs, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
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
      menuBuilder { isPresented = false }
        .popoverContainerStyle()
    }
  }
}
