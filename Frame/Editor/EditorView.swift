import SwiftUI

struct EditorView: View {
  @Bindable var editorState: EditorState
  @State private var thumbnailGenerator = ThumbnailGenerator()
  @Environment(\.colorScheme) private var colorScheme

  let onSave: (URL) -> Void
  let onCancel: () -> Void
  let onDelete: () -> Void

  var body: some View {
    let _ = colorScheme
    VStack(spacing: 0) {
      EditorTopBar(
        editorState: editorState,
        onOpenFolder: { editorState.openExportFolder() },
        onDelete: { editorState.showDeleteConfirmation = true }
      )
      Divider().background(FrameColors.divider)

      HStack(spacing: 0) {
        mainContent
        Divider().background(FrameColors.divider)
        PropertiesPanel(editorState: editorState)
      }
    }
    .background(FrameColors.panelBackground)
    .task {
      await editorState.setup()
      await thumbnailGenerator.generate(from: editorState.result.screenVideoURL)
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
          editorState.openExportFolder()
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
      Divider().background(FrameColors.divider)
      timeline
      Divider().background(FrameColors.divider)
      EditorBottomBar(editorState: editorState)
    }
  }

  private var videoPreview: some View {
    let screenSize = editorState.result.screenSize
    let hasEffects = editorState.backgroundStyle != .none || editorState.padding > 0
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
          pipCornerRadius: editorState.pipCornerRadius,
          pipBorderWidth: editorState.pipBorderWidth
        )
        .clipShape(RoundedRectangle(cornerRadius: scaledCornerRadius(in: geo.size)))
        .padding(.horizontal, scaledHPadding(in: geo.size))
        .padding(.vertical, scaledVPadding(in: geo.size))
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

  private func scaledHPadding(in viewSize: CGSize) -> CGFloat {
    guard editorState.padding > 0 else { return 0 }
    let canvasSize = editorState.canvasSize(for: editorState.result.screenSize)
    let fitScale = min(viewSize.width / canvasSize.width, viewSize.height / canvasSize.height)
    return editorState.padding * editorState.result.screenSize.width * fitScale
  }

  private func scaledVPadding(in viewSize: CGSize) -> CGFloat {
    guard editorState.padding > 0 else { return 0 }
    let canvasSize = editorState.canvasSize(for: editorState.result.screenSize)
    let fitScale = min(viewSize.width / canvasSize.width, viewSize.height / canvasSize.height)
    return editorState.padding * editorState.result.screenSize.height * fitScale
  }

  private func scaledCornerRadius(in viewSize: CGSize) -> CGFloat {
    guard editorState.videoCornerRadius > 0 else { return 0 }
    let canvasSize = editorState.canvasSize(for: editorState.result.screenSize)
    let fitScale = min(viewSize.width / canvasSize.width, viewSize.height / canvasSize.height)
    return editorState.videoCornerRadius * fitScale
  }

  private var timeline: some View {
    TimelineView(
      editorState: editorState,
      thumbnails: thumbnailGenerator.thumbnails,
      onScrub: { time in
        editorState.pause()
        editorState.seek(to: time)
      }
    )
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
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
