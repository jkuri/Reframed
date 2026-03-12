import AVFoundation
import SwiftUI

extension TimelineView {
  func trackSidebar(label: String, icon: String) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.system(size: FontSize.sm))
      Text(label)
        .font(.system(size: FontSize.xxs, weight: .semibold))
    }
    .foregroundStyle(ReframedColors.primaryText)
  }

  func zoomTrackContent(width: CGFloat, keyframes: [ZoomKeyframe]) -> some View {
    ZoomKeyframeEditor(
      keyframes: keyframes,
      duration: totalSeconds,
      width: width,
      height: trackHeight,
      scrollOffset: scrollOffset,
      timelineZoom: timelineZoom,
      onAddKeyframe: { time in
        if let provider = editorState.cursorMetadataProvider {
          let pos = provider.sample(at: time)
          editorState.addManualZoomKeyframe(at: time, center: pos)
        }
      },
      onRemoveRegion: { startIndex, count in
        editorState.removeZoomRegion(startIndex: startIndex, count: count)
      },
      onUpdateRegion: { startIndex, count, newKeyframes in
        editorState.updateZoomRegion(startIndex: startIndex, count: count, newKeyframes: newKeyframes)
      }
    )
    .frame(width: width, height: trackHeight)
  }
}
