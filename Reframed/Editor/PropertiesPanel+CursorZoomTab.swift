import SwiftUI

extension PropertiesPanel {
  var cursorStyleGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
      ForEach(CursorStyle.allCases, id: \.rawValue) { style in
        let isSelected = editorState.cursorStyle == style
        Button {
          editorState.cursorStyle = style
        } label: {
          VStack(spacing: 3) {
            Image(
              nsImage: CursorRenderer.previewImage(
                for: style,
                size: 42,
                fillColor: editorState.cursorFillColor,
                strokeColor: editorState.cursorStrokeColor
              )
            )
            .frame(width: 42, height: 42)
            .background(ReframedColors.muted)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
              RoundedRectangle(cornerRadius: Radius.md)
                .stroke(isSelected ? ReframedColors.ring : Color.clear, lineWidth: 2)
            )
            Text(style.label)
              .font(.system(size: FontSize.xs, weight: isSelected ? .semibold : .regular))
              .foregroundStyle(isSelected ? ReframedColors.primaryText : ReframedColors.secondaryText)
              .lineLimit(1)
          }
        }
        .buttonStyle(PlainCustomButtonStyle())
      }
    }
  }

  var cursorSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "cursorarrow", title: "Cursor")

      ToggleRow(label: "Show Cursor", isOn: $editorState.showCursor)

      if editorState.showCursor {
        ToggleRow(label: "System Cursor", isOn: $editorState.useSystemCursor)

        if !editorState.useSystemCursor {
          cursorStyleGrid
        }

        SliderRow(
          label: "Size",
          labelWidth: Layout.labelWidth,
          value: $editorState.cursorSize,
          range: 16...128,
          step: 2,
          formattedValue: "\(Int(editorState.cursorSize))px",
          valueWidth: Layout.labelWidth
        )

        if !editorState.useSystemCursor {
          HStack(spacing: 8) {
            Text("Fill")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(ReframedColors.secondaryText)
              .frame(width: Layout.labelWidth, alignment: .leading)
            cursorFillColorPicker
          }

          HStack(spacing: 8) {
            Text("Stroke")
              .font(.system(size: FontSize.xs))
              .foregroundStyle(ReframedColors.secondaryText)
              .frame(width: Layout.labelWidth, alignment: .leading)
            cursorStrokeColorPicker
          }
        }
      }
    }
  }

  var cursorFillColorPicker: some View {
    TailwindColorPicker(
      color: editorState.cursorFillColor,
      fallbackName: "White",
      onSelect: { editorState.cursorFillColor = $0 }
    )
  }

  var cursorStrokeColorPicker: some View {
    TailwindColorPicker(
      color: editorState.cursorStrokeColor,
      fallbackName: "Black",
      onSelect: { editorState.cursorStrokeColor = $0 }
    )
  }

  var clickHighlightsSubsection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "cursorarrow.click.2", title: "Click Highlights")

      ToggleRow(label: "Show Highlights", isOn: $editorState.showClickHighlights)

      if editorState.showClickHighlights {
        HStack(spacing: 8) {
          Text("Color")
            .font(.system(size: FontSize.xs))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: Layout.labelWidth, alignment: .leading)
          clickColorPickerButton
        }

        SliderRow(
          label: "Size",
          labelWidth: Layout.labelWidth,
          value: $editorState.clickHighlightSize,
          range: 16...80,
          step: 2,
          formattedValue: "\(Int(editorState.clickHighlightSize))px"
        )
      }
    }
  }

  var clickColorPickerButton: some View {
    TailwindColorPicker(
      color: editorState.clickHighlightColor,
      fallbackName: "Black",
      onSelect: { editorState.clickHighlightColor = $0 }
    )
  }

  var cursorEffectsSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "sparkles", title: "Cursor Effects")

      SliderRow(
        label: "Click Bounce",
        labelWidth: 82,
        value: $editorState.clickBounce,
        range: 0...10,
        step: 0.5,
        formattedValue: String(format: "%.1f", editorState.clickBounce),
        valueWidth: 36
      )

      SliderRow(
        label: "Sway",
        labelWidth: 82,
        value: $editorState.cursorSway,
        range: 0...2,
        step: 0.05,
        formattedValue: String(format: "%.2f", editorState.cursorSway),
        valueWidth: 36
      )

      SliderRow(
        label: "Motion Blur",
        labelWidth: 82,
        value: $editorState.cursorMotionBlur,
        range: 0...5,
        step: 0.1,
        formattedValue: String(format: "%.1f", editorState.cursorMotionBlur),
        valueWidth: 36
      )
    }
  }

  var cursorMovementSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "cursorarrow.motionlines", title: "Cursor Movement")

      ToggleRow(label: "Smooth Movement", isOn: $editorState.cursorMovementEnabled)
        .onChange(of: editorState.cursorMovementEnabled) { _, _ in
          editorState.regenerateSmoothedCursor()
        }

      if editorState.cursorMovementEnabled {
        VStack(alignment: .leading, spacing: Layout.compactSpacing) {
          Text("Speed")
            .font(.system(size: FontSize.xs))
            .foregroundStyle(ReframedColors.secondaryText)

          SegmentPicker(
            items: CursorMovementSpeed.allCases,
            label: { $0.label },
            selection: $editorState.cursorMovementSpeed
          )
          .onChange(of: editorState.cursorMovementSpeed) { _, _ in
            editorState.regenerateSmoothedCursor()
          }
        }

        springParametersInfo
      }
    }
  }

  private var springParametersInfo: some View {
    let speed = editorState.cursorMovementSpeed
    return VStack(spacing: Layout.compactSpacing) {
      infoParam("Tension", value: String(format: "%.0f", speed.tension))
      infoParam("Friction", value: String(format: "%.0f", speed.friction))
      infoParam("Mass", value: String(format: "%.1f", speed.mass))
    }
    .padding(.top, 4)
  }

  private func infoParam(_ label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: FontSize.xs))
        .foregroundStyle(ReframedColors.secondaryText)
      Spacer()
      Text(value)
        .font(.system(size: FontSize.xs, design: .monospaced))
        .foregroundStyle(ReframedColors.secondaryText)
    }
  }

  var zoomSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "plus.magnifyingglass", title: "Zoom")

      ToggleRow(label: "Enable Zoom", isOn: $editorState.zoomEnabled)
        .onChange(of: editorState.zoomEnabled) { _, enabled in
          if !enabled {
            editorState.autoZoomEnabled = false
            editorState.zoomTimeline = nil
          }
        }

      if editorState.zoomEnabled {
        ToggleRow(label: "Follow Cursor", isOn: $editorState.zoomFollowCursor)

        ToggleRow(label: "Auto Zoom", isOn: $editorState.autoZoomEnabled)
          .onChange(of: editorState.autoZoomEnabled) { _, enabled in
            if enabled {
              editorState.generateAutoZoom()
            } else {
              editorState.clearAutoZoom()
            }
          }

        if editorState.autoZoomEnabled {
          SliderRow(
            label: "Level",
            labelWidth: Layout.labelWidth,
            value: $editorState.zoomLevel,
            range: 1.5...5.0,
            step: 0.1,
            formattedValue: String(format: "%.1fx", editorState.zoomLevel),
            valueWidth: 40
          )
          .onChange(of: editorState.zoomLevel) { _, _ in
            editorState.generateAutoZoom()
          }

          SliderRow(
            label: "Speed",
            labelWidth: Layout.labelWidth,
            value: $editorState.zoomTransitionSpeed,
            range: 0.1...4.0,
            step: 0.05,
            formattedValue: String(format: "%.2fs", editorState.zoomTransitionSpeed),
            valueWidth: 40
          )
          .onChange(of: editorState.zoomTransitionSpeed) { _, _ in
            editorState.generateAutoZoom()
          }

          SliderRow(
            label: "Hold",
            labelWidth: Layout.labelWidth,
            value: $editorState.zoomDwellThreshold,
            range: 0.5...10.0,
            step: 0.1,
            formattedValue: String(format: "%.1fs", editorState.zoomDwellThreshold),
            valueWidth: 40
          )
          .onChange(of: editorState.zoomDwellThreshold) { _, _ in
            editorState.generateAutoZoom()
          }
        }
      }
    }
  }
}
