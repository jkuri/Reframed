import CoreMedia
import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
  case general, video, camera, audio, cursor, zoom, effects, captions

  var id: String { rawValue }

  var label: String {
    switch self {
    case .general: "General"
    case .video: "Video"
    case .camera: "Camera"
    case .audio: "Audio"
    case .cursor: "Cursor"
    case .zoom: "Zoom"
    case .effects: "Effects"
    case .captions: "Captions"
    }
  }

  var icon: String {
    switch self {
    case .general: "slider.horizontal.3"
    case .video: "play.rectangle"
    case .camera: "web.camera"
    case .audio: "speaker.wave.2"
    case .cursor: "cursorarrow"
    case .zoom: "plus.magnifyingglass"
    case .effects: "wand.and.stars"
    case .captions: "captions.bubble"
    }
  }

  static let isAppleSilicon: Bool = {
    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
    return machine.hasPrefix("arm64")
  }()

  static var availableCases: [EditorTab] {
    if isAppleSilicon {
      return allCases
    }
    return allCases.filter { $0 != .captions }
  }
}

struct EditorView: View {
  @Bindable var editorState: EditorState
  @State private var systemWaveformGenerator = AudioWaveformGenerator()
  @State private var micWaveformGenerator = AudioWaveformGenerator()
  @State private var selectedTab: EditorTab = .general
  @State private var micWaveformTask: Task<Void, Never>?
  @State private var didFinishSetup = false
  @State var showHistoryPopover = false
  @State var timelineZoom: CGFloat = 1.0
  @State var baseZoom: CGFloat = 1.0
  @Environment(\.colorScheme) private var colorScheme

  let onDelete: () -> Void

  private var timelineTrackSignature: Int {
    var h = 0
    if editorState.hasWebcam && editorState.webcamEnabled { h |= 1 }
    if !editorState.systemAudioMuted { h |= 2 }
    if !editorState.micAudioMuted { h |= 4 }
    if editorState.zoomEnabled { h |= 8 }
    if editorState.spotlightEnabled { h |= 16 }
    return h
  }

