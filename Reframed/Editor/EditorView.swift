import CoreMedia
import SwiftUI

struct EditorView: View {
  @Bindable var editorState: EditorState
  @State private var systemWaveformGenerator = AudioWaveformGenerator()
  @State private var micWaveformGenerator = AudioWaveformGenerator()
  @State var selectedTab: EditorTab = .general
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

  var mainContent: some View {
    videoPreview
      .frame(maxHeight: .infinity)
  }

  var timeline: some View {
    TimelineView(
      editorState: editorState,
      systemAudioSamples: systemWaveformGenerator.samples,
      micAudioSamples: micWaveformGenerator.samples,
      systemAudioProgress: systemWaveformGenerator.isGenerating ? systemWaveformGenerator.progress : nil,
      micAudioProgress: editorState.isMicProcessing
        ? editorState.micProcessingProgress * 0.5
        : (micWaveformGenerator.isGenerating ? 0.5 + micWaveformGenerator.progress * 0.5 : nil),
      micAudioMessage: editorState.isMicProcessing
        ? "正在降噪… \(Int(editorState.micProcessingProgress * 100))%"
        : (micWaveformGenerator.isGenerating
          ? "正在生成波形… \(Int(micWaveformGenerator.progress * 100))%"
          : nil),
      onScrub: { time in
        editorState.pause()
        editorState.seek(to: time)
      },
      timelineZoom: $timelineZoom,
      baseZoom: $baseZoom
    )
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
