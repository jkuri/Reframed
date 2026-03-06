import SwiftUI

struct AreaSizePresetsPopover: View {
  let presets: [(String, Int, Int)]
  let onSelect: (Int, Int) -> Void

  private let popoverBg = Color.white
  private let borderColor = Color.black.opacity(0.1)
  private let textColor = Color.black
  private let secondaryTextColor = Color.black.opacity(0.6)

  private var screenSize: CGSize {
    NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Size Presets")
        .font(.system(size: FontSize.xxs, weight: .semibold))
        .foregroundStyle(secondaryTextColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)

      ForEach(presets, id: \.0) { preset in
        let fits = CGFloat(preset.1) <= screenSize.width && CGFloat(preset.2) <= screenSize.height
        AreaPresetRow(label: preset.0) {
          onSelect(preset.1, preset.2)
        }
        .disabled(!fits)
        .opacity(fits ? 1 : 0.35)
      }
    }
    .padding(.vertical, 8)
    .frame(minWidth: 200)
    .background(popoverBg)
    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(
      RoundedRectangle(cornerRadius: Radius.lg)
        .strokeBorder(borderColor, lineWidth: 0.5)
    )
    .presentationBackground(popoverBg)
  }
}

private struct AreaPresetRow: View {
  let label: String
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Text(label)
          .font(.system(size: FontSize.xs))
        Spacer()
      }
      .foregroundStyle(Color.black)
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(
      RoundedRectangle(cornerRadius: Radius.sm)
        .fill(isHovered ? Color.black.opacity(0.06) : Color.clear)
        .padding(.horizontal, 4)
    )
    .onHover { isHovered = $0 }
  }
}
