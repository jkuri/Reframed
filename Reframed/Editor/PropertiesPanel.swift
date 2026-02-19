import SwiftUI
import UniformTypeIdentifiers

struct PropertiesPanel: View {
  @Bindable var editorState: EditorState
  let selectedTab: EditorTab
  @Environment(\.colorScheme) private var colorScheme

  enum BackgroundMode: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }
    case color, gradient, image

    var label: String {
      switch self {
      case .color: "Color"
      case .gradient: "Gradient"
      case .image: "Image"
      }
    }
  }

  @State var backgroundMode: BackgroundMode = .color
  @State var selectedGradientId: Int = 0
  @State var selectedColorId: String? = "Black"
  @State var backgroundImageFilename: String?
  @State private var editingProjectName: String = ""
  @State var showClickColorPopover = false
  @State var showBorderColorPopover = false
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
          paddingSection
          cornerRadiusSection
          videoShadowSection
          backgroundSection
        case .camera:
          cameraSection
          cameraPositionSection
          cameraAspectRatioSection
          cameraStyleSection
          cameraFullscreenSection
        case .audio:
          audioSection
        case .cursor:
          cursorSection
          if editorState.showCursor {
            clickHighlightsSubsection
          }
        case .zoom:
          zoomSection
        case .animations:
          cursorMovementSection
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
    .onAppear {
      syncBackgroundMode()
    }
  }

  private func syncBackgroundMode() {
    switch editorState.backgroundStyle {
    case .none:
      backgroundMode = .color
      selectedColorId = "Black"
      editorState.backgroundStyle = .solidColor(CodableColor(r: 0, g: 0, b: 0))
    case .gradient(let id):
      backgroundMode = .gradient
      selectedGradientId = id
    case .solidColor(let color):
      backgroundMode = .color
      if let preset = TailwindColors.all.first(where: { $0.color == color }) {
        selectedColorId = preset.id
      }
    case .image(let filename):
      backgroundMode = .image
      backgroundImageFilename = filename
    }
  }

  private var projectSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        SectionHeader(icon: "doc.text", title: "Project")

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
            .onAppear {
              editingProjectName = editorState.projectName
              Task { @MainActor in
                projectNameFocused = false
              }
            }

          Button("Rename") {
            commitProjectRename()
            projectNameFocused = false
          }
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.white)
          .background(ReframedColors.controlAccentColor)
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .disabled(isRenameDisabled)
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
      SectionHeader(icon: "info.circle", title: "Recording Info")

      VStack(spacing: Layout.compactSpacing) {
        infoRow("Resolution", value: "\(Int(editorState.result.screenSize.width))x\(Int(editorState.result.screenSize.height))")
        infoRow("FPS", value: "\(editorState.result.fps)")
        infoRow("Codec", value: codecLabel(editorState.result.captureQuality))
        infoRow("Duration", value: formatDuration(editorState.duration))

        if let mode = editorState.project?.metadata.captureMode, mode != .none {
          infoRow("Capture Mode", value: captureModeLabel(mode))
        }

        infoRow("File Size", value: formattedFileSize(url: editorState.result.screenVideoURL))

        if let ws = editorState.result.webcamSize {
          infoRow("Webcam", value: "\(Int(ws.width))x\(Int(ws.height))")
        }

        infoRow("System Audio", value: editorState.result.systemAudioURL != nil ? "Yes" : "No")
        infoRow("Microphone", value: editorState.result.microphoneAudioURL != nil ? "Yes" : "No")
        infoRow("Cursor Data", value: editorState.cursorMetadataProvider != nil ? "Yes" : "No")

        if let date = editorState.project?.metadata.createdAt {
          infoRow("Recorded", value: formattedDate(date))
        }
      }
    }
  }

  private func codecLabel(_ quality: CaptureQuality) -> String {
    switch quality {
    case .standard: "H.264"
    case .high: "ProRes 422"
    case .veryHigh: "ProRes 4444"
    }
  }

  private func captureModeLabel(_ mode: CaptureMode) -> String {
    switch mode {
    case .none: "None"
    case .entireScreen: "Entire Screen"
    case .selectedWindow: "Window"
    case .selectedArea: "Area"
    case .device: "iOS Device"
    }
  }

  private func formattedFileSize(url: URL) -> String {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attrs[.size] as? Int64
    else {
      return "—"
    }
    return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
  }

  private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  private func infoRow(_ label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 12))
        .foregroundStyle(ReframedColors.dimLabel)
      Spacer()
      Text(value)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(ReframedColors.secondaryText)
    }
  }

  var canvasSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "rectangle.dashed", title: "Canvas")

      Picker("", selection: $editorState.canvasAspect) {
        ForEach(CanvasAspect.allCases) { aspect in
          Text(aspect.label).tag(aspect)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .onChange(of: editorState.canvasAspect) { _, _ in
        editorState.clampCameraPosition()
      }
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
    case .image:
      if case .image = editorState.backgroundStyle {
        return
      }
      if let filename = backgroundImageFilename {
        editorState.backgroundStyle = .image(filename)
      }
    }
  }

  func pickBackgroundImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
      guard response == .OK, let url = panel.url else { return }
      DispatchQueue.main.async {
        self.editorState.setBackgroundImage(from: url)
        if case .image(let f) = self.editorState.backgroundStyle {
          self.backgroundImageFilename = f
        }
      }
    }
  }
}
