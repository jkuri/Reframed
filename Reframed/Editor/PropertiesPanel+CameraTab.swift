import SwiftUI

extension PropertiesPanel {
  var cameraSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "web.camera", title: "Camera")

      ToggleRow(label: "Enabled", isOn: $editorState.webcamEnabled)

      ToggleRow(label: "Mirror", isOn: $editorState.cameraMirrored)
        .disabled(!editorState.webcamEnabled)
        .opacity(editorState.webcamEnabled ? 1 : 0.5)
    }
  }

  var cameraPositionSection: some View {
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
            editorState.setCameraCorner(corner)
          } label: {
            Image(systemName: icon)
              .font(.system(size: 11))
              .frame(width: 28, height: 28)
              .background(ReframedColors.fieldBackground)
              .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
          }
          .buttonStyle(.plain)
          .foregroundStyle(ReframedColors.primaryText)
        }
      }
    }
    .disabled(!editorState.webcamEnabled)
    .opacity(editorState.webcamEnabled ? 1 : 0.5)
  }

  var cameraAspectRatioSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "aspectratio", title: "Aspect Ratio")

      SegmentPicker(
        items: CameraAspect.allCases,
        label: { $0.label },
        selection: $editorState.cameraAspect
      )
      .onChange(of: editorState.cameraAspect) { _, _ in
        editorState.clampCameraPosition()
      }
    }
    .disabled(!editorState.webcamEnabled)
    .opacity(editorState.webcamEnabled ? 1 : 0.5)
  }

  var cameraStyleSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "paintbrush", title: "Style")

      SliderRow(
        label: "Size",
        value: $editorState.cameraLayout.relativeWidth,
        range: 0.1...editorState.maxCameraRelativeWidth,
        step: 0.01
      )
      .onChange(of: editorState.cameraLayout.relativeWidth) { _, _ in
        editorState.clampCameraPosition()
      }

      SliderRow(
        label: "Radius",
        value: $editorState.cameraCornerRadius,
        range: 0...50,
        formattedValue: "\(Int(editorState.cameraCornerRadius))%"
      )

      SliderRow(
        label: "Shadow",
        value: $editorState.cameraShadow,
        range: 0...100,
        formattedValue: "\(Int(editorState.cameraShadow))"
      )

      SliderRow(
        label: "Border",
        value: $editorState.cameraBorderWidth,
        range: 0...30,
        step: 0.5,
        formattedValue: String(format: "%.1f", editorState.cameraBorderWidth)
      )

      borderColorPickerButton
    }
    .disabled(!editorState.webcamEnabled)
    .opacity(editorState.webcamEnabled ? 1 : 0.5)
  }

  var cameraBackgroundSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "person.and.background.dotted", title: "Background")

      SegmentPicker(
        items: CameraBackgroundMode.allCases,
        label: { $0.label },
        selection: $cameraBackgroundMode
      )

      switch cameraBackgroundMode {
      case .none:
        EmptyView()
      case .blur:
        SliderRow(
          label: "Intensity",
          value: $cameraBlurIntensity,
          range: 0.1...1.0,
          step: 0.05,
          formattedValue: "\(Int(cameraBlurIntensity * 100))%"
        )
      case .color:
        cameraColorGrid
      case .gradient:
        cameraGradientGrid
      case .image:
        cameraImageSection
      }
    }
    .disabled(!editorState.webcamEnabled)
    .opacity(editorState.webcamEnabled ? 1 : 0.5)
  }

  private var cameraColorGrid: some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
    return LazyVGrid(columns: columns, spacing: 6) {
      ForEach(TailwindColors.all) { preset in
        SwatchButton(
          fill: preset.swiftUIColor,
          isSelected: selectedCameraColorId == preset.id
        ) {
          selectedCameraColorId = preset.id
        }
      }
    }
  }

  private var cameraGradientGrid: some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
    return LazyVGrid(columns: columns, spacing: 6) {
      ForEach(GradientPresets.all) { preset in
        SwatchButton(
          fill: LinearGradient(
            colors: preset.colors,
            startPoint: preset.startPoint,
            endPoint: preset.endPoint
          ),
          isSelected: selectedCameraGradientId == preset.id
        ) {
          selectedCameraGradientId = preset.id
        }
      }
    }
  }

  private var cameraImageSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      if let image = editorState.cameraBackgroundImage {
        Image(nsImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: 60)
          .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
      }
      Button {
        pickCameraBackgroundImage()
      } label: {
        HStack {
          Image(systemName: "photo.on.rectangle")
          Text(editorState.cameraBackgroundImage != nil ? "Change Image" : "Choose Image")
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(ReframedColors.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      }
      .buttonStyle(.plain)
      .foregroundStyle(ReframedColors.primaryText)
    }
  }

  var cameraFullscreenSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Fullscreen")

      VStack(alignment: .leading, spacing: 4) {
        Text("Aspect Ratio")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        SegmentPicker(
          items: CameraFullscreenAspect.allCases,
          label: { $0.label },
          selection: $editorState.cameraFullscreenAspect
        )
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Fill Mode")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        SegmentPicker(
          items: CameraFullscreenFillMode.allCases,
          label: { $0.label },
          selection: $editorState.cameraFullscreenFillMode
        )
      }
    }
    .disabled(!editorState.webcamEnabled || !editorState.cameraRegions.contains { $0.type == .fullscreen })
    .opacity(editorState.webcamEnabled && editorState.cameraRegions.contains { $0.type == .fullscreen } ? 1 : 0.5)
  }

  private var borderColorPickerButton: some View {
    let currentName =
      TailwindColors.all.first { $0.color == editorState.cameraBorderColor }?.name ?? "White"
    return TailwindColorPicker(
      displayColor: Color(cgColor: editorState.cameraBorderColor.cgColor),
      displayName: currentName,
      isSelected: { $0.color == editorState.cameraBorderColor },
      onSelect: { editorState.cameraBorderColor = $0.color }
    )
  }
}
