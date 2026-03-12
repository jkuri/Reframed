import AVFoundation
import SwiftUI

extension TimelineView {
  func trimBorderOverlay(
    width: CGFloat,
    height: CGFloat,
    trimStart: Double,
    trimEnd: Double
  ) -> some View {
    let startX = width * trimStart
    let endX = width * trimEnd
    let selectionWidth = endX - startX

    return ZStack(alignment: .leading) {
      Color.clear.frame(width: width, height: height)

      RoundedRectangle(cornerRadius: Track.borderRadius)
        .stroke(Track.borderColor, lineWidth: Track.borderWidth)
        .frame(width: max(0, selectionWidth), height: height)
        .offset(x: startX)
    }
    .allowsHitTesting(false)
  }

  func trimHandleOverlay(
    width: CGFloat,
    height: CGFloat,
    trimStart: Double,
    trimEnd: Double,
    onTrimStart: @escaping (Double) -> Void,
    onTrimEnd: @escaping (Double) -> Void
  ) -> some View {
    ZStack(alignment: .leading) {
      TrimHandle(
        edge: .leading,
        position: trimStart,
        totalWidth: width,
        height: height
      ) { newFraction in
        let clamped = min(newFraction, trimEnd - 0.01)
        onTrimStart(clamped)
      }

      TrimHandle(
        edge: .trailing,
        position: trimEnd,
        totalWidth: width,
        height: height
      ) { newFraction in
        let clamped = max(newFraction, trimStart + 0.01)
        onTrimEnd(clamped)
      }
    }
  }

  func playheadOverlay(contentWidth: CGFloat, inset: CGFloat) -> some View {
    let frameWidth = contentWidth + inset * 2
    let playheadFraction = CMTimeGetSeconds(editorState.currentTime) / totalSeconds

    return SwiftUI.TimelineView(.animation(paused: !editorState.isPlaying)) { _ in
      let fraction: Double =
        if editorState.isPlaying {
          max(0, min(1, CMTimeGetSeconds(editorState.playerController.screenPlayer.currentTime()) / totalSeconds))
        } else {
          playheadFraction
        }
      let centerX = inset + contentWidth * fraction
      let lineHeight = timelineHeight - rulerHeight

      ZStack {
        Rectangle()
          .fill(ReframedColors.primaryText.opacity(0.9))
          .frame(width: 2, height: lineHeight)
          .position(x: centerX, y: rulerHeight + lineHeight / 2)
          .allowsHitTesting(false)

        RoundedRectangle(cornerRadius: Radius.md)
          .fill(ReframedColors.primaryText.opacity(0.9))
          .frame(width: 12, height: rulerHeight)
          .position(x: centerX, y: rulerHeight / 2)
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                let fraction = max(0, min(1, (value.location.x - inset) / contentWidth))
                let time = CMTime(seconds: fraction * totalSeconds, preferredTimescale: 600)
                onScrub(time)
              }
          )
      }
      .frame(width: frameWidth, height: timelineHeight)
    }
  }
}
