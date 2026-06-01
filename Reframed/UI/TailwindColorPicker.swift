import SwiftUI

struct TailwindColorPicker: View {
  let displayColor: Color
  let displayName: String
  let isSelected: (ColorPreset) -> Bool
  let onSelect: (ColorPreset) -> Void

  init(
    displayColor: Color,
    displayName: String,
    isSelected: @escaping (ColorPreset) -> Bool,
    onSelect: @escaping (ColorPreset) -> Void
  ) {
    self.displayColor = displayColor
    self.displayName = displayName
    self.isSelected = isSelected
    self.onSelect = onSelect
  }

  init(
    color: CodableColor,
    fallbackName: String = "Custom",
    onSelect: @escaping (CodableColor) -> Void
  ) {
    let name = TailwindColors.all.first { $0.color == color }?.name ?? fallbackName
    self.displayColor = Color(cgColor: color.cgColor)
    self.displayName = name
    self.isSelected = { $0.color == color }
    self.onSelect = { onSelect($0.color) }
  }

  var body: some View {
    SelectButton(
      label: displayName,
      leadingContent: AnyView(
        Circle()
          .fill(displayColor)
          .overlay(Circle().stroke(ReframedColors.border, lineWidth: 1))
          .frame(width: 14, height: 14)
      )
    ) { dismiss in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(TailwindColors.all) { preset in
            ColorPickerRow(
              preset: preset,
              isSelected: isSelected(preset),
              onSelect: {
                onSelect(preset)
                dismiss()
              }
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
        Text(LocalizedStringKey(preset.name))
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
    .buttonStyle(PlainCustomButtonStyle())
    .background(
      RoundedRectangle(cornerRadius: Radius.sm)
        .fill(isHovered ? ReframedColors.hoverBackground : Color.clear)
        .padding(.horizontal, 4)
    )
    .onHover { isHovered = $0 }
  }
}
