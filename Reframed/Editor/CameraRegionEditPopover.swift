import SwiftUI

struct CameraRegionEditPopover: View {
  let region: CameraRegionData
  let maxCameraRelativeWidth: CGFloat
  let onChangeType: (CameraRegionType) -> Void
  let onUpdateLayout: (CameraLayout) -> Void
  let onSetCorner: (CameraCorner) -> Void
  let onUpdateStyle:
    (
      CameraAspect?, CGFloat?, CGFloat?, CGFloat?, CodableColor?, Bool?
    ) -> Void
  let onUpdateTransition: (CameraTransitionType?, Double?, CameraTransitionType?, Double?) -> Void
  let onRemove: () -> Void

  @State private var localLayout: CameraLayout = CameraLayout()
  @State private var localAspect: CameraAspect = .original
  @State private var localCornerRadius: CGFloat = 8
  @State private var localShadow: CGFloat = 0
  @State private var localBorderWidth: CGFloat = 0
  @State private var localBorderColor: CodableColor = CodableColor(r: 0, g: 0, b: 0, a: 1)
  @State private var localMirrored: Bool = false
  @State private var localEntryTransition: CameraTransitionType = .none
  @State private var localEntryDuration: Double = 0.3
  @State private var localExitTransition: CameraTransitionType = .none
  @State private var localExitDuration: Double = 0.3
  @State private var showBorderColorPopover = false
  @State private var didInit = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: Layout.regionPopoverSpacing) {
      SectionHeader(title: "Camera Region")

      FullWidthSegmentPicker(
        items: CameraRegionType.allCases,
        label: { $0.label },
        selection: Binding(
          get: { region.type },
          set: { onChangeType($0) }
        )
      )
      .padding(.horizontal, 12)
      .padding(.vertical, 4)

      if region.type == .custom {
        Divider()
          .padding(.horizontal, 12)

        customControls
      }

      Divider()
        .padding(.horizontal, 12)

      transitionControls

      Button {
        onRemove()
      } label: {
        HStack(spacing: 5) {
          Image(systemName: "trash")
            .font(.system(size: 12, weight: .semibold))
          Text("Remove")
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(Color.red.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 7))
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .padding(.vertical, 8)
    .frame(width: Layout.regionPopoverWidth)
    .popoverContainerStyle()
    .onAppear {
      if !didInit {
        localLayout = region.customLayout ?? CameraLayout()
        localAspect = region.customCameraAspect ?? .original
        localCornerRadius = region.customCornerRadius ?? 8
        localShadow = region.customShadow ?? 0
        localBorderWidth = region.customBorderWidth ?? 0
        localBorderColor = region.customBorderColor ?? CodableColor(r: 0, g: 0, b: 0, a: 1)
        localMirrored = region.customMirrored ?? false
        localEntryTransition = region.entryTransition ?? .none
        localEntryDuration = region.entryTransitionDuration ?? 0.3
        localExitTransition = region.exitTransition ?? .none
        localExitDuration = region.exitTransitionDuration ?? 0.3
        didInit = true
      }
    }
    .onChange(of: region.customLayout) { _, newValue in
      if let newValue { localLayout = newValue }
    }
    .onChange(of: localLayout) { _, newValue in
      onUpdateLayout(newValue)
    }
    .onChange(of: localAspect) { _, newValue in
      onUpdateStyle(newValue, nil, nil, nil, nil, nil)
    }
    .onChange(of: localCornerRadius) { _, newValue in
      onUpdateStyle(nil, newValue, nil, nil, nil, nil)
    }
    .onChange(of: localShadow) { _, newValue in
      onUpdateStyle(nil, nil, newValue, nil, nil, nil)
    }
    .onChange(of: localBorderWidth) { _, newValue in
      onUpdateStyle(nil, nil, nil, newValue, nil, nil)
    }
    .onChange(of: localBorderColor) { _, newValue in
      onUpdateStyle(nil, nil, nil, nil, newValue, nil)
    }
    .onChange(of: localMirrored) { _, newValue in
      onUpdateStyle(nil, nil, nil, nil, nil, newValue)
    }
    .onChange(of: localEntryTransition) { _, newValue in
      onUpdateTransition(newValue, nil, nil, nil)
    }
    .onChange(of: localEntryDuration) { _, newValue in
      onUpdateTransition(nil, newValue, nil, nil)
    }
    .onChange(of: localExitTransition) { _, newValue in
      onUpdateTransition(nil, nil, newValue, nil)
    }
    .onChange(of: localExitDuration) { _, newValue in
      onUpdateTransition(nil, nil, nil, newValue)
    }
  }

  private var customControls: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "Position")

      HStack(spacing: 4) {
        ForEach(
          Array(
            zip(
              [CameraCorner.topLeft, .topRight, .bottomLeft, .bottomRight],
              ["arrow.up.left", "arrow.up.right", "arrow.down.left", "arrow.down.right"]
            )
          ),
          id: \.1
        ) { corner, icon in
          Button {
            onSetCorner(corner)
          } label: {
            Image(systemName: icon)
              .font(.system(size: 11))
              .frame(width: 28, height: 28)
              .background(ReframedColors.fieldBackground)
              .clipShape(RoundedRectangle(cornerRadius: 4))
          }
          .buttonStyle(.plain)
          .foregroundStyle(ReframedColors.primaryText)
        }
      }

      SectionHeader(icon: "aspectratio", title: "Aspect Ratio")

      Picker("", selection: $localAspect) {
        ForEach(CameraAspect.allCases) { aspect in
          Text(aspect.label).tag(aspect)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      SectionHeader(icon: "paintbrush", title: "Style")

      SliderRow(
        label: "Size",
        value: $localLayout.relativeWidth,
        range: 0.1...maxCameraRelativeWidth,
        step: 0.01
      )

      SliderRow(
        label: "Radius",
        value: $localCornerRadius,
        range: 0...50,
        formattedValue: "\(Int(localCornerRadius))%"
      )

      SliderRow(
        label: "Shadow",
        value: $localShadow,
        range: 0...100,
        formattedValue: "\(Int(localShadow))"
      )

      SliderRow(
        label: "Border",
        value: $localBorderWidth,
        range: 0...30,
        step: 0.5,
        formattedValue: String(format: "%.1f", localBorderWidth)
      )

      borderColorPickerButton

      ToggleRow(label: "Mirror", isOn: $localMirrored)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }

  private var transitionControls: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.right", title: "Entry Transition")

      FullWidthSegmentPicker(
        items: CameraTransitionType.allCases,
        label: { $0.label },
        selection: $localEntryTransition
      )

      if localEntryTransition != .none {
        SliderRow(
          label: "Duration",
          value: $localEntryDuration,
          range: 0.05...1.0,
          step: 0.05,
          formattedValue: String(format: "%.2fs", localEntryDuration)
        )
      }

      Divider()

      SectionHeader(icon: "arrow.left", title: "Exit Transition")

      FullWidthSegmentPicker(
        items: CameraTransitionType.allCases,
        label: { $0.label },
        selection: $localExitTransition
      )

      if localExitTransition != .none {
        SliderRow(
          label: "Duration",
          value: $localExitDuration,
          range: 0.05...1.0,
          step: 0.05,
          formattedValue: String(format: "%.2fs", localExitDuration)
        )
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }

  private var borderColorPickerButton: some View {
    let currentName =
      TailwindColors.all.first { $0.color == localBorderColor }?.name ?? "Custom"
    return TailwindColorPicker(
      displayColor: Color(cgColor: localBorderColor.cgColor),
      displayName: currentName,
      isPresented: $showBorderColorPopover,
      isSelected: { $0.color == localBorderColor },
      onSelect: { localBorderColor = $0.color }
    )
  }
}
