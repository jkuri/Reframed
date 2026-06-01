import SwiftUI

struct SpotlightRegionEditPopover: View {
  let region: SpotlightRegionData
  let globalRadius: CGFloat
  let globalDimOpacity: CGFloat
  let globalEdgeSoftness: CGFloat
  let onUpdateStyle: (CGFloat?, CGFloat?, CGFloat?, Double?) -> Void
  let onRemove: () -> Void

  @State private var localRadius: CGFloat = 200
  @State private var localDimOpacity: CGFloat = 0.6
  @State private var localEdgeSoftness: CGFloat = 50
  @State private var localFadeDuration: CGFloat = 0
  @State private var useCustomRadius: Bool = false
  @State private var useCustomDimOpacity: Bool = false
  @State private var useCustomEdgeSoftness: Bool = false
  @State private var didInit = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.regionPopoverSpacing) {
      SectionHeader(title: "Spotlight Region")

      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        overrideSlider(
          label: "Radius",
          useCustom: $useCustomRadius,
          localValue: $localRadius,
          globalValue: globalRadius,
          range: 50...500,
          step: 10,
          format: { "\(Int($0))px" },
          onUpdate: { onUpdateStyle($0, nil, nil, nil) },
          onReset: { onUpdateStyle(nil, nil, nil, nil) }
        )

        overrideSlider(
          label: "Dim",
          useCustom: $useCustomDimOpacity,
          localValue: $localDimOpacity,
          globalValue: globalDimOpacity,
          range: 0.1...0.95,
          step: 0.05,
          format: { "\(Int($0 * 100))%" },
          onUpdate: { onUpdateStyle(nil, $0, nil, nil) },
          onReset: { onUpdateStyle(nil, nil, nil, nil) }
        )

        overrideSlider(
          label: "Softness",
          useCustom: $useCustomEdgeSoftness,
          localValue: $localEdgeSoftness,
          globalValue: globalEdgeSoftness,
          range: 0...200,
          step: 5,
          format: { "\(Int($0))px" },
          onUpdate: { onUpdateStyle(nil, nil, $0, nil) },
          onReset: { onUpdateStyle(nil, nil, nil, nil) }
        )

        Divider()

        SectionHeader(icon: "waveform.path", title: "Fade")

        SliderRow(
          label: "Duration",
          labelWidth: 58,
          value: $localFadeDuration,
          range: 0...1.0,
          step: 0.05,
          formattedValue: localFadeDuration == 0
            ? "关闭"
            : String(format: "%.2f秒", localFadeDuration),
          valueWidth: 40
        )
        .onChange(of: localFadeDuration) { _, newValue in
          onUpdateStyle(nil, nil, nil, Double(newValue))
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 4)

      Button {
        onRemove()
      } label: {
        Label("Remove", systemImage: "trash")
      }
      .buttonStyle(OutlineButtonStyle(size: .medium, fullWidth: true))
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .padding(.vertical, 8)
    .frame(width: Layout.regionPopoverWidth)
    .popoverContainerStyle()
    .onAppear {
      guard !didInit else { return }
      localRadius = region.customRadius ?? globalRadius
      localDimOpacity = region.customDimOpacity ?? globalDimOpacity
      localEdgeSoftness = region.customEdgeSoftness ?? globalEdgeSoftness
      localFadeDuration = CGFloat(region.fadeDuration ?? 0)
      useCustomRadius = region.customRadius != nil
      useCustomDimOpacity = region.customDimOpacity != nil
      useCustomEdgeSoftness = region.customEdgeSoftness != nil
      didInit = true
    }
  }

  private func overrideSlider(
    label: String,
    useCustom: Binding<Bool>,
    localValue: Binding<CGFloat>,
    globalValue: CGFloat,
    range: ClosedRange<CGFloat>,
    step: CGFloat,
    format: @escaping (CGFloat) -> String,
    onUpdate: @escaping (CGFloat) -> Void,
    onReset: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      ToggleRow(label: "自定义\(localizedLabel(label))", isOn: useCustom)
        .onChange(of: useCustom.wrappedValue) { _, newValue in
          if newValue {
            localValue.wrappedValue = globalValue
            onUpdate(globalValue)
          } else {
            onReset()
          }
        }

      if useCustom.wrappedValue {
        SliderRow(
          label: label,
          labelWidth: 58,
          value: localValue,
          range: range,
          step: step,
          formattedValue: format(localValue.wrappedValue),
          valueWidth: 40
        )
        .onChange(of: localValue.wrappedValue) { _, newValue in
          onUpdate(newValue)
        }
      }
    }
  }

  private func localizedLabel(_ label: String) -> String {
    switch label {
    case "Radius": return "半径"
    case "Dim": return "暗化"
    case "Softness": return "柔和度"
    default: return label
    }
  }
}
