import SwiftUI

struct PropertiesPanel: View {
  @Bindable var editorState: EditorState
  let selectedTab: EditorTab
  @Environment(\.colorScheme) private var colorScheme

  enum BackgroundMode: Int, CaseIterable {
    case none, gradient, color

    var label: String {
      switch self {
      case .none: "None"
      case .gradient: "Gradient"
      case .color: "Color"
      }
    }
  }

  @State var backgroundMode: BackgroundMode = .none
  @State var selectedGradientId: Int = 0
  @State var selectedColorId: String? = "Blue"
  @State private var editingProjectName: String = ""
  @State var showColorPopover = false
  @State var showClickColorPopover = false
  @FocusState private var projectNameFocused: Bool

  var body: some View {
    let _ = colorScheme
    ScrollView {
      VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
        switch selectedTab {
        case .general:
          projectSection
        case .video:
          canvasSection
          backgroundSection
          paddingSection
          cornerRadiusSection
        case .camera:
          cameraSection
        case .cursor:
          cursorSection
          if editorState.showCursor {
            clickHighlightsSubsection
          }
        case .zoom:
          zoomSection
        }
      }
      .padding(Layout.panelPadding)
    }
    .frame(width: 300)
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
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        sectionHeader(icon: "doc.text", title: "Project")

        HStack(spacing: 6) {
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

          Button("Rename") { commitProjectRename() }
            .font(.system(size: 12, weight: .medium))
            .disabled(isRenameDisabled)
            .opacity(isRenameDisabled ? 0.4 : 1.0)
        }
      }

      recordingInfoSection
    }
  }

  private var isRenameDisabled: Bool {
    let trimmed = editingProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty || trimmed == editorState.projectName
  }

  private var recordingInfoSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "info.circle", title: "Recording Info")

      VStack(spacing: Layout.compactSpacing) {
        infoRow("Resolution", value: "\(Int(editorState.result.screenSize.width))x\(Int(editorState.result.screenSize.height))")
        infoRow("FPS", value: "\(editorState.result.fps)")
        infoRow("Duration", value: formatDuration(editorState.duration))

        if let ws = editorState.result.webcamSize {
          infoRow("Webcam", value: "\(Int(ws.width))x\(Int(ws.height))")
        }

        infoRow("System Audio", value: editorState.result.systemAudioURL != nil ? "Yes" : "No")
        infoRow("Microphone", value: editorState.result.microphoneAudioURL != nil ? "Yes" : "No")
        infoRow("Cursor Data", value: editorState.cursorMetadataProvider != nil ? "Yes" : "No")
      }
    }
  }

  private func infoRow(_ label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(ReframedColors.dimLabel)
      Spacer()
      Text(value)
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(ReframedColors.secondaryText)
    }
  }

  var canvasSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      sectionHeader(icon: "rectangle.dashed", title: "Canvas")

      Picker("", selection: $editorState.canvasAspect) {
        ForEach(CanvasAspect.allCases) { aspect in
          Text(aspect.label).tag(aspect)
        }
      }
      .pickerStyle(.segmented)
    }
  }

  func sectionHeader(icon: String, title: String) -> some View {
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
