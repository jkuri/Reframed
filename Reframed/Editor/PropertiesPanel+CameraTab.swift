import SwiftUI

extension PropertiesPanel {
  var cameraSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "web.camera", title: "Camera")

      toggleRow("Enabled", isOn: $editorState.webcamEnabled)

      toggleRow("Mirror", isOn: $editorState.cameraMirrored)
        .disabled(!editorState.webcamEnabled)
        .opacity(editorState.webcamEnabled ? 1 : 0.5)
    }
  }

  var cameraPositionSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "Position")

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
              .clipShape(RoundedRectangle(cornerRadius: 4))
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
      sectionHeader(icon: "aspectratio", title: "Aspect Ratio")

      Picker("", selection: $editorState.cameraAspect) {
        ForEach(CameraAspect.allCases) { aspect in
          Text(aspect.label).tag(aspect)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .onChange(of: editorState.cameraAspect) { _, _ in
        editorState.clampCameraPosition()
      }
    }
    .disabled(!editorState.webcamEnabled)
    .opacity(editorState.webcamEnabled ? 1 : 0.5)
  }

  var cameraStyleSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "paintbrush", title: "Style")

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
      sectionHeader(icon: "arrow.up.left.and.arrow.down.right", title: "Fullscreen")

      VStack(alignment: .leading, spacing: 4) {
        Text("Aspect Ratio")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        Picker("", selection: $editorState.cameraFullscreenAspect) {
          ForEach(CameraFullscreenAspect.allCases) { aspect in
            Text(aspect.label).tag(aspect)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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
    .disabled(!editorState.webcamEnabled || editorState.cameraFullscreenRegions.isEmpty)
    .opacity(editorState.webcamEnabled && !editorState.cameraFullscreenRegions.isEmpty ? 1 : 0.5)
  }

  private var borderColorPickerButton: some View {
    let currentName =
      TailwindColors.all.first { $0.color == editorState.cameraBorderColor }?.name ?? "White"
    return TailwindColorPicker(
      displayColor: Color(cgColor: editorState.cameraBorderColor.cgColor),
      displayName: currentName,
      isPresented: $showBorderColorPopover,
      isSelected: { $0.color == editorState.cameraBorderColor },
      onSelect: { editorState.cameraBorderColor = $0.color }
    )
  }
}
