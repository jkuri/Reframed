import CoreMedia
import SwiftUI

extension EditorView {
  var transportBar: some View {
    let isPreview = editorState.isPreviewMode

    return VStack(spacing: 0) {
      HStack {
        IconButton(
          systemName: editorState.isPlaying ? "pause.fill" : "play.fill",
          action: { editorState.togglePlayPause() }
        )

        Spacer()

        HStack(spacing: 4) {
          if isPreview && editorState.hasVideoRegionCuts {
            Text(formatPreciseDuration(seconds: editorState.previewElapsedTime))
              .font(.system(size: 12, design: .monospaced))
              .foregroundStyle(ReframedColors.primaryText)
            Text("/ \(formatPreciseDuration(seconds: editorState.videoRegionsTotalDuration))")
              .font(.system(size: 12, design: .monospaced))
              .foregroundStyle(ReframedColors.secondaryText)
          } else {
            Text(
              "\(formatPreciseDuration(editorState.currentTime)) / \(formatPreciseDuration(editorState.duration))"
            )
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(ReframedColors.primaryText)

            if editorState.hasVideoRegionCuts {
              Text("(\(formatPreciseDuration(seconds: editorState.videoRegionsTotalDuration)))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ReframedColors.secondaryText)
            }
          }
        }

        Spacer()

        if !isPreview {
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
              .presentationBackground(ReframedColors.backgroundPopover)
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
        }

        IconButton(
          systemName: isPreview ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
          action: { editorState.isPreviewMode.toggle() }
        )
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)

      if isPreview {
        previewProgressBar
          .padding(.horizontal, 12)
          .padding(.bottom, 8)
      }
    }
    .background(ReframedColors.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: Radius.xxl))
    .overlay(RoundedRectangle(cornerRadius: Radius.xxl).strokeBorder(ReframedColors.border, lineWidth: 1))
  }

  private var previewProgressBar: some View {
    let totalDuration =
      editorState.hasVideoRegionCuts
      ? editorState.videoRegionsTotalDuration
      : CMTimeGetSeconds(editorState.duration)
    let elapsed =
      editorState.hasVideoRegionCuts
      ? editorState.previewElapsedTime
      : CMTimeGetSeconds(editorState.currentTime)
    let progress = CGFloat(elapsed / max(0.01, totalDuration))
    let barHeight: CGFloat = 4
    let thumbSize: CGFloat = 12

    return GeometryReader { geo in
      let thumbX = max(0, min(geo.size.width, geo.size.width * progress))

      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: barHeight / 2)
          .fill(ReframedColors.muted)
          .frame(height: barHeight)

        RoundedRectangle(cornerRadius: barHeight / 2)
          .fill(ReframedColors.primaryText)
          .frame(width: thumbX, height: barHeight)

        Circle()
          .fill(ReframedColors.primaryText)
          .frame(width: thumbSize, height: thumbSize)
          .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
          .position(x: thumbX, y: geo.size.height / 2)
      }
      .frame(height: geo.size.height)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            if editorState.isPlaying {
              editorState.pause()
            }
            seekPreviewProgress(x: value.location.x, width: geo.size.width, totalDuration: totalDuration)
          }
          .onEnded { _ in
            editorState.play()
          }
      )
    }
    .frame(height: thumbSize)
  }

  private func seekPreviewProgress(x: CGFloat, width: CGFloat, totalDuration: Double) {
    let fraction = max(0, min(1, Double(x / width)))
    let targetElapsed = fraction * totalDuration

    if editorState.hasVideoRegionCuts {
      let sourceTime = editorState.sourceTimeForPreviewElapsed(targetElapsed)
      editorState.seek(to: CMTime(seconds: sourceTime, preferredTimescale: 600))
    } else {
      editorState.seek(to: CMTime(seconds: targetElapsed, preferredTimescale: 600))
    }
  }
}
