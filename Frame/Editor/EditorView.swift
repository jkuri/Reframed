import SwiftUI

struct EditorView: View {
  @Bindable var editorState: EditorState
  @State private var thumbnailGenerator = ThumbnailGenerator()

  let onSave: (URL) -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider().background(FrameColors.divider)
      videoPreview
      Divider().background(FrameColors.divider)
      timeline
      Divider().background(FrameColors.divider)
      EditorToolbar(editorState: editorState, onSave: handleSave, onCancel: onCancel)
    }
    .background(FrameColors.panelBackground)
    .task {
      await editorState.setup()
      await thumbnailGenerator.generate(from: editorState.result.screenVideoURL)
    }
  }

  private var header: some View {
    HStack {
      Text("Editor")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(FrameColors.primaryText)
      Spacer()
      if editorState.isExporting {
        HStack(spacing: 8) {
          ProgressView()
            .controlSize(.small)
            .scaleEffect(0.8)
          Text("Exporting...")
            .font(.system(size: 12))
            .foregroundStyle(FrameColors.secondaryText)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private var videoPreview: some View {
    VideoPreviewView(
      screenPlayer: editorState.playerController.screenPlayer,
      webcamPlayer: editorState.playerController.webcamPlayer,
      pipLayout: $editorState.pipLayout,
      webcamSize: editorState.result.webcamSize,
      screenSize: editorState.result.screenSize
    )
    .aspectRatio(
      editorState.result.screenSize.width / max(editorState.result.screenSize.height, 1),
      contentMode: .fit
    )
    .clipShape(RoundedRectangle(cornerRadius: 4))
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
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

  private func handleSave() {
    Task {
      do {
        let url = try await editorState.export()
        onSave(url)
      } catch {
        let alert = NSAlert()
        alert.messageText = "Export Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
      }
    }
  }
}
