import SwiftUI

struct SegmentPicker<Item: Hashable>: View {
  let items: [Item]
  let label: (Item) -> String
  let isSelected: (Item) -> Bool
  let onSelect: (Item) -> Void
  var itemWidth: CGFloat? = nil
  var horizontalPadding: CGFloat = 10

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(spacing: 4) {
      ForEach(items, id: \.self) { item in
        Button {
          onSelect(item)
        } label: {
          if let itemWidth {
            Text(label(item))
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(ReframedColors.primaryText)
              .frame(width: itemWidth, height: 28)
              .background(isSelected(item) ? ReframedColors.selectedActive : ReframedColors.fieldBackground)
              .clipShape(RoundedRectangle(cornerRadius: Radius.md))
          } else {
            Text(label(item))
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(ReframedColors.primaryText)
              .padding(.horizontal, horizontalPadding)
              .frame(height: 28)
              .background(isSelected(item) ? ReframedColors.selectedActive : ReframedColors.fieldBackground)
              .clipShape(RoundedRectangle(cornerRadius: Radius.md))
          }
        }
        .buttonStyle(.plain)
      }
    }
  }
}
