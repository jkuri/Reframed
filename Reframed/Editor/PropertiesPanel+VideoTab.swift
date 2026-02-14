import SwiftUI

extension PropertiesPanel {
  var backgroundSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "paintbrush.fill", title: "Background")

      Picker("", selection: $backgroundMode) {
        ForEach(BackgroundMode.allCases, id: \.rawValue) { mode in
          Text(mode.label).tag(mode)
        }
      }
      .pickerStyle(.segmented)

      switch backgroundMode {
      case .none:
        EmptyView()
      case .gradient:
        gradientGrid
      case .color:
        solidColorPicker
      }
    }
  }

  var gradientGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: 4), spacing: Layout.gridSpacing) {
      ForEach(GradientPresets.all) { preset in
        Button {
          selectedGradientId = preset.id
        } label: {
          Circle()
            .fill(
              LinearGradient(
                colors: preset.colors,
                startPoint: preset.startPoint,
                endPoint: preset.endPoint
              )
            )
            .frame(width: 36, height: 36)
            .overlay(
              Circle()
                .stroke(selectedGradientId == preset.id ? Color.blue : Color.clear, lineWidth: 2)
                .padding(1)
            )
        }
        .buttonStyle(.plain)
      }
    }
  }

  var solidColorPicker: some View {
    TailwindColorPicker(
      displayColor: solidColorDisplay,
      displayName: selectedColorId ?? "Blue",
      isPresented: $showColorPopover,
      isSelected: { $0.id == selectedColorId },
      onSelect: { selectedColorId = $0.id }
    )
  }

  var solidColorDisplay: Color {
    guard let id = selectedColorId, let preset = TailwindColors.all.first(where: { $0.id == id }) else {
      return TailwindColors.all[0].swiftUIColor
    }
    return preset.swiftUIColor
  }

  var paddingSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        sectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Padding")
        Spacer()
        if editorState.padding > 0 {
          Button("Reset") {
            editorState.padding = 0
          }
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.dimLabel)
          .buttonStyle(.plain)
        }
      }

      SliderRow(
        value: $editorState.padding,
        range: 0...0.20,
        step: 0.01,
        formattedValue: "\(Int(editorState.padding * 100))%"
      )
    }
  }

  var cornerRadiusSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        sectionHeader(icon: "rectangle.roundedtop", title: "Corner Radius")
        Spacer()
        if editorState.videoCornerRadius > 0 {
          Button("Reset") {
            editorState.videoCornerRadius = 0
          }
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.dimLabel)
          .buttonStyle(.plain)
        }
      }

      SliderRow(
        value: $editorState.videoCornerRadius,
        range: 0...40,
        formattedValue: "\(Int(editorState.videoCornerRadius))px"
      )
    }
  }
}
