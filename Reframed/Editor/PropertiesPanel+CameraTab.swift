import SwiftUI

extension PropertiesPanel {
  var cameraSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "pip", title: "Camera")

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

      cameraAspectSection

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
        label: "Border",
        value: $editorState.cameraBorderWidth,
        range: 0...10,
        step: 0.5,
        formattedValue: String(format: "%.1f", editorState.cameraBorderWidth)
      )

      SliderRow(
        label: "Shadow",
        value: $editorState.cameraShadow,
        range: 0...100,
        formattedValue: "\(Int(editorState.cameraShadow))"
      )
    }
  }

  private var cameraAspectSection: some View {
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
}
