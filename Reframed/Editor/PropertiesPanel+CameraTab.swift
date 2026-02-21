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

      FullWidthSegmentPicker(
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

  var cameraFullscreenSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Fullscreen")

      VStack(alignment: .leading, spacing: 4) {
        Text("Aspect Ratio")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        FullWidthSegmentPicker(
          items: CameraFullscreenAspect.allCases,
          label: { $0.label },
          selection: $editorState.cameraFullscreenAspect
        )
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Fill Mode")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        FullWidthSegmentPicker(
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
