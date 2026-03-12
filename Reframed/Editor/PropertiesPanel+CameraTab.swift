import AppKit
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
              .font(.system(size: FontSize.xs))
              .frame(width: 28, height: 28)
              .background(ReframedColors.fieldBackground)
              .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
              .overlay(RoundedRectangle(cornerRadius: Radius.sm).strokeBorder(ReframedColors.border))
          }
          .buttonStyle(SecondaryButtonStyle())
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
    ImageDropSection(
      image: editorState.cameraBackgroundImage,
      onPick: { pickCameraBackgroundImage() },
      onDrop: { url in
        editorState.setCameraBackgroundImage(from: url)
        if case .image(let f) = editorState.cameraBackgroundStyle {
          cameraBackgroundImageFilename = f
        }
      }
    )
  }

  var cameraFullscreenSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Fullscreen")

      VStack(alignment: .leading, spacing: 4) {
        Text("Aspect Ratio")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)
        SegmentPicker(
          items: CameraFullscreenAspect.allCases,
          label: { $0.label },
          selection: $editorState.cameraFullscreenAspect
        )
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Fill Mode")
          .font(.system(size: FontSize.xs))
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
    TailwindColorPicker(
      color: editorState.cameraBorderColor,
      fallbackName: "White",
      onSelect: { editorState.cameraBorderColor = $0 }
    )
  }

  func syncCameraBackgroundMode() {
    switch editorState.cameraBackgroundStyle {
    case .none:
      cameraBackgroundMode = .none
    case .blur(let intensity):
      cameraBackgroundMode = .blur
      cameraBlurIntensity = intensity
    case .solidColor(let color):
      cameraBackgroundMode = .color
      if let preset = TailwindColors.all.first(where: { $0.color == color }) {
        selectedCameraColorId = preset.id
      }
    case .gradient(let id):
      cameraBackgroundMode = .gradient
      selectedCameraGradientId = id
    case .image(let filename):
      cameraBackgroundMode = .image
      cameraBackgroundImageFilename = filename
    }
  }

  func updateCameraBackgroundStyle(mode: CameraBackgroundMode) {
    switch mode {
    case .none:
      editorState.cameraBackgroundStyle = .none
    case .blur:
      editorState.cameraBackgroundStyle = .blur(cameraBlurIntensity)
    case .color:
      if let id = selectedCameraColorId, let preset = TailwindColors.all.first(where: { $0.id == id }) {
        editorState.cameraBackgroundStyle = .solidColor(preset.color)
      } else {
        let first = TailwindColors.all[0]
        selectedCameraColorId = first.id
        editorState.cameraBackgroundStyle = .solidColor(first.color)
      }
    case .gradient:
      editorState.cameraBackgroundStyle = .gradient(selectedCameraGradientId)
    case .image:
      if case .image = editorState.cameraBackgroundStyle {
        return
      }
      if let filename = cameraBackgroundImageFilename {
        editorState.cameraBackgroundStyle = .image(filename)
      }
    }
  }

  func pickCameraBackgroundImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
      guard response == .OK, let url = panel.url else { return }
      DispatchQueue.main.async {
        self.editorState.setCameraBackgroundImage(from: url)
        if case .image(let f) = self.editorState.cameraBackgroundStyle {
          self.cameraBackgroundImageFilename = f
        }
      }
    }
  }
}
