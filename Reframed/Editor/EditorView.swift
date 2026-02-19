import CoreMedia
import SwiftUI

enum EditorTab: String, CaseIterable, Identifiable {
  case general, video, camera, audio, cursor, zoom, animations

  var id: String { rawValue }

  var label: String {
    switch self {
    case .general: "General"
    case .video: "Video"
    case .camera: "Camera"
    case .audio: "Audio"
    case .cursor: "Cursor"
    case .zoom: "Zoom"
    case .animations: "Animate"
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
    case .animations: "wand.and.stars"
    }
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

  let onSave: (URL) -> Void
  let onCancel: () -> Void
  let onDelete: () -> Void

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
        .padding(.bottom, 4)

        HStack(spacing: 6) {
          mainContent
            .background(ReframedColors.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          editorSidebar
            .background(ReframedColors.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          PropertiesPanel(editorState: editorState, selectedTab: selectedTab)
            .background(ReframedColors.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
      }

      transportBar
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, editorState.isPreviewMode ? 12 : 0)

      if !editorState.isPreviewMode {
        timeline
          .fixedSize(horizontal: false, vertical: true)
          .background(ReframedColors.panelBackground)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .padding(.horizontal, 12)
          .padding(.top, 8)
          .padding(.bottom, 12)
      }
    }
    .onTapGesture {
      NSApp.keyWindow?.makeFirstResponder(nil)
    }
    .ignoresSafeArea(edges: .top)
    .frame(minWidth: 1200, minHeight: 800)
    .background(ReframedColors.selectedBackground.opacity(0.55))
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
        isPresented: $editorState.showExportSheet,
        sourceFPS: editorState.result.fps,
        hasAudio: (editorState.hasSystemAudio && !editorState.systemAudioMuted)
          || (editorState.hasMicAudio && !editorState.micAudioMuted)
      ) { settings in
        handleExport(settings: settings)
      }
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
    .sheet(isPresented: $editorState.showExportResult) {
      ExportResultSheet(
        editorState: editorState,
        isPresented: $editorState.showExportResult
      )
    }
  }

  private var editorSidebar: some View {
    VStack(spacing: 0) {
      HoverEffectScope {
        VStack(spacing: 2) {
          ForEach(EditorTab.allCases) { tab in
            let disabled =
              (tab == .camera && !editorState.hasWebcam)
              || (tab == .audio && !editorState.hasSystemAudio && !editorState.hasMicAudio)
            Button {
              selectedTab = tab
            } label: {
              VStack(spacing: 3) {
                Image(systemName: tab.icon)
                  .font(.system(size: 16))
                  .foregroundStyle(selectedTab == tab ? ReframedColors.primaryText : ReframedColors.secondaryText)
                Text(tab.label)
                  .font(.system(size: 10))
                  .foregroundStyle(selectedTab == tab ? ReframedColors.secondaryText : ReframedColors.dimLabel)
              }
              .frame(width: 56, height: 48)
              .background(
                selectedTab == tab ? ReframedColors.selectedBackground : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
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
      case .solidColor(let c): return !(c.r == 0 && c.g == 0 && c.b == 0)
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
          cameraLayout: $editorState.cameraLayout,
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
          showClickHighlights: editorState.showClickHighlights,
          clickHighlightColor: editorState.clickHighlightColor.cgColor,
          clickHighlightSize: editorState.clickHighlightSize,
          zoomFollowCursor: editorState.zoomFollowCursor,
          currentTime: CMTimeGetSeconds(editorState.currentTime),
          zoomTimeline: editorState.zoomTimeline,
          cameraFullscreenRegions: editorState.webcamEnabled
            ? editorState.cameraFullscreenRegions.map { (start: $0.startSeconds, end: $0.endSeconds) } : [],
          cameraFullscreenFillMode: editorState.cameraFullscreenFillMode,
          cameraFullscreenAspect: editorState.cameraFullscreenAspect
        )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .aspectRatio(hasEffects ? canvasAspect : screenSize.width / max(screenSize.height, 1), contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: hasEffects ? 0 : previewCornerRadius(screenSize: screenSize, viewSize: geo.size)))
      .overlay(
        RoundedRectangle(cornerRadius: hasEffects ? 0 : previewCornerRadius(screenSize: screenSize, viewSize: geo.size))
          .stroke(ReframedColors.divider, lineWidth: 1)
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

  private func previewCornerRadius(screenSize: CGSize, viewSize: CGSize) -> CGFloat {
    let nativeRadius: CGFloat = 10
    let scale = min(viewSize.width / max(screenSize.width, 1), viewSize.height / max(screenSize.height, 1))
    return nativeRadius * scale
  }

  private func regenerateMicWaveform() {
    let url = editorState.processedMicAudioURL ?? editorState.result.microphoneAudioURL
    guard let url else { return }
    micWaveformTask?.cancel()
    micWaveformTask = Task {
      guard !Task.isCancelled else { return }
      await micWaveformGenerator.generate(from: url)
    }
  }

  private func handleExport(settings: ExportSettings) {
    editorState.exportTask = Task {
      do {
        let url = try await editorState.export(settings: settings)
        try Task.checkCancellation()
        editorState.exportResultMessage = "Saved to \(url.lastPathComponent)"
        editorState.exportResultIsError = false
        editorState.showExportResult = true
      } catch is CancellationError {
      } catch {
        editorState.exportResultMessage = error.localizedDescription
        editorState.exportResultIsError = true
        editorState.showExportResult = true
      }
    }
  }
}
