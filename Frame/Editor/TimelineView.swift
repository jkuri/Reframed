import AVFoundation
import AppKit
import SwiftUI

struct TimelineView: View {
  @Bindable var editorState: EditorState
  let thumbnails: [NSImage]
  let onScrub: (CMTime) -> Void

  private var totalSeconds: Double {
    max(CMTimeGetSeconds(editorState.duration), 0.001)
  }

  private var playheadFraction: Double {
    CMTimeGetSeconds(editorState.currentTime) / totalSeconds
  }

  private var trimStartFraction: Double {
    CMTimeGetSeconds(editorState.trimStart) / totalSeconds
  }

  private var trimEndFraction: Double {
    CMTimeGetSeconds(editorState.trimEnd) / totalSeconds
  }

  var body: some View {
    GeometryReader { geo in
      let width = geo.size.width
      let height = geo.size.height

      ZStack(alignment: .leading) {
        thumbnailStrip(width: width, height: height)

        Rectangle()
          .fill(Color.black.opacity(0.5))
          .frame(width: max(0, width * trimStartFraction))

        Rectangle()
          .fill(Color.black.opacity(0.5))
          .frame(width: max(0, width * (1 - trimEndFraction)))
          .offset(x: width * trimEndFraction)

        TrimHandle(position: trimStartFraction, totalWidth: width) { newFraction in
          let time = CMTime(seconds: newFraction * totalSeconds, preferredTimescale: 600)
          editorState.updateTrimStart(time)
        }

        TrimHandle(position: trimEndFraction, totalWidth: width) { newFraction in
          let time = CMTime(seconds: newFraction * totalSeconds, preferredTimescale: 600)
          editorState.updateTrimEnd(time)
        }

        Rectangle()
          .fill(Color.red)
          .frame(width: 2, height: height)
          .offset(x: width * playheadFraction - 1)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let fraction = max(0, min(1, value.location.x / width))
            let time = CMTime(seconds: fraction * totalSeconds, preferredTimescale: 600)
            onScrub(time)
          }
      )
    }
    .frame(height: 50)
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  @ViewBuilder
  private func thumbnailStrip(width: CGFloat, height: CGFloat) -> some View {
    if thumbnails.isEmpty {
      Rectangle()
        .fill(FrameColors.fieldBackground)
        .frame(width: width, height: height)
    } else {
      HStack(spacing: 0) {
        ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
          Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width / CGFloat(thumbnails.count), height: height)
            .clipped()
        }
      }
    }
  }
}
