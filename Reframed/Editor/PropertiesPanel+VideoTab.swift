import SwiftUI

extension PropertiesPanel {
  var backgroundSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "paintbrush.fill", title: "Background")

      FullWidthSegmentPicker(
        items: BackgroundMode.allCases,
        label: { $0.label },
        selection: $backgroundMode
      )

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
        SwatchButton(
          fill: LinearGradient(
            colors: preset.colors,
            startPoint: preset.startPoint,
            endPoint: preset.endPoint
          ),
          isSelected: selectedGradientId == preset.id
        ) {
          selectedGradientId = preset.id
        }
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
          .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
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
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      }
      .buttonStyle(.plain)
      .foregroundStyle(ReframedColors.primaryText)
      if editorState.backgroundImage != nil {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
          SectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Fill Mode")

          FullWidthSegmentPicker(
            items: BackgroundImageFillMode.allCases,
            label: { $0.label },
            selection: $editorState.backgroundImageFillMode
          )
        }
      }
    }
  }

  var solidColorGrid: some View {
    LazyVGrid(columns: swatchColumns, spacing: 6) {
      ForEach(TailwindColors.all) { preset in
        SwatchButton(
          fill: preset.swiftUIColor,
          isSelected: selectedColorId == preset.id
        ) {
          selectedColorId = preset.id
        }
      }
    }
  }

  var paddingSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        SectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Padding")
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
        range: 0...0.50,
        step: 0.01,
        formattedValue: "\(Int(editorState.padding * 100))%"
      )
    }
  }

  var cornerRadiusSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        SectionHeader(icon: "rectangle.roundedtop", title: "Corner Radius")
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
        range: 0...50,
        formattedValue: "\(Int(editorState.videoCornerRadius))%"
      )
    }
  }

  var videoShadowSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      HStack {
        SectionHeader(icon: "shadow", title: "Shadow")
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
