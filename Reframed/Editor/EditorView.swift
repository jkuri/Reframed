import SwiftUI

struct EditorView: View {
  @Bindable var editorState: EditorState
  @State private var thumbnailGenerator = ThumbnailGenerator(count: 24)
  @State private var webcamThumbnailGenerator = ThumbnailGenerator(count: 24)
  @State private var systemWaveformGenerator = AudioWaveformGenerator()
  @State private var micWaveformGenerator = AudioWaveformGenerator()
  @Environment(\.colorScheme) private var colorScheme

  let onSave: (URL) -> Void
  let onCancel: () -> Void
  let onDelete: () -> Void

  var body: some View {
    let _ = colorScheme
    VStack(spacing: 0) {
      EditorTopBar(
        editorState: editorState,
        onOpenFolder: { editorState.openProjectFolder() },
        onDelete: { editorState.showDeleteConfirmation = true }
      )
      .padding(.bottom, 4)

      HStack(spacing: 12) {
        mainContent
          .background(ReframedColors.panelBackground)
          .clipShape(RoundedRectangle(cornerRadius: 8))
        PropertiesPanel(editorState: editorState)
          .background(ReframedColors.panelBackground)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .padding(.horizontal, 12)
      .frame(maxHeight: .infinity)

      timeline
        .fixedSize(horizontal: false, vertical: true)
        .background(ReframedColors.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
    .background(ReframedColors.selectedBackground.opacity(0.55))
    .task {
      await editorState.setup()
      let sysURL = editorState.result.systemAudioURL
      let micURL = editorState.result.microphoneAudioURL
      let screenURL = editorState.result.screenVideoURL
      let webcamURL = editorState.result.webcamVideoURL
      async let thumbTask: Void = thumbnailGenerator.generate(from: screenURL)
      async let webcamTask: Void = {
        if let url = webcamURL { await webcamThumbnailGenerator.generate(from: url) }
      }()
      async let sysTask: Void = {
        if let url = sysURL { await systemWaveformGenerator.generate(from: url) }
      }()
      async let micTask: Void = {
        if let url = micURL { await micWaveformGenerator.generate(from: url) }
      }()
      _ = await (thumbTask, webcamTask, sysTask, micTask)
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

  private var mainContent: some View {
    VStack(spacing: 0) {
      videoPreview
        .frame(maxHeight: .infinity)
      EditorBottomBar(editorState: editorState)
    }
  }

  private var videoPreview: some View {
    let screenSize = editorState.result.screenSize
    let hasEffects =
      editorState.backgroundStyle != .none || editorState.padding > 0
      || editorState.videoCornerRadius > 0
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
          webcamPlayer: editorState.playerController.webcamPlayer,
          pipLayout: $editorState.pipLayout,
          webcamSize: editorState.result.webcamSize,
          screenSize: screenSize,
          canvasSize: editorState.canvasSize(for: screenSize),
          padding: editorState.padding,
          videoCornerRadius: editorState.videoCornerRadius,
          pipCornerRadius: editorState.pipCornerRadius,
          pipBorderWidth: editorState.pipBorderWidth
        )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .aspectRatio(hasEffects ? canvasAspect : screenSize.width / max(screenSize.height, 1), contentMode: .fit)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  @ViewBuilder
  private var backgroundView: some View {
    switch editorState.backgroundStyle {
    case .none:
      Color.clear
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


  private var timeline: some View {
    TimelineView(
      editorState: editorState,
      thumbnails: thumbnailGenerator.thumbnails,
      webcamThumbnails: webcamThumbnailGenerator.thumbnails,
      systemAudioSamples: systemWaveformGenerator.samples,
      micAudioSamples: micWaveformGenerator.samples,
      onScrub: { time in
        editorState.pause()
        editorState.seek(to: time)
      }
    )
  }

  private func handleExport(settings: ExportSettings) {
    Task {
      do {
        let url = try await editorState.export(settings: settings)
        editorState.exportResultMessage = "Saved to \(url.lastPathComponent)"
        editorState.exportResultIsError = false
      } catch {
        editorState.exportResultMessage = error.localizedDescription
        editorState.exportResultIsError = true
      }
      editorState.showExportResult = true
    }
  }
}
