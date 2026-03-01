import SwiftUI

struct SegmentPicker<Item: Hashable>: View {
  let items: [Item]
  let label: (Item) -> String
  @Binding var selection: Item
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(spacing: Layout.segmentSpacing) {
      ForEach(items, id: \.self) { item in
        let isSelected = selection == item
        ToggleGroupItem(
          text: label(item),
          isSelected: isSelected
        ) {
          selection = item
        }
      }
    }
  }
}

private struct ToggleGroupItem: View {
  let text: String
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Text(text)
        .font(.system(size: FontSize.xs, weight: .medium))
        .foregroundStyle(ReframedColors.primaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
          isSelected
            ? ReframedColors.muted
            : (isHovered ? ReframedColors.muted : Color.clear),
          in: RoundedRectangle(cornerRadius: Radius.md)
        )
        .overlay(
          RoundedRectangle(cornerRadius: Radius.md)
            .stroke(ReframedColors.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}
