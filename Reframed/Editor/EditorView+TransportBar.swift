import SwiftUI

extension EditorView {
  var transportBar: some View {
    HStack {
      IconButton(
        systemName: editorState.isPlaying ? "pause.fill" : "play.fill",
        action: { editorState.togglePlayPause() }
      )

      Spacer()

      Text("\(formatPreciseDuration(editorState.currentTime)) / \(formatPreciseDuration(editorState.duration))")
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(ReframedColors.secondaryText)

      Spacer()

      IconButton(
        systemName: "minus.magnifyingglass",
        color: timelineZoom > 1.0 ? ReframedColors.primaryText : ReframedColors.disabledText
      ) {
        timelineZoom = max(1.0, timelineZoom / 1.5)
        baseZoom = timelineZoom
      }
      .disabled(timelineZoom <= 1.0)

      IconButton(
        systemName: "plus.magnifyingglass",
        color: timelineZoom < 30.0 ? ReframedColors.primaryText : ReframedColors.disabledText
      ) {
        timelineZoom = min(30.0, timelineZoom * 1.5)
        baseZoom = timelineZoom
      }
      .disabled(timelineZoom >= 30.0)

      IconButton(
        systemName: "1.magnifyingglass",
        color: timelineZoom > 1.0 ? ReframedColors.primaryText : ReframedColors.disabledText
      ) {
        timelineZoom = 1.0
        baseZoom = 1.0
      }
      .disabled(timelineZoom <= 1.0)

      IconButton(systemName: "clock.arrow.circlepath") {
        showHistoryPopover.toggle()
      }
      .popover(isPresented: $showHistoryPopover, arrowEdge: .top) {
        HistoryPopover(editorState: editorState)
          .presentationBackground(ReframedColors.panelBackground)
      }

      IconButton(
        systemName: "arrow.uturn.backward",
        color: editorState.history.canUndo ? ReframedColors.primaryText : ReframedColors.disabledText,
        action: { editorState.undo() }
      )
      .disabled(!editorState.history.canUndo)

      IconButton(
        systemName: "arrow.uturn.forward",
        color: editorState.history.canRedo ? ReframedColors.primaryText : ReframedColors.disabledText,
        action: { editorState.redo() }
      )
      .disabled(!editorState.history.canRedo)

      IconButton(
        systemName: editorState.isPreviewMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
        action: { editorState.isPreviewMode.toggle() }
      )
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(ReframedColors.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}
