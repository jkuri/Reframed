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

  enum CameraBackgroundMode: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }
    case none, blur, color, gradient, image

    var label: String {
      switch self {
      case .none: "None"
      case .blur: "Blur"
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
  @State var cameraBackgroundMode: CameraBackgroundMode = .none
  @State var cameraBlurIntensity: CGFloat = 0.5
  @State var selectedCameraGradientId: Int = 0
  @State var selectedCameraColorId: String? = "Black"
  @State var cameraBackgroundImageFilename: String?
  @State var captionSegmentsExpanded: Bool = false
  @State private var screenInfo: MediaFileInfo?
  @State private var webcamInfo: MediaFileInfo?
  @State private var systemAudioInfo: MediaFileInfo?
  @State private var micAudioInfo: MediaFileInfo?

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
          cameraBackgroundSection
          cameraFullscreenSection
        case .audio:
          audioSection
        case .cursor:
          cursorSection
          if editorState.showCursor {
            clickHighlightsSubsection
            cursorMovementSection
          }
        case .zoom:
          zoomSection
        case .captions:
          captionsSection
        }
      }
      .padding(Layout.panelPadding)
    }
    .frame(width: Layout.propertiesPanelWidth)
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
    .onChange(of: cameraBackgroundMode) { _, newValue in
      updateCameraBackgroundStyle(mode: newValue)
    }
    .onChange(of: cameraBlurIntensity) { _, newValue in
      if cameraBackgroundMode == .blur {
        editorState.cameraBackgroundStyle = .blur(newValue)
      }
    }
    .onChange(of: selectedCameraGradientId) { _, newValue in
      if cameraBackgroundMode == .gradient {
        editorState.cameraBackgroundStyle = .gradient(newValue)
      }
    }
    .onChange(of: selectedCameraColorId) { _, newValue in
      if cameraBackgroundMode == .color, let id = newValue,
        let preset = TailwindColors.all.first(where: { $0.id == id })
      {
        editorState.cameraBackgroundStyle = .solidColor(preset.color)
      }
    }
    .onAppear {
      syncBackgroundMode()
      syncCameraBackgroundMode()
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

        InlineEditableText(
          text: editorState.projectName,
          onCommit: { newName in
            editorState.renameProject(newName)
          }
        )
      }

      recordingInfoSection
    }
  }

  private var recordingInfoSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "info.circle", title: "Recording Info")

      VStack(spacing: Layout.compactSpacing) {
        infoRow("Duration", value: formatDuration(editorState.duration))

        if let mode = editorState.project?.metadata.captureMode, mode != .none {
          infoRow("Capture Mode", value: captureModeLabel(mode))
        }

        infoRow("Project Size", value: formattedProjectSize())
        infoRow("Cursor Data", value: editorState.cursorMetadataProvider != nil ? "Yes" : "No")

        if let date = editorState.project?.metadata.createdAt {
          infoRow("Recorded", value: formattedDate(date))
        }
      }

      screenTrackSection
      webcamTrackSection
      systemAudioTrackSection
      micAudioTrackSection
    }
    .task { await loadMediaInfo() }
  }

  private var screenTrackSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "rectangle.on.rectangle", title: "Screen Capture")

      VStack(spacing: Layout.compactSpacing) {
        infoRow("Resolution", value: "\(Int(editorState.result.screenSize.width))x\(Int(editorState.result.screenSize.height))")
        infoRow("FPS", value: "\(editorState.result.fps)")
        infoRow("Codec", value: codecLabel(editorState.result.captureQuality))
        if let info = screenInfo {
          infoRow("Size", value: info.fileSize)
          if let bitrate = info.bitrate {
            infoRow("Bitrate", value: bitrate)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var webcamTrackSection: some View {
    if editorState.result.webcamSize != nil {
      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        SectionHeader(icon: "web.camera", title: "Camera")

        VStack(spacing: Layout.compactSpacing) {
          if let ws = editorState.result.webcamSize {
            infoRow("Resolution", value: "\(Int(ws.width))x\(Int(ws.height))")
          }
          if let info = webcamInfo {
            if let fps = info.fps {
              infoRow("FPS", value: fps)
            }
            infoRow("Size", value: info.fileSize)
            if let bitrate = info.bitrate {
              infoRow("Bitrate", value: bitrate)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var systemAudioTrackSection: some View {
    if editorState.result.systemAudioURL != nil {
      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        SectionHeader(icon: "speaker.wave.2", title: "System Audio")

        VStack(spacing: Layout.compactSpacing) {
          if let info = systemAudioInfo {
            infoRow("Size", value: info.fileSize)
            if let bitrate = info.bitrate {
              infoRow("Bitrate", value: bitrate)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var micAudioTrackSection: some View {
    if editorState.result.microphoneAudioURL != nil {
      VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        SectionHeader(icon: "mic", title: "Microphone")

        VStack(spacing: Layout.compactSpacing) {
          if let info = micAudioInfo {
            infoRow("Size", value: info.fileSize)
            if let bitrate = info.bitrate {
              infoRow("Bitrate", value: bitrate)
            }
          }
        }
      }
    }
  }

  private func loadMediaInfo() async {
    let result = editorState.result
    screenInfo = await MediaFileInfo.load(url: result.screenVideoURL)
    if let url = result.webcamVideoURL {
      webcamInfo = await MediaFileInfo.load(url: url)
    }
    if let url = result.systemAudioURL {
      systemAudioInfo = await MediaFileInfo.load(url: url)
    }
    if let url = result.microphoneAudioURL {
      micAudioInfo = await MediaFileInfo.load(url: url)
    }
  }

  private func codecLabel(_ quality: CaptureQuality) -> String {
    switch quality {
    case .standard: "H.265 (HEVC)"
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

  private func formattedProjectSize() -> String {
    guard let bundleURL = editorState.project?.bundleURL else { return "—" }
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: bundleURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
      return "—"
    }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      if let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
        total += Int64(size)
      }
    }
    return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
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
        .foregroundStyle(ReframedColors.secondaryText)
      Spacer()
      Text(value)
        .font(.system(size: 12))
        .foregroundStyle(ReframedColors.secondaryText)
    }
  }

  var canvasSection: some View {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
      SectionHeader(icon: "rectangle.dashed", title: "Canvas")

      SegmentPicker(
        items: CanvasAspect.allCases,
        label: { $0.label },
        selection: $editorState.canvasAspect
      )
      .onChange(of: editorState.canvasAspect) { _, _ in
        editorState.clampCameraPosition()
      }
    }
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

  private func syncCameraBackgroundMode() {
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

  private func updateCameraBackgroundStyle(mode: CameraBackgroundMode) {
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
