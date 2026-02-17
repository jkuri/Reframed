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
      .labelsHidden()

      switch backgroundMode {
      case .color:
        solidColorGrid
      case .gradient:
        gradientGrid
      case .image:
        imageBackgroundSection
      }
    }
  }

  private var swatchColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
  }

  var gradientGrid: some View {
    LazyVGrid(columns: swatchColumns, spacing: 6) {
      ForEach(GradientPresets.all) { preset in
        Button {
          selectedGradientId = preset.id
        } label: {
          RoundedRectangle(cornerRadius: 10)
            .fill(
              LinearGradient(
                colors: preset.colors,
                startPoint: preset.startPoint,
                endPoint: preset.endPoint
              )
            )
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(selectedGradientId == preset.id ? Color.blue : Color.clear, lineWidth: 2)
                .padding(1)
            )
        }
        .buttonStyle(.plain)
      }
    }
  }

  var imageBackgroundSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      if let image = editorState.backgroundImage {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: 60)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      Button {
        pickBackgroundImage()
      } label: {
        HStack {
          Image(systemName: "photo.on.rectangle")
          Text(editorState.backgroundImage != nil ? "Change Image" : "Choose Image")
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(ReframedColors.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
      .foregroundStyle(ReframedColors.primaryText)
      if editorState.backgroundImage != nil {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
          sectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Fill Mode")

          Picker("", selection: $editorState.backgroundImageFillMode) {
            ForEach(BackgroundImageFillMode.allCases) { mode in
              Text(mode.label).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }
      }
    }
  }

  var solidColorGrid: some View {
    LazyVGrid(columns: swatchColumns, spacing: 6) {
      ForEach(TailwindColors.all) { preset in
        Button {
          selectedColorId = preset.id
        } label: {
          RoundedRectangle(cornerRadius: 10)
            .fill(preset.swiftUIColor)
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(selectedColorId == preset.id ? Color.blue : Color.clear, lineWidth: 2)
                .padding(1)
            )
        }
        .buttonStyle(.plain)
      }
    }
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
        range: 0...20,
        formattedValue: "\(Int(editorState.videoCornerRadius))%"
      )
    }
  }

  var videoShadowSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        sectionHeader(icon: "shadow", title: "Shadow")
        Spacer()
        if editorState.videoShadow > 0 {
          Button("Reset") {
            editorState.videoShadow = 0
          }
          .font(.system(size: 11))
          .foregroundStyle(ReframedColors.dimLabel)
          .buttonStyle(.plain)
        }
      }

      SliderRow(
        value: $editorState.videoShadow,
        range: 0...100,
        formattedValue: "\(Int(editorState.videoShadow))"
      )
    }
  }
}
