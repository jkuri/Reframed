import SwiftUI

struct TailwindColorPicker: View {
  let displayColor: Color
  let displayName: String
  let isSelected: (ColorPreset) -> Bool
  let onSelect: (ColorPreset) -> Void

  var body: some View {
    SelectButton(
      label: displayName,
      leadingContent: AnyView(
        Circle()
          .fill(displayColor)
          .overlay(Circle().stroke(ReframedColors.border, lineWidth: 1))
          .frame(width: 14, height: 14)
      )
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(TailwindColors.all) { preset in
            ColorPickerRow(
              preset: preset,
              isSelected: isSelected(preset),
              onSelect: { onSelect(preset) }
            )
          }
        }
        .padding(.vertical, 8)
      }
      .frame(width: 200)
      .frame(maxHeight: 320)
    }
  }
}

private struct ColorPickerRow: View {
  let preset: ColorPreset
  let isSelected: Bool
  let onSelect: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 10) {
        Circle()
          .fill(preset.swiftUIColor)
          .overlay(Circle().stroke(ReframedColors.border, lineWidth: 1))
          .frame(width: 18, height: 18)
        Text(preset.name)
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: FontSize.xs, weight: .bold))
            .foregroundStyle(ReframedColors.primaryText)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      RoundedRectangle(cornerRadius: Radius.sm)
        .fill(isHovered ? ReframedColors.hoverBackground : Color.clear)
        .padding(.horizontal, 4)
    )
    .onHover { isHovered = $0 }
  }
}