  var body: some View {
    let _ = colorScheme
    VStack(spacing: 0) {
      if editorState.isPreviewMode {
        mainContent
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        EditorTopBar(
          editorState: editorState,
          onOpenFolder: { editorState.openProjectFolder() },
          onDelete: { editorState.showDeleteConfirmation = true }
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 2)

        HStack(spacing: 8) {
          mainContent
            .background(ReframedColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
            .overlay(RoundedRectangle(cornerRadius: Radius.xxl).strokeBorder(ReframedColors.border, lineWidth: 1))
          editorSidebar
            .background(ReframedColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
            .overlay(RoundedRectangle(cornerRadius: Radius.xxl).strokeBorder(ReframedColors.border, lineWidth: 1))
          PropertiesPanel(editorState: editorState, selectedTab: selectedTab)
            .background(ReframedColors.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
            .overlay(RoundedRectangle(cornerRadius: Radius.xxl).strokeBorder(ReframedColors.border, lineWidth: 1))
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
      }

      transportBar
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, editorState.isPreviewMode ? 12 : 0)

      if !editorState.isPreviewMode {
        timeline
          .fixedSize(horizontal: false, vertical: true)
          .background(ReframedColors.backgroundCard)
          .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
          .overlay(RoundedRectangle(cornerRadius: Radius.xxl).strokeBorder(ReframedColors.border, lineWidth: 1))
          .padding(.horizontal, 12)
          .padding(.top, 12)
          .padding(.bottom, 12)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: timelineTrackSignature)
    .background {
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture {
          DispatchQueue.main.async {
            NSApp.keyWindow?.makeFirstResponder(nil)
          }
        }
    }
    .ignoresSafeArea(edges: .top)
    .frame(minWidth: Layout.editorWindowMinWidth, minHeight: Layout.editorWindowMinHeight)
    .background(ReframedColors.background)
    .task {
      await editorState.setup()
      didFinishSetup = true
      if editorState.result.microphoneAudioURL != nil {
        regenerateMicWaveform()
      }
      if let url = editorState.result.systemAudioURL {
        await systemWaveformGenerator.generate(from: url)
      }
    }
    .onChange(of: editorState.micNoiseReductionEnabled) { _, _ in
      guard didFinishSetup else { return }
      editorState.syncNoiseReduction()
    }
    .onChange(of: editorState.micNoiseReductionIntensity) { _, _ in
      guard didFinishSetup else { return }
      editorState.syncNoiseReduction()
    }
    .onChange(of: editorState.processedMicAudioURL) { _, _ in
      guard didFinishSetup else { return }
      regenerateMicWaveform()
    }
    .sheet(isPresented: $editorState.showExportSheet) {
      ExportSheet(
        editorState: editorState,
        isPresented: $editorState.showExportSheet
      )
    }
    .alert("Delete Recording?", isPresented: $editorState.showDeleteConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive) {
        editorState.deleteRecording()
        onDelete()
      }
    } message: {
      Text("This will permanently delete the source recording files.")
    }
  }

  private var editorSidebar: some View {
    VStack(spacing: 0) {
      HoverEffectScope {
        VStack(spacing: 2) {
          ForEach(EditorTab.availableCases) { tab in
            let disabled =
              (tab == .camera && !editorState.hasWebcam)
              || (tab == .audio && !editorState.hasSystemAudio && !editorState.hasMicAudio)
              || (tab == .cursor && editorState.cursorMetadataProvider == nil)
              || (tab == .zoom && editorState.cursorMetadataProvider == nil)
              || (tab == .captions && !editorState.hasMicAudio && !editorState.hasSystemAudio)
            Button {
              selectedTab = tab
            } label: {
              VStack(spacing: 3) {
                Image(systemName: tab.icon)
                  .font(.system(size: FontSize.base))
                  .foregroundStyle(ReframedColors.primaryText)
                Text(tab.label)
                  .font(.system(size: FontSize.xxs, weight: .semibold))
                  .foregroundStyle(selectedTab == tab ? ReframedColors.primaryText : ReframedColors.secondaryText)
              }
              .frame(width: 56, height: 48)
              .background(
                selectedTab == tab ? ReframedColors.muted : Color.clear,
                in: RoundedRectangle(cornerRadius: Radius.lg)
              )
              .contentShape(Rectangle())
              .opacity(disabled ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .hoverEffect(id: "tab.\(tab.rawValue)")
            .disabled(disabled)
          }
        }
      }
      Spacer()
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
  }

  private var mainContent: some View {
    videoPreview
      .frame(maxHeight: .infinity)
  }

  private var videoPreview: some View {
    let screenSize = editorState.result.screenSize
    let hasNonDefaultBg: Bool = {
      switch editorState.backgroundStyle {
      case .none: return false
      case .solidColor: return true
      case .gradient, .image: return true
      }
    }()
    let hasEffects =
      hasNonDefaultBg || editorState.canvasAspect != .original
      || editorState.padding > 0 || editorState.videoCornerRadius > 0
      || editorState.videoShadow > 0
    let canvasAspect: CGFloat = {
      let canvas = editorState.canvasSize(for: screenSize)
      return canvas.width / max(canvas.height, 1)
    }()

    return GeometryReader { geo in
      ZStack {
        if hasEffects {
          backgroundView
        }

        VideoPreviewView(
          screenPlayer: editorState.playerController.screenPlayer,
          webcamPlayer: editorState.webcamEnabled ? editorState.playerController.webcamPlayer : nil,
          cameraLayout: effectiveCameraLayoutBinding,
          webcamSize: editorState.webcamEnabled ? editorState.result.webcamSize : nil,
          screenSize: screenSize,
          canvasSize: editorState.canvasSize(for: screenSize),
          padding: editorState.padding,
          videoCornerRadius: editorState.videoCornerRadius,
          cameraAspect: editorState.cameraAspect,
          cameraCornerRadius: editorState.cameraCornerRadius,
          cameraBorderWidth: editorState.cameraBorderWidth,
          cameraBorderColor: editorState.cameraBorderColor.cgColor,
          videoShadow: editorState.videoShadow,
          cameraShadow: editorState.cameraShadow,
          cameraMirrored: editorState.cameraMirrored,
          cursorMetadataProvider: editorState.activeCursorProvider,
          showCursor: editorState.showCursor,
          cursorStyle: editorState.cursorStyle,
          cursorSize: editorState.cursorSize,
          cursorFillColor: editorState.cursorFillColor,
          cursorStrokeColor: editorState.cursorStrokeColor,
          showClickHighlights: editorState.showClickHighlights,
          clickHighlightColor: editorState.clickHighlightColor.cgColor,
          clickHighlightSize: editorState.clickHighlightSize,
          zoomFollowCursor: editorState.zoomFollowCursor,
          currentTime: CMTimeGetSeconds(editorState.currentTime),
          zoomTimeline: editorState.zoomTimeline,
          cameraFullscreenRegions: editorState.webcamEnabled
            ? editorState.cameraRegions.filter { $0.type == .fullscreen }.map { r in
              (
                start: r.startSeconds, end: r.endSeconds,
                entryTransition: r.entryTransition ?? .none,
                entryDuration: r.entryTransitionDuration ?? 0.3,
                exitTransition: r.exitTransition ?? .none,
                exitDuration: r.exitTransitionDuration ?? 0.3
              )
            } : [],
          cameraHiddenRegions: editorState.webcamEnabled
            ? editorState.cameraRegions.filter { $0.type == .hidden }.map { r in
              (
                start: r.startSeconds, end: r.endSeconds,
                entryTransition: r.entryTransition ?? .none,
                entryDuration: r.entryTransitionDuration ?? 0.3,
                exitTransition: r.exitTransition ?? .none,
                exitDuration: r.exitTransitionDuration ?? 0.3
              )
            } : [],
          cameraCustomRegions: editorState.webcamEnabled
            ? editorState.cameraRegions.filter { $0.type == .custom && $0.customLayout != nil }
              .map { r in
                (
                  start: r.startSeconds,
                  end: r.endSeconds,
                  layout: r.customLayout!,
                  cameraAspect: r.customCameraAspect ?? editorState.cameraAspect,
                  cornerRadius: r.customCornerRadius ?? editorState.cameraCornerRadius,
                  shadow: r.customShadow ?? editorState.cameraShadow,
                  borderWidth: r.customBorderWidth ?? editorState.cameraBorderWidth,
                  borderColor: (r.customBorderColor ?? editorState.cameraBorderColor).cgColor,
                  mirrored: r.customMirrored ?? editorState.cameraMirrored,
                  entryTransition: r.entryTransition ?? .none,
                  entryDuration: r.entryTransitionDuration ?? 0.3,
                  exitTransition: r.exitTransition ?? .none,
                  exitDuration: r.exitTransitionDuration ?? 0.3
                )
              } : [],
          cameraFullscreenFillMode: editorState.cameraFullscreenFillMode,
          cameraFullscreenAspect: editorState.cameraFullscreenAspect,
          videoRegions: editorState.videoRegions.map { r in
            (
              start: r.startSeconds, end: r.endSeconds,
              entryTransition: r.entryTransition ?? .none,
              entryDuration: r.entryTransitionDuration ?? 0.3,
              exitTransition: r.exitTransition ?? .none,
              exitDuration: r.exitTransitionDuration ?? 0.3
            )
          },
          isPreviewMode: editorState.isPreviewMode,
          isPlaying: editorState.isPlaying,
          clickSoundEnabled: editorState.clickSoundEnabled && editorState.showCursor
            && editorState.cursorMetadataProvider != nil,
          clickSoundVolume: editorState.clickSoundVolume,
          clickSoundStyle: editorState.clickSoundStyle,
          spotlightEnabled: editorState.isSpotlightActive(at: CMTimeGetSeconds(editorState.currentTime))
            && editorState.showCursor && editorState.cursorMetadataProvider != nil,
          spotlightRadius: editorState.effectiveSpotlightSettings(
            at: CMTimeGetSeconds(editorState.currentTime)
          ).radius,
          spotlightDimOpacity: editorState.effectiveSpotlightSettings(
            at: CMTimeGetSeconds(editorState.currentTime)
          ).dimOpacity,
          spotlightEdgeSoftness: editorState.effectiveSpotlightSettings(
            at: CMTimeGetSeconds(editorState.currentTime)
          ).edgeSoftness,
          cameraBackgroundStyle: editorState.webcamEnabled ? editorState.cameraBackgroundStyle : .none,
          cameraBackgroundImage: editorState.cameraBackgroundImage
        )

        if let captionText = editorState.visibleCaptionText(
          at: CMTimeGetSeconds(editorState.currentTime)
        ) {
          CaptionOverlayView(
            text: captionText,
            position: editorState.captionPosition,
            fontSize: editorState.captionFontSize,
            fontWeight: editorState.captionFontWeight,
            textColor: editorState.captionTextColor,
            backgroundColor: editorState.captionBackgroundColor,
            backgroundOpacity: editorState.captionBackgroundOpacity,
            showBackground: editorState.captionShowBackground
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .aspectRatio(hasEffects ? canvasAspect : screenSize.width / max(screenSize.height, 1), contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
      .overlay(
        RoundedRectangle(cornerRadius: Radius.xxl)
          .strokeBorder(ReframedColors.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private var backgroundView: some View {
    switch editorState.backgroundStyle {
    case .none:
      Color.black
    case .gradient(let id):
      if let preset = GradientPresets.preset(for: id) {
        LinearGradient(
          colors: preset.colors,
          startPoint: preset.startPoint,
          endPoint: preset.endPoint
        )
      } else {
        Color.clear
      }
    case .solidColor(let codableColor):
      Color(cgColor: codableColor.cgColor)
    case .image:
      if let nsImage = editorState.backgroundImage {
        GeometryReader { geo in
          Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: editorState.backgroundImageFillMode == .fill ? .fill : .fit)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
      } else {
        Color.black
      }
    }
  }

  private var timeline: some View {
    TimelineView(
      editorState: editorState,
      systemAudioSamples: systemWaveformGenerator.samples,
      micAudioSamples: micWaveformGenerator.samples,
      systemAudioProgress: systemWaveformGenerator.isGenerating ? systemWaveformGenerator.progress : nil,
      micAudioProgress: editorState.isMicProcessing
        ? editorState.micProcessingProgress * 0.5
        : (micWaveformGenerator.isGenerating ? 0.5 + micWaveformGenerator.progress * 0.5 : nil),
      micAudioMessage: editorState.isMicProcessing
        ? "Denoising… \(Int(editorState.micProcessingProgress * 100))%"
        : (micWaveformGenerator.isGenerating
          ? "Generating waveform… \(Int(micWaveformGenerator.progress * 100))%"
          : nil),
      onScrub: { time in
        editorState.pause()
        editorState.seek(to: time)
      },
      timelineZoom: $timelineZoom,
      baseZoom: $baseZoom
    )
  }

  private var effectiveCameraLayoutBinding: Binding<CameraLayout> {
    let currentTime = CMTimeGetSeconds(editorState.currentTime)
    if let regionId = editorState.activeCameraRegionId(at: currentTime) {
      return Binding(
        get: { editorState.effectiveCameraLayout(at: currentTime) },
        set: { newLayout in
          editorState.updateCameraRegionLayout(regionId: regionId, layout: newLayout)
          editorState.clampCameraRegionLayout(regionId: regionId)
        }
      )
    }
    return $editorState.cameraLayout
  }

  private func regenerateMicWaveform() {
    let url = editorState.processedMicAudioURL ?? editorState.result.microphoneAudioURL
    guard let url, FileManager.default.fileExists(atPath: url.path) else { return }
    micWaveformTask?.cancel()
    micWaveformTask = Task {
      guard !Task.isCancelled else { return }
      await micWaveformGenerator.generate(from: url)
    }
  }

}
