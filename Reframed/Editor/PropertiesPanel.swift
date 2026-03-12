import AVFoundation
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
  @State var screenInfo: MediaFileInfo?
  @State var webcamInfo: MediaFileInfo?
  @State var systemAudioInfo: MediaFileInfo?
  @State var micAudioInfo: MediaFileInfo?
  @State var clickSoundPreviewPlayer: AVAudioPlayer?

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
          clickSoundSection
        case .cursor:
          cursorSection
          if editorState.showCursor {
            clickHighlightsSubsection
            cursorMovementSection
          }
        case .zoom:
          zoomSection
        case .effects:
          spotlightSection
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

}
