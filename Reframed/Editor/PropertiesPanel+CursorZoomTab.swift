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
            Image(nsImage: CursorRenderer.previewImage(for: style, size: 42))
              .frame(width: 42, height: 42)
              .background(ReframedColors.fieldBackground)
              .clipShape(RoundedRectangle(cornerRadius: 5))
              .overlay(
                RoundedRectangle(cornerRadius: 5)
                  .stroke(isSelected ? ReframedColors.controlAccentColor : Color.clear, lineWidth: 2)
              )
            Text(style.label)
              .font(.system(size: 8, weight: isSelected ? .semibold : .regular))
              .foregroundStyle(isSelected ? ReframedColors.primaryText : ReframedColors.secondaryText)
              .lineLimit(1)
          }
        }
        .buttonStyle(.plain)
      }
    }
  }

  var cursorSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "cursorarrow", title: "Cursor")

      toggleRow("Show Cursor", isOn: $editorState.showCursor)

      if editorState.showCursor {
        cursorStyleGrid

        SliderRow(
          label: "Size",
          labelWidth: Layout.labelWidth,
          value: $editorState.cursorSize,
          range: 16...64,
          step: 2,
          formattedValue: "\(Int(editorState.cursorSize))px"
        )
      }
    }
  }

  var clickHighlightsSubsection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "cursorarrow.click.2", title: "Click Highlights")

      toggleRow("Show Highlights", isOn: $editorState.showClickHighlights)

      if editorState.showClickHighlights {
        HStack(spacing: 8) {
          Text("Color")
            .font(.system(size: 12))
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
    let currentName = TailwindColors.all.first { $0.color == editorState.clickHighlightColor }?.name ?? "Blue"
    return TailwindColorPicker(
      displayColor: Color(cgColor: editorState.clickHighlightColor.cgColor),
      displayName: currentName,
      isPresented: $showClickColorPopover,
      isSelected: { $0.color == editorState.clickHighlightColor },
      onSelect: { editorState.clickHighlightColor = $0.color }
    )
  }

  func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 12))
        .foregroundStyle(ReframedColors.primaryText)
      Spacer()
      Toggle("", isOn: isOn)
        .toggleStyle(.switch)
        .controlSize(.mini)
        .labelsHidden()
    }
  }

  var zoomSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "plus.magnifyingglass", title: "Zoom")

      toggleRow("Enable Zoom", isOn: $editorState.zoomEnabled)
        .onChange(of: editorState.zoomEnabled) { _, enabled in
          if !enabled {
            editorState.autoZoomEnabled = false
            editorState.zoomTimeline = nil
          }
        }

      if editorState.zoomEnabled {
        toggleRow("Follow Cursor", isOn: $editorState.zoomFollowCursor)

        toggleRow("Auto Zoom", isOn: $editorState.autoZoomEnabled)
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
            range: 0.1...2.0,
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
            range: 0.5...5.0,
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
