import SwiftUI

struct ResizePopover: View {
  let windowController: WindowController
  let window: WindowInfo

  @State private var customWidth: Int = 1920
  @State private var customHeight: Int = 1080

  private let popoverBg = Color.white
  private let borderColor = Color.black.opacity(0.1)
  private let dividerColor = Color.black.opacity(0.12)
  private let textColor = Color.black
  private let secondaryTextColor = Color.black.opacity(0.6)
  private let disabledOpacity = 0.35

  private var screenSize: CGSize {
    NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
  }

  private struct SizePreset {
    let width: Int
    let height: Int
    var label: String { "\(width) \u{00d7} \(height)" }
    var size: CGSize { CGSize(width: width, height: height) }
  }

  private struct PresetGroup {
    let title: String
    let presets: [SizePreset]
  }

  private let groups: [PresetGroup] = [
    PresetGroup(
      title: "16:9",
      presets: [
        SizePreset(width: 1280, height: 720),
        SizePreset(width: 1920, height: 1080),
        SizePreset(width: 2560, height: 1440),
      ]
    ),
    PresetGroup(
      title: "4:3",
      presets: [
        SizePreset(width: 1024, height: 768),
        SizePreset(width: 1280, height: 960),
      ]
    ),
    PresetGroup(
      title: "16:10",
      presets: [
        SizePreset(width: 1280, height: 800),
        SizePreset(width: 1440, height: 900),
        SizePreset(width: 1680, height: 1050),
      ]
    ),
    PresetGroup(
      title: "9:16",
      presets: [
        SizePreset(width: 720, height: 1280),
        SizePreset(width: 1080, height: 1920),
      ]
    ),
    PresetGroup(
      title: "Square",
      presets: [
        SizePreset(width: 720, height: 720),
        SizePreset(width: 1080, height: 1080),
      ]
    ),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
            if index > 0 {
              Divider().background(dividerColor).padding(.vertical, 4)
            }
            resizeSectionHeader(group.title)
            ForEach(group.presets, id: \.label) { preset in
              let fits =
                preset.size.width <= screenSize.width && preset.size.height <= screenSize.height
              ResizePopoverRow(label: preset.label) {
                windowController.resize(window, to: preset.size)
              }
              .disabled(!fits)
              .opacity(fits ? 1 : disabledOpacity)
            }
          }
        }
      }
      .frame(maxHeight: 300)

      Divider().background(dividerColor).padding(.vertical, 4)

      resizeSectionHeader("Custom")

      HStack(spacing: 6) {
        TextField("W", value: $customWidth, format: .number)
          .textFieldStyle(.plain)
          .font(.system(size: FontSize.xs, design: .monospaced))
          .foregroundStyle(textColor)
          .multilineTextAlignment(.center)
          .frame(width: 60, height: 28)
          .background(Color.black.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
          .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(borderColor))

        Text("\u{00D7}")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(secondaryTextColor)

        TextField("H", value: $customHeight, format: .number)
          .textFieldStyle(.plain)
          .font(.system(size: FontSize.xs, design: .monospaced))
          .foregroundStyle(textColor)
          .multilineTextAlignment(.center)
          .frame(width: 60, height: 28)
          .background(Color.black.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
          .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(borderColor))

        Spacer()

        Button("Apply") {
          windowController.resize(
            window,
            to: CGSize(width: max(customWidth, 100), height: max(customHeight, 100))
          )
        }
        .buttonStyle(PrimaryButtonStyle(size: .small, forceLightMode: true))
        .fixedSize()
      }
      .padding(.horizontal, 12)
      .padding(.bottom, 8)
    }
    .padding(.vertical, 8)
    .frame(width: 260)
    .background(popoverBg)
    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    .overlay(
      RoundedRectangle(cornerRadius: Radius.lg)
        .strokeBorder(borderColor, lineWidth: 0.5)
    )
    .presentationBackground(popoverBg)
    .onAppear {
      customWidth = Int(window.frame.width)
      customHeight = Int(window.frame.height)
    }
  }

  private func resizeSectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: FontSize.xs, weight: .medium))
      .foregroundStyle(secondaryTextColor)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.top, 8)
      .padding(.bottom, 4)
  }
}

private struct ResizePopoverRow: View {
  let label: String
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack {
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
