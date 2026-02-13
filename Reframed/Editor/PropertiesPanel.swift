import SwiftUI

struct PropertiesPanel: View {
  @Bindable var editorState: EditorState
  @Environment(\.colorScheme) private var colorScheme

  private enum BackgroundMode: Int, CaseIterable {
    case none, gradient, color

    var label: String {
      switch self {
      case .none: "None"
      case .gradient: "Gradient"
      case .color: "Color"
      }
    }
  }

  @State private var backgroundMode: BackgroundMode = .none
  @State private var selectedGradientId: Int = 0
  @State private var selectedColorId: String? = "Blue"
  @State private var editingProjectName: String = ""
  @State private var showColorPopover = false
  @State private var showClickColorPopover = false
  @FocusState private var projectNameFocused: Bool

  var body: some View {
    let _ = colorScheme
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        projectSection
        backgroundSection
        paddingSection
        cornerRadiusSection
        if editorState.cursorMetadataProvider != nil {
          cursorSection
        }
        if editorState.cursorMetadataProvider != nil {
          zoomSection
        }
        if editorState.hasWebcam {
          pipSection
        }
      }
      .padding(16)
    }
    .frame(width: 260)
    .onChange(of: backgroundMode) { _, newValue in
      updateBackgroundStyle(mode: newValue)
    }
    .onChange(of: selectedGradientId) { _, newValue in
      if backgroundMode == .gradient {
        editorState.backgroundStyle = .gradient(newValue)
      }
    }
    .onChange(of: selectedColorId) { _, newValue in
      if backgroundMode == .color, let id = newValue,
        let preset = TailwindColors.all.first(where: { $0.id == id })
      {
        editorState.backgroundStyle = .solidColor(preset.color)
      }
    }
  }

  private var projectSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader(icon: "doc.text", title: "Project")

      TextField("Project Name", text: $editingProjectName)
        .font(.system(size: 12))
        .foregroundStyle(ReframedColors.primaryText)
        .textFieldStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(ReframedColors.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .focused($projectNameFocused)
        .onSubmit { commitProjectRename() }
        .onChange(of: projectNameFocused) { _, focused in
          if !focused { commitProjectRename() }
        }
        .onAppear { editingProjectName = editorState.projectName }
    }
  }

  private var backgroundSection: some View {
    VStack(alignment: .leading, spacing: 10) {
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

  private var gradientGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
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

  private var solidColorPicker: some View {
    Button {
      showColorPopover.toggle()
    } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(solidColorDisplay)
          .frame(width: 16, height: 16)
        Text(selectedColorId ?? "Blue")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
        Spacer()
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(ReframedColors.dimLabel)
      }
      .padding(.horizontal, 10)
      .frame(height: 30)
      .background(ReframedColors.fieldBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showColorPopover, arrowEdge: .trailing) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(TailwindColors.all) { preset in
            Button {
              selectedColorId = preset.id
              showColorPopover = false
            } label: {
              HStack(spacing: 10) {
                Circle()
                  .fill(preset.swiftUIColor)
                  .frame(width: 18, height: 18)
                Text(preset.name)
                  .font(.system(size: 13))
                  .foregroundStyle(ReframedColors.primaryText)
                Spacer()
                if selectedColorId == preset.id {
                  Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReframedColors.primaryText)
                }
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 5)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 8)
      }
      .frame(width: 200)
      .frame(maxHeight: 320)
    }
  }

  private var solidColorDisplay: Color {
    guard let id = selectedColorId, let preset = TailwindColors.all.first(where: { $0.id == id }) else {
      return TailwindColors.all[0].swiftUIColor
    }
    return preset.swiftUIColor
  }

  private var paddingSection: some View {
    VStack(alignment: .leading, spacing: 10) {
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

      HStack(spacing: 8) {
        Slider(value: $editorState.padding, in: 0...0.20, step: 0.01)
        Text("\(Int(editorState.padding * 100))%")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 36, alignment: .trailing)
      }
    }
  }

  private var cornerRadiusSection: some View {
    VStack(alignment: .leading, spacing: 10) {
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

      HStack(spacing: 8) {
        Slider(value: $editorState.videoCornerRadius, in: 0...40, step: 1)
        Text("\(Int(editorState.videoCornerRadius))px")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 36, alignment: .trailing)
      }
    }
  }

  private var pipSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader(icon: "pip", title: "Picture in Picture")

      HStack(spacing: 4) {
        ForEach(
          Array(
            zip(
              [PiPCorner.topLeft, .topRight, .bottomLeft, .bottomRight],
              ["arrow.up.left", "arrow.up.right", "arrow.down.left", "arrow.down.right"]
            )
          ),
          id: \.1
        ) { corner, icon in
          Button {
            editorState.setPipCorner(corner)
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

      HStack(spacing: 8) {
        Text("Size")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        Slider(value: $editorState.pipLayout.relativeWidth, in: 0.1...1.0, step: 0.01)
          .onChange(of: editorState.pipLayout.relativeWidth) { _, _ in
            editorState.clampPipPosition()
          }
      }

      HStack(spacing: 8) {
        Text("Radius")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        Slider(value: $editorState.pipCornerRadius, in: 0...50, step: 1)
        Text("\(Int(editorState.pipCornerRadius))%")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 36, alignment: .trailing)
      }

      HStack(spacing: 8) {
        Text("Border")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        Slider(value: $editorState.pipBorderWidth, in: 0...10, step: 0.5)
        Text(String(format: "%.1f", editorState.pipBorderWidth))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 36, alignment: .trailing)
      }
    }
  }

  private var cursorSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader(icon: "cursorarrow", title: "Cursor")

      Toggle(isOn: $editorState.showCursor) {
        Text("Show Cursor")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.primaryText)
      }
      .toggleStyle(.switch)
      .controlSize(.mini)

      if editorState.showCursor {
        HStack(spacing: 8) {
          Text("Style")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
          Picker("", selection: $editorState.cursorStyle) {
            ForEach(CursorStyle.allCases, id: \.rawValue) { style in
              Text(style.label).tag(style)
            }
          }
          .pickerStyle(.segmented)
        }

        HStack(spacing: 8) {
          Text("Size")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
          Slider(value: $editorState.cursorSize, in: 16...64, step: 2)
          Text("\(Int(editorState.cursorSize))px")
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: 36, alignment: .trailing)
        }

        HStack(spacing: 8) {
          Text("Smooth")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
          Picker("", selection: $editorState.cursorSmoothing) {
            ForEach(CursorSmoothing.allCases, id: \.rawValue) { level in
              Text(level.label).tag(level)
            }
          }
          .pickerStyle(.segmented)
        }
      }

      clickHighlightsSubsection
    }
  }

  private var clickHighlightsSubsection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader(icon: "cursorarrow.click.2", title: "Click Highlights")

      Toggle(isOn: $editorState.showClickHighlights) {
        Text("Show Click Highlights")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.primaryText)
      }
      .toggleStyle(.switch)
      .controlSize(.mini)

      if editorState.showClickHighlights {
        HStack(spacing: 8) {
          Text("Color")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
          clickColorPickerButton
        }

        HStack(spacing: 8) {
          Text("Size")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.secondaryText)
          Slider(value: $editorState.clickHighlightSize, in: 16...80, step: 2)
          Text("\(Int(editorState.clickHighlightSize))px")
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(ReframedColors.secondaryText)
            .frame(width: 36, alignment: .trailing)
        }
      }
    }
  }

  private var clickColorPickerButton: some View {
    let currentName = TailwindColors.all.first { $0.color == editorState.clickHighlightColor }?.name ?? "Blue"
    return Button {
      showClickColorPopover.toggle()
    } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(Color(cgColor: editorState.clickHighlightColor.cgColor))
          .frame(width: 16, height: 16)
        Text(currentName)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
        Spacer()
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(ReframedColors.dimLabel)
      }
      .padding(.horizontal, 10)
      .frame(height: 30)
      .background(ReframedColors.fieldBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showClickColorPopover, arrowEdge: .trailing) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(TailwindColors.all) { preset in
            Button {
              editorState.clickHighlightColor = preset.color
              showClickColorPopover = false
            } label: {
              HStack(spacing: 10) {
                Circle()
                  .fill(preset.swiftUIColor)
                  .frame(width: 18, height: 18)
                Text(preset.name)
                  .font(.system(size: 13))
                  .foregroundStyle(ReframedColors.primaryText)
                Spacer()
                if editorState.clickHighlightColor == preset.color {
                  Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReframedColors.primaryText)
                }
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 5)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 8)
      }
      .frame(width: 200)
      .frame(maxHeight: 320)
    }
  }

  private var zoomSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader(icon: "plus.magnifyingglass", title: "Zoom")

      Toggle(isOn: $editorState.autoZoomEnabled) {
        Text("Auto Zoom")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.primaryText)
      }
      .toggleStyle(.switch)
      .controlSize(.mini)
      .onChange(of: editorState.autoZoomEnabled) { _, enabled in
        if enabled {
          editorState.generateAutoZoom()
        } else {
          editorState.clearAutoZoom()
        }
      }

      Toggle(isOn: $editorState.zoomFollowCursor) {
        Text("Follow Cursor")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.primaryText)
      }
      .toggleStyle(.switch)
      .controlSize(.mini)

      HStack(spacing: 8) {
        Text("Level")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        Slider(value: $editorState.zoomLevel, in: 1.5...3.0, step: 0.1)
        Text(String(format: "%.1fx", editorState.zoomLevel))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 36, alignment: .trailing)
      }
      .onChange(of: editorState.zoomLevel) { _, _ in
        if editorState.autoZoomEnabled { editorState.generateAutoZoom() }
      }

      HStack(spacing: 8) {
        Text("Speed")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        Slider(value: $editorState.zoomTransitionSpeed, in: 0.1...1.0, step: 0.05)
        Text(String(format: "%.2fs", editorState.zoomTransitionSpeed))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 42, alignment: .trailing)
      }
      .onChange(of: editorState.zoomTransitionSpeed) { _, _ in
        if editorState.autoZoomEnabled { editorState.generateAutoZoom() }
      }

      HStack(spacing: 8) {
        Text("Dwell")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
        Slider(value: $editorState.zoomDwellThreshold, in: 0.2...2.0, step: 0.1)
        Text(String(format: "%.1fs", editorState.zoomDwellThreshold))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 36, alignment: .trailing)
      }
      .onChange(of: editorState.zoomDwellThreshold) { _, _ in
        if editorState.autoZoomEnabled { editorState.generateAutoZoom() }
      }
    }
  }

  private func sectionHeader(icon: String, title: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 11))
        .foregroundStyle(ReframedColors.dimLabel)
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)
    }
  }

  private func commitProjectRename() {
    let trimmed = editingProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != editorState.projectName else {
      editingProjectName = editorState.projectName
      return
    }
    editorState.renameProject(trimmed)
    editingProjectName = editorState.projectName
  }

  private func updateBackgroundStyle(mode: BackgroundMode) {
    switch mode {
    case .none:
      editorState.backgroundStyle = .none
    case .gradient:
      editorState.backgroundStyle = .gradient(selectedGradientId)
    case .color:
      if let id = selectedColorId, let preset = TailwindColors.all.first(where: { $0.id == id }) {
        editorState.backgroundStyle = .solidColor(preset.color)
      } else {
        let first = TailwindColors.all[0]
        selectedColorId = first.id
        editorState.backgroundStyle = .solidColor(first.color)
      }
    }
  }
}
