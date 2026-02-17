import AVFoundation
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
      regenerateMicWaveform()
    }
    .onChange(of: editorState.micNoiseReductionIntensity) { _, _ in
      guard didFinishSetup else { return }
      regenerateMicWaveform()
    }
    .sheet(isPresented: $editorState.showExportSheet) {
      ExportSheet(isPresented: $editorState.showExportSheet, sourceFPS: editorState.result.fps) { settings in
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
    .alert(
      editorState.exportResultIsError ? "Export Failed" : "Export Successful",
      isPresented: $editorState.showExportResult
    ) {
      Button("OK") {}
      if !editorState.exportResultIsError {
        Button("Show in Finder") {
          editorState.openExportedFile()
        }
      }
    } message: {
      Text(editorState.exportResultMessage)
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
              .opacity(disabled ? 0.35 : 1)
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
      case .gradient: return true
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
            ? editorState.cameraFullscreenRegions.map { (start: $0.startSeconds, end: $0.endSeconds) } : []
        )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .aspectRatio(hasEffects ? canvasAspect : screenSize.width / max(screenSize.height, 1), contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: hasEffects ? 0 : previewCornerRadius(screenSize: screenSize, viewSize: geo.size)))
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
    }
  }

  private var transportBar: some View {
    HStack {
      Button(action: { editorState.togglePlayPause() }) {
        Image(systemName: editorState.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 14))
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(ReframedColors.primaryText)

      Spacer()

      Text("\(formatPreciseDuration(editorState.currentTime)) / \(formatPreciseDuration(editorState.duration))")
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(ReframedColors.secondaryText)

      Spacer()

      Button(action: { editorState.isPreviewMode.toggle() }) {
        Image(systemName: editorState.isPreviewMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
          .font(.system(size: 14))
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(ReframedColors.primaryText)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(ReframedColors.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var timeline: some View {
    TimelineView(
      editorState: editorState,
      systemAudioSamples: systemWaveformGenerator.samples,
      micAudioSamples: micWaveformGenerator.samples,
      systemAudioProgress: systemWaveformGenerator.isGenerating ? systemWaveformGenerator.progress : nil,
      micAudioProgress: micWaveformGenerator.isGenerating ? micWaveformGenerator.progress : nil,
      onScrub: { time in
        editorState.pause()
        editorState.seek(to: time)
      }
    )
  }

  private func previewCornerRadius(screenSize: CGSize, viewSize: CGSize) -> CGFloat {
    let nativeRadius: CGFloat = 10
    let scale = min(viewSize.width / max(screenSize.width, 1), viewSize.height / max(screenSize.height, 1))
    return nativeRadius * scale
  }

  private func regenerateMicWaveform() {
    guard let url = editorState.result.microphoneAudioURL else { return }
    micWaveformTask?.cancel()
    micWaveformTask = Task {
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }

      var params: NoiseReductionParams?
      if editorState.micNoiseReductionEnabled {
        let intensity = editorState.micNoiseReductionIntensity
        let highPass = 80 + (300 - 80) * intensity
        let lowPass = 20000 - (20000 - 8000) * intensity
        let asset = AVURLAsset(url: url)
        let tracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        var sampleRate = 44100.0
        if let track = tracks.first,
          let descriptions = try? await track.load(.formatDescriptions),
          let desc = descriptions.first
        {
          let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)
          if let rate = asbd?.pointee.mSampleRate, rate > 0 {
            sampleRate = rate
          }
        }
        params = NoiseReductionParams(highPassFreq: highPass, lowPassFreq: lowPass, sampleRate: sampleRate)
      }

      guard !Task.isCancelled else { return }
      await micWaveformGenerator.generate(from: url, noiseReduction: params)
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
