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
  @State private var solidColor: Color = .blue
  @State private var editingProjectName: String = ""
  @FocusState private var projectNameFocused: Bool

  var body: some View {
    let _ = colorScheme
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        projectSection
        backgroundSection
        paddingSection
        cornerRadiusSection
        if editorState.hasWebcam {
          pipSection
        }
      }
      .padding(16)
    }
    .frame(width: 260)
    .background(FrameColors.panelBackground)
    .onChange(of: backgroundMode) { _, newValue in
      updateBackgroundStyle(mode: newValue)
    }
    .onChange(of: selectedGradientId) { _, newValue in
      if backgroundMode == .gradient {
        editorState.backgroundStyle = .gradient(newValue)
      }
    }
    .onChange(of: solidColor) { _, newValue in
      if backgroundMode == .color {
        editorState.backgroundStyle = .solidColor(CodableColor(cgColor: NSColor(newValue).cgColor))
      }
    }
  }

  private var projectSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader(icon: "doc.text", title: "Project")

      TextField("Project Name", text: $editingProjectName)
        .font(.system(size: 12))
        .foregroundStyle(FrameColors.primaryText)
        .textFieldStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(FrameColors.fieldBackground)
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
        ColorPicker("Color", selection: $solidColor, supportsOpacity: false)
          .font(.system(size: 12))
          .foregroundStyle(FrameColors.secondaryText)
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
          .foregroundStyle(FrameColors.dimLabel)
          .buttonStyle(.plain)
        }
      }

      HStack(spacing: 8) {
        Slider(value: $editorState.padding, in: 0...0.20, step: 0.01)
        Text("\(Int(editorState.padding * 100))%")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(FrameColors.secondaryText)
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
          .foregroundStyle(FrameColors.dimLabel)
          .buttonStyle(.plain)
        }
      }

      HStack(spacing: 8) {
        Slider(value: $editorState.videoCornerRadius, in: 0...40, step: 1)
        Text("\(Int(editorState.videoCornerRadius))px")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(FrameColors.secondaryText)
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
              .background(FrameColors.fieldBackground)
              .clipShape(RoundedRectangle(cornerRadius: 4))
          }
          .buttonStyle(.plain)
          .foregroundStyle(FrameColors.primaryText)
        }
      }

      HStack(spacing: 8) {
        Text("Size")
          .font(.system(size: 12))
          .foregroundStyle(FrameColors.secondaryText)
        Slider(value: $editorState.pipLayout.relativeWidth, in: 0.1...0.5, step: 0.01)
      }

      HStack(spacing: 8) {
        Text("Radius")
          .font(.system(size: 12))
          .foregroundStyle(FrameColors.secondaryText)
        Slider(value: $editorState.pipCornerRadius, in: 0...40, step: 1)
        Text("\(Int(editorState.pipCornerRadius))px")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(FrameColors.secondaryText)
          .frame(width: 36, alignment: .trailing)
      }

      HStack(spacing: 8) {
        Text("Border")
          .font(.system(size: 12))
          .foregroundStyle(FrameColors.secondaryText)
        Slider(value: $editorState.pipBorderWidth, in: 0...10, step: 0.5)
        Text(String(format: "%.1f", editorState.pipBorderWidth))
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(FrameColors.secondaryText)
          .frame(width: 36, alignment: .trailing)
      }
    }
  }

  private func sectionHeader(icon: String, title: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 11))
        .foregroundStyle(FrameColors.dimLabel)
      Text(title)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(FrameColors.primaryText)
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
      editorState.backgroundStyle = .solidColor(CodableColor(cgColor: NSColor(solidColor).cgColor))
    }
  }
}
